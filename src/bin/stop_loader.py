#!/usr/bin/env python3
#
# Tells parallel_loader to stop
#

import os
import pika
import configparser

#
config = configparser.ConfigParser()
config_dir = os.path.dirname(__file__) + "/../etc"
config_file_path = os.path.join( config_dir, 'config.ini')
config.read(config_file_path)

MAX_WORKERS = int( config.get('cbmon_load', 'max_workers') )
JOB_QUEUE   = config.get('cbmon_load', 'job_queue')

RMQ_HOST    = config.get('rabbitmq', 'host')
RMQ_USER    = config.get('rabbitmq', 'user')
RMQ_PASS    = config.get('rabbitmq', 'pass')


#
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

# Create message to stop
from control_message import control_message as cm

msg = cm()
msg.stop()
jsstr = msg.as_str()

channel.basic_publish(
    exchange = '',
    routing_key = JOB_QUEUE,
    body = jsstr
)

print(" [x] Sent")

connection.close()

