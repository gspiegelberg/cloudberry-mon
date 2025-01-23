#!/usr/bin/env python3

import os
import re
import sys
import csv
from datetime import datetime, timedelta

import argparse

parser = argparse.ArgumentParser(
	description=""
        , formatter_class=argparse.RawDescriptionHelpFormatter
)

parser.add_argument(
	"-l", "--log"
	, help="log file to process"
	, type=str
)
parser.add_argument(
	"-H", "--hours"
	, help="optional test log timestamp in past hours"
	, type=int
	, default=1
)

args = parser.parse_args()

if os.path.isfile(args.log):
    input_file = args.log
else:
    exit(1)

target_ts = datetime.now()
target_ts = target_ts - timedelta(hours=args.hours)

segment_id = [ os.getenv('GP_SEGMENT_ID') ]


#
# Overcome csvlog corruption
#
def validate_row(row):
    if len(row) != 30:
        return False, "Discard, incorrect number of columns"

    row_ts = datetime.strptime(row[0], "%Y-%m-%d %H:%M:%S.%f %Z")
    if  row_ts < target_ts:
        return False, "Discard"

    if row[18].startswith(('QUERY STATISTICS', 'BIND MESSAGE STATISTICS', 'EXECUTE MESSAGE STATISTICS', 'PARSE MESSAGE STATISTICS')):
        return True, None

    return False, "Discard"


elements_keep = [0, 1, 2, 3, 4, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 ]
num_pattern = r'-?\d+(?:\.\d+)?|(?:\d+/\d+)'

with open(input_file, newline='', encoding='utf-8') as infile:
    reader = csv.reader(infile, quotechar='"' )
    writer = csv.writer(sys.stdout)

    for row in reader:
        is_valid, error_message = validate_row(row)
        if is_valid:
            output= []
            output = [row[i] for i in elements_keep]

            numbers = re.findall(num_pattern, row[19])
            output.extend(numbers)
            writer.writerow(segment_id + output)

"""
0       2024-12-01 00:00:06.538344 MST
1       "gpadmin"
2       "coredw"
3       p1262002
4       th-1203922816
5       "192.168.122.80"
6       "41142"
7       2024-12-01 00:00:06 MST
8       0
9       con5235
10      cmd1
11      seg0
12
13
14
15
16      "LOG"
17      "00000"
18      "QUERY STATISTICS"
19      "! system usage stats:
        !       0.000218 s user 0.000174 s system 0.000390 s elapsed
        !       [0.005890 s user 0.004691 s system total]
        !       20812 kB max resident size
        !       0/0 [0/0] filesystem blocks in/out
        !       0/14 [0/733] page faults/reclaims 0 [0] swaps
        !       0 [0] signals rcvd 0/0 [0/0] messages rcvd/sent
        !       0/0 [5/6] voluntary/involuntary context switches"
20
21
22
23
24      "SET search_path TO 'pg_catalog'"
25      0
26
27      "postgres.c"
28      6247
29


2024-12-02 14:29:28.090424 MST,gpadmin,coredw,p1931349,th-1203922816,16404,0,con9206,cmd94,seg0,slice1,,,,LOG,00000,0.009201,0.015134,0.114390,0.011892,0.023300,24068,0,0,0,0,0,452,0,1166,0,0,0,0,0,0,0,0,6,2,9,6


"""
