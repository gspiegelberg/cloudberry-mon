#!/usr/bin/env python3

import os
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

#
# Overcome csvlog corruption
#
def validate_row(row):
    if len(row) != 30:
        return False, "Discard, incorrect number of columns"

    row_ts = datetime.strptime(row[0], "%Y-%m-%d %H:%M:%S.%f %Z")
    if  row_ts < target_ts:
        return False, "Discard"

    if row[18].startswith(('connection ', 'statement: ', 'execute ', 'disconnection: ')):
        return True, None
    
    return False, "Discard"



with open(input_file, newline='', encoding='utf-8') as infile:
    reader = csv.reader(infile, quotechar='"' )
    writer = csv.writer(sys.stdout)
    
    for row in reader:
        is_valid, error_message = validate_row(row)
        if is_valid:
            writer.writerow(row)

