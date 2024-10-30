#!/usr/bin/env python3

import os
import sys
import csv

if len(sys.argv) != 2:
    print("Usage: python3 log_reader_helped.py <csvfile>")
    sys.exit(1)

input_file = sys.argv[1]


#
# Overcome csvlog corruption
#
def validate_row(row):
    if len(row) != 30:
        return False, "Discard, incorrect number of columns"
    
    return True, None


with open(input_file, newline='', encoding='utf-8') as infile:
    reader = csv.reader(infile, quotechar='"' )
    writer = csv.writer(sys.stdout)
    
    for row in reader:
        is_valid, error_message = validate_row(row)
        if is_valid:
            writer.writerow(row)

