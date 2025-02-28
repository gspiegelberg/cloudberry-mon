#!/usr/bin/env python3

"""
Execute work received from queue

Not using Threads. Not efficiently implemented in python3 and
every worker requires own connection to database. Nothing shared
anyways to warrant threads.
"""

import os
import multiprocessing
import time
import pika
import psycopg2
import json
from datetime import datetime

import configparser



def process_message(message):
    def pgconnect():
        return psycopg2.connect(
            host     = DBHOST,
            database = DBNAME,
            port     = DBPORT,
            user     = DBUSER,
            password = DBPASS
        )

    try:
        pid = os.getpid()

        print(f"{pid:>10}: start {message}.")

        pg = pgconnect()
        cluster_id = message.get("cluster_id")
        load_function_id = message.get("cluster_id")
        override_freq = message.get("override_freq")
        analyze = message.get("analyze")
        prime = message.get("prime")

        cur = pg.cursor()
        cur.execute("CALL public.load(%s, %s, %s, %s, %s);",
            (cluster_id, analyze, prime, load_function_id, override_freq)
        )
        pg.commit()

        # Simulate some work
        #delay = data["delay"]
        #delay = message["delay"]
        #time.sleep( delay )

        print(f"{pid:>10}: done {message}.")
        pg.close()

    except psycopg2.Error as e:
        print(f"{pid:>10}: database error: {e}")

    finally:
        # Ensure the connection is closed in case of an error
        if 'pg' in locals() and pg is not None:
            pg.close()


def callback(ch, method, properties, body):
    print(f"Received: {body}")

    message = json.loads( body )

    if message is None:
        # bad json, ack and return
        ch.basic_ack(
            delivery_tag = method.delivery_tag
        )
        return False

    # Could do this better
    # Control message
    if "control" in message:
        if message["control"] == "stop":
            from control_message import control_message as cm
            msg = cm( body )
            if msg.is_stop():
                messager = msg.req_user()+'@'+msg.req_host()+' at '+str(msg.req_ts())
                print( f"told to stop by {messager}")

                # Need to wait for all executing threads 

                # ACK or we'll never be able to start again
                ch.basic_ack(
                    delivery_tag = method.delivery_tag
                )

                exit(0)
            #else: what?

    presult = process_pool.apply_async(
        process_message, args=(message,)
    )

    # Need to wait for process_message to return before ACK
    #presult.wait()

    # if needed, return available via
    #output = presult.get()

    # ACK message
    ch.basic_ack(
        delivery_tag = method.delivery_tag
    )


def main():
    # Loops only on exception
    while True:
        try:
            creds = pika.PlainCredentials( RMQ_USER, RMQ_PASS )
            connection = pika.BlockingConnection(
                pika.ConnectionParameters(
                    host = RMQ_HOST,
                    credentials = creds
                )
            )

            channel = connection.channel()
            channel.queue_declare(
                queue = JOB_QUEUE,
                durable = True
            )
            
            channel.basic_qos(
                prefetch_count = MAX_WORKERS
            )

            channel.basic_consume(
                queue = JOB_QUEUE,
                on_message_callback = callback
            )
            
            print("Waiting for messages")
            channel.start_consuming()

        except KeyboardInterrupt:
            print("Stopping consumer...")
            break

        except pika.exceptions.AMQPConnectionError:
            print("Connection lost. Reconnecting...")
            time.sleep(5)
        finally:
            try:
                connection.close()
            except Exception:
                pass

if __name__ == "__main__":
    # configuration
    config = configparser.ConfigParser()
    config_file_path = os.path.join( '/home/gspiegel/src/cloudberry-mon/src/wip', 'config.ini')
    config.read(config_file_path)
    
    MAX_WORKERS = int( config.get('cbmon_load', 'max_workers') )
    JOB_QUEUE   = config.get('cbmon_load', 'job_queue')

    DBNAME      = config.get('cbmondb', 'name')
    DBUSER      = config.get('cbmondb', 'user')
    DBPASS      = config.get('cbmondb', 'pass')
    DBHOST      = config.get('cbmondb', 'host')
    DBPORT      = int( config.get('cbmondb', 'port') )

    RMQ_HOST    = config.get('rabbitmq', 'host')
    RMQ_USER    = config.get('rabbitmq', 'user')
    RMQ_PASS    = config.get('rabbitmq', 'pass')

    # Create a pool of workers
    process_pool = multiprocessing.Pool(
        processes = MAX_WORKERS
    )
    main()
    process_pool.close()
    process_pool.join()


