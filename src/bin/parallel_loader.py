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
import argparse
import configparser
import logging
from logging.handlers import TimedRotatingFileHandler
from load_function_message import load_function_message, MessageException
from control_message import control_message

logger = logging.getLogger(__name__)


def process_message(message):
    def pgconnect():
        return psycopg2.connect(
            host=DBHOST,
            database=DBNAME,
            port=DBPORT,
            user=DBUSER,
            password=DBPASS
        )

    pid = os.getpid()
    try:
        logger.debug( f"{pid:>10}: start {message}." )

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

        logger.debug( f"{pid:>10}: done {message}." )
        pg.close()

    except psycopg2.Error as e:
        logger.error( f"{pid:>10}: database error: {e}" )

    finally:
        # Ensure the connection is closed in case of an error
        if 'pg' in locals() and pg is not None:
            pg.close()


def callback(ch, method, properties, body):
    logger.debug( f"Received: {body}" )

    message = json.loads( body )

    if message is None:
        # bad json, ack and return
        logger.warning( "received NULL message" )
        ch.basic_ack(
            delivery_tag = method.delivery_tag
        )
        return False

    # @todo Could do this better leveraging Message class to determine message type
    # Control message
    if "control" in message:
        if message["control"] == "stop":
            from control_message import control_message as cm
            msg = cm( body )

            if msg.validate():
                logger.warning( "not a valid control message" )

            if msg.is_stop():
                messager = msg.req_user()+'@'+msg.req_host()+' at '+str(msg.req_ts())
                logger.info( f"told to stop by {messager}")

                # @todo Need to wait for all executing threads

                # ACK or we'll never be able to start again
                ch.basic_ack(
                    delivery_tag = method.delivery_tag
                )

                exit(0)

    presult = process_pool.apply_async(
        process_message, args=(message,)
    )

    # @todo Need to wait for process_message to return before ACK
    #presult.wait()

    # @todo if needed, return available via
    #output = presult.get()

    # @todo don't blind ACK message
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
            
            logger.info("Waiting for messages")
            channel.start_consuming()

        except KeyboardInterrupt:
            logger.info("Stopping consumer...")
            break

        except pika.exceptions.AMQPConnectionError:
            logging.warning("Connection lost. Reconnecting...")
            # @todo Make config driven
            time.sleep(5)
        finally:
            try:
                connection.close()
            except Exception:
                pass

if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description=""
        , formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument(
        "-c", "--config"
        , help="Path to configuration file (required)"
        , type=str
    )

    args = parser.parse_args()

    # configuration
    CONFIG = args.config
    config = configparser.ConfigParser()
    config.read(CONFIG)

    MAX_WORKERS = int( config.get('cbmon_load', 'max_workers') )
    JOB_QUEUE = config.get('cbmon_load', 'job_queue')

    DBNAME = config.get('cbmondb', 'name')
    DBUSER = config.get('cbmondb', 'user')
    DBPASS = config.get('cbmondb', 'pass')
    DBHOST = config.get('cbmondb', 'host')
    DBPORT = int( config.get('cbmondb', 'port') )

    RMQ_HOST = config.get('rabbitmq', 'host')
    RMQ_USER = config.get('rabbitmq', 'user')
    RMQ_PASS = config.get('rabbitmq', 'pass')

    LOG_FILE = config.get('logging', 'file')

    logger.setLevel(logging.DEBUG)  # Set the minimum log level

    # Create a file handler
    file_handler = logging.FileHandler(LOG_FILE)
    file_handler.setLevel(logging.DEBUG)
    file_handler = TimedRotatingFileHandler(
        LOG_FILE, when="midnight", interval=1, backupCount=7
    )
    py_name = os.path.basename(__file__)
    formatter = logging.Formatter('%(asctime)s:' + py_name + ':%(funcName)s():%(levelname)s:%(message)s')
    file_handler.setFormatter(formatter)

    # Where logs are going, file & console
    if config.get('logging', 'console') == 'on':
        ch = logging.StreamHandler()
        ch.setFormatter(formatter)
        logger.addHandler(ch)
    logger.addHandler(file_handler)

    # Create a pool of workers
    process_pool = multiprocessing.Pool(
        processes = MAX_WORKERS
    )
    main()
    process_pool.close()
    process_pool.join()


