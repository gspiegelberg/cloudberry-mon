#!/usr/bin/env python3

import psutil
import subprocess
import json
import fnmatch
import os
import csv
import re
import sys
from datetime import datetime, timezone

def get_pxf_pid():
    pattern = 'pxf*.jar'
    for p in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            cmdline = p.info['cmdline'] or []
            for arg in cmdline:
                jar_name = os.path.basename(arg)
                if fnmatch.fnmatch(jar_name, pattern):
                    return str(p.info['pid'])
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return None

def run_jcmd(pid):
    out = subprocess.check_output(
        ["jcmd", pid, "VM.native_memory", "summary"],
        universal_newlines=True
    )
    return out

def parse_nmt(text):
    data = {}

    # Mmmmmmm, metadata
    timestamp = datetime.now(timezone.utc).isoformat()
    data["timestamp"] = timestamp

    hostname = os.uname().nodename
    data["hostname"] = hostname

    for line in text.splitlines():
        m = re.search(r"Total:\s+reserved=(\d+)KB,\s+committed=(\d+)KB", line)
        if m:
            data["total_reserved_kb"] = int(m.group(1))
            data["total_committed_kb"] = int(m.group(2))

        # Section line
        m = re.search(r"-\s+(.+?)\s+\(reserved=(\d+)KB,\s+committed=(\d+)KB\)", line)
        if m:
            name, reserved, committed = m.groups()
            key = name.strip().lower().replace(" ", "_")
            data[key + "_reserved_kb"] = int(reserved)
            data[key + "_committed_kb"] = int(committed)

    return data

def print_output(data):
    if isinstance(data, dict):
        data = [data]

    fieldnames = data[0].keys()
    writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames)
    writer.writerows(data)

if __name__ == "__main__":
    pid = get_pxf_pid()
    raw = run_jcmd(pid)
    parsed = parse_nmt(raw)
    print_output(parsed) 
