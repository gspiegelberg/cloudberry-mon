#!/usr/bin/env python3
# 
# Send work to parallel_loader
#

import os
import pika
import json
import configparser
from datetime import datetime

# configuration
config = configparser.ConfigParser()
config_dir = os.path.dirname(__file__) + "/../etc"
config_file_path = os.path.join( config_dir, 'config.ini')
config.read(config_file_path)

RMQ_HOST    = config.get('rabbitmq', 'host')
RMQ_USER    = config.get('rabbitmq', 'user')
RMQ_PASS    = config.get('rabbitmq', 'pass')
JOB_QUEUE   = config.get('cbmon_load', 'job_queue')
ROUTING_KEY = JOB_QUEUE


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

current_time = datetime.now().timestamp()

"""
Might be tempted to overload the message to do a variety of things... DON'T
Queue & queue consumer dictate work type
Other types of work, get your own queue, they're free

Example of other work:
 * Route to queue lds_mgmt a message indicating new information is
    a) ready to be insert into final CIL table
    b) analyze CIL table/partition
 * Route to queue lds_mgmt a 2nd message telling it to take new
   information and:
    a) back up to S3 object
    b) send another message to AnalyticsDW cluster new CIL data
       ready for load at S3 location
Work done in parallel and out-of-band of existing LDS processes.

Producer & consumer for each type/category of work must have a strictly
implemented contract that is ideally a common message class capable of
 1) crafting a properly formed message for the purpose
 2) final message cannot be formed without all required elements
    existing that is if message requires a "table" field and field
    is None then message is not created
 3) digesting and validating message
"""

from load_function_message import load_function_message as lfm

msg = lfm()
msg.set_cluster_id( 2 )
msg.set_load_function_id( 1 )
msg.set_override_freq( True )
jsstr = msg.as_str()


channel.basic_publish(
    exchange = '',
    routing_key = ROUTING_KEY,
    body = jsstr
)

print(" [x] Sent")

connection.close()

