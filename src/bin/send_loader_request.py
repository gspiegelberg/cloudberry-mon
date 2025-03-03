#!/usr/bin/env python3
# 
# Send work to parallel_loader
#

import pika
import psycopg2
import argparse
import configparser
from datetime import datetime

DEF_OVERRIDE_FREQ = False
DEF_ANALYZE       = False
DEF_PRIME         = False

parser = argparse.ArgumentParser(
	description=""
        , formatter_class=argparse.RawDescriptionHelpFormatter
)

parser.add_argument(
	"-c", "--config"
	, help = "Path to configuration file (required)"
	, type = str
)

parser.add_argument(
	"-C", "--cluster-id"
	, help = "Identifier of cluster to act on (required)"
	, type = int
)

parser.add_argument(
	"-L", "--load-function-id"
	, help = "Identifier of load function to act on (required)"
	, type = int
)

parser.add_argument(
	"-O", "--override-freq"
	, help = "Override load function frequency (optional, default="+str(DEF_OVERRIDE_FREQ)+")"
	, action = 'store_true'
)

parser.add_argument(
	"-A", "--analyze"
	, help = "Analyze post-load execution (optional, default="+str(DEF_ANALYZE)+")"
	, action = 'store_true'
)

parser.add_argument(
	"-P", "--prime"
	, help = "Prime with more historical metrics (optional, default="+str(DEF_PRIME)+")"
	, action = 'store_true'
)

parser.add_argument(
	"--load-all"
	, help = "Send load request for all enabled functions (optional)"
	, action = 'store_true'
)

args = parser.parse_args()

CONFIG = args.config
CLUSTER_ID = args.cluster_id
LOAD_FUNCTION_ID = args.load_function_id
OVERRIDE_FREQ = args.override_freq
ANALYZE = args.analyze
PRIME = args.prime
LOAD_ALL = args.load_all

# Load configuration
config = configparser.ConfigParser()
config.read( CONFIG )

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

def send(ch, queue, message):
	ch.basic_publish(
		exchange = '',
		routing_key = queue,
		body = message
	)

from load_function_message import load_function_message as lfm

msg = lfm()
msg.set_cluster_id( CLUSTER_ID )
msg.set_override_freq( OVERRIDE_FREQ )
msg.set_analyze( ANALYZE )
msg.set_prime( PRIME )

DBNAME = config.get('cbmondb', 'name')
DBUSER = config.get('cbmondb', 'user')
DBPASS = config.get('cbmondb', 'pass')
DBHOST = config.get('cbmondb', 'host')
DBPORT = int(config.get('cbmondb', 'port'))

pg = psycopg2.connect(
	host=DBHOST,
	database=DBNAME,
	port=DBPORT,
	user=DBUSER,
	password=DBPASS
)

ids_sql = ""
if not LOAD_ALL:
	ids_sql = " AND id = " + LOAD_FUNCTION_ID

override_freq_sql = ""
if not OVERRIDE_FREQ:
	override_freq_sql = " AND extract(epoch from now())::int % frequency = 0"

cur = pg.cursor()

cur.execute("SELECT id FROM public.load_functions WHERE enabled" + ids_sql + override_freq_sql)

ids = [r[0] for r in cur.fetchall()]
for id in ids:
	msg.set_load_function_id(id)
	send(channel, ROUTING_KEY, msg.as_str())
	print(f"Sent load request for load function {id}")

connection.close()

