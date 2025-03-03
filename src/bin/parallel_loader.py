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
from load_function_message import load_function_message as lfm, MessageException
from control_message import control_message as cm, MessageException

logger = logging.getLogger(__name__)
running_functions = {}

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

def ack_message(ch):
    cb.basic_ack( delivery_tag= method.delivery_tag )

def callback(ch, method, properties, body):
    logger.debug( f"Received: {body}" )

    message = json.loads( body )

    if message is None:
        # bad json, ack and return
        logger.warning( "received NULL message" )
        ack_message(ch)
        return False

    # @todo Could do this better leveraging Message class to determine message type
    # Control message
    if "control" in message:
        msg = cm( body )

        if not msg.validate():
            logger.warning( "not a valid control message" )
            ack_message(ch)
            return False

        elif msg.is_stop():
            messager = msg.req_user()+'@'+msg.req_host()+' at '+str(msg.req_ts())
            logger.info( f"told to stop by {messager}")

            # @todo Need to wait for all executing threads

            # ACK or we'll never be able to start again
            ack_message(ch)

            exit(0)

    else:
        msg = lfm( body )

        if not msg.validate():
            logger.warning( "not a valid load function message" )
            ack_message(ch)
            return False

        if msg.get_cluster_id() not in running_functions:
            # Cluster id not in dict neither is load func id
            running_functions[msg.get_cluster_id()] = {}
            running_functions[msg.get_cluster_id()][msg.get_load_function_id()] = True
        elif msg.get_load_function_id() in running_functions[msg.get_cluster_id()]:
            # Case to prevent duplicate load func's running on same cluster id
            logger.info( f"ignoring, load function {msg.get_load_function_id()} for cluster {msg.get_cluster_id()} already running" )
            ack_message(ch)
            return True
        else:
            # Cluster id exists and load func id not present
            running_functions[msg.get_cluster_id()][msg.get_load_function_id()] = True

        presult = process_pool.apply_async(
            process_message, args=(message,)
        )

        # @todo Need to wait for process_message to return before ACK
        #presult.wait()

        # @todo if needed, return available via
        #output = presult.get()

        ack_message(ch)

        # Remove to permit future load func id's
        running_functions[msg.get_cluster_id()].pop(msg.get_load_function_id())


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


