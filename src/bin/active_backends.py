#!/usr/bin/env python3

import os
import psutil
import re
import json
import time
import socket

hostname = socket.gethostname()
current_time = time.time()

# Frequently used patterns
re_is_pg = re.compile(r'^postgres: ')
re_client_ip = re.compile(r'\((\d+)\)')
re_session_id = re.compile(r' con(\d+) ')
re_cmdno = re.compile(r' cmd(\d+) ')
re_content = re.compile(r' seg(\d+) ')
re_slice = re.compile(r' slice(\d+) ')


def is_mdw():
    found_mdw = False
    mdw_pid = -1
    # dispatch test
    for proc in psutil.process_iter(['pid', 'cmdline']):
        if proc.info['cmdline'] and "gp_role=dispatch" in ' '.join(proc.info['cmdline']):
            found_mdw = True
            mdw_pid = proc.info['pid']

    if found_mdw:
        for proc in psutil.process_iter(['pid', 'cmdline']):
            if proc.info['cmdline'] and "start recovering" in ' '.join(proc.info['cmdline']) and proc.info['ppid'] == mdw_pid:
                return False
    return found_mdw

def is_backend(cmdline):
    #match = re.search(r'^postgres: ', cmdline)
    match = re_is_pg.search(cmdline)
    if not match:
        return False

    parts = cmdline.split(" ")

    res = {}
    #res['cmdline'] = cmdline
    res['server_port'] = parts[2].replace(",", "")
    res['role'] = parts[3]
    res['database'] = parts[4]

    if parts[5] == '[local]':
        res['client_ip'] = '127.0.0.1'
        res['client_port'] = -1
    else:
        res['client_ip'] = re.sub(r"\(\d+\)", r"", parts[5])
        #match = re.search(r'\((\d+)\)', parts[5])
        match = re_client_ip.search(parts[5])
        if match:
            res['client_port'] = match.group(1)

    #match = re.search(r' con(\d+) ', cmdline)
    match = re_session_id.search(cmdline)
    if match:
        res['session_id'] = match.group(1)
    else:
        res['session_id'] = "-404"

    #match = re.search(r' cmd(\d+) ', cmdline)
    match = re_cmdno.search(cmdline)
    if match:
        res['cmdno'] = match.group(1)
    else:
        res['cmdno'] = "-404"

    #match = re.search(r' seg(\d+) ', cmdline)
    match = re_content.search(cmdline)
    if match:
        res['content'] = match.group(1)
    else:
        res['content'] = "-404"

    if is_mdw_host:
        #res['content'] = -1
        res['slice'] = "-404"
        if "idle in transaction" in cmdline:
            res['sqlcmd'] = "idle in transaction"
        elif "idle" in cmdline:
            res['sqlcmd'] = "idle"
        else:
            res['sqlcmd'] = parts[ len(parts) - 1 ]
    else:
        #match = re.search(r' slice(\d+) ', cmdline)
        match = re_slice.search(cmdline)
        if match:
            res['slice'] = match.group(1)
        else:
            res['slice'] = "-404"

        if "idle in transaction" in cmdline:
            res['sqlcmd'] = "idle in transaction"
        elif "idle" in cmdline:
            res['sqlcmd'] = "idle"
        else:
            res['sqlcmd'] = parts[ len(parts) - 1 ]

    return res



def multiple_substrings_test(target, substrs):
    for substr in substrs:
        if substr in target:
            return True
    return False


ignore_procs = [
    "master logger process",
    "checkpointer",
    "background writer",
    "walwriter",
    "stats collector",
    "login monitor",
    "dtx recovery process",
    "ftsprobe process",
    "logical replication launcher",
    "ic proxy process",
    "pg_cron launcher",
    "sweeper process",
    "walsender",
    "logger",
    "startup recovering",
    "walreceiver streaming",
    "python",
    "java",
    "gp_role=execute",
    "systemd",
    "cbmon"]

is_mdw_host = is_mdw()



'''
# Full list
for proc in psutil.process_iter(['cmdline', 'cpu_affinity', 'cpu_num', 'cpu_percent', 'cpu_times', 'create_time', 'cwd', 'environ', 'exe', 'gids', 'io_counters', 'ionice', 'memory_full_info', 'memory_info', 'memory_maps', 'memory_percent', 'name', 'nice', 'num_ctx_switches', 'num_fds', 'num_threads', 'open_files', 'pid', 'ppid', 'status', 'terminal', 'threads', 'uids', 'username']):
'''
for proc in psutil.process_iter(['cmdline', 'cpu_percent', 'cpu_times', 'create_time', 'io_counters', 'memory_full_info', 'memory_percent', 'name', 'num_ctx_switches', 'pid', 'status', 'username']):
    if proc.info['username'] == "gpadmin":
        #and proc.info['terminal'] is None:
        if len(proc.info['cmdline']) == 0:
            continue

        if multiple_substrings_test(proc.info['cmdline'][0], ignore_procs):
            continue

        results = is_backend(proc.info['cmdline'][0])
        if results is False:
            continue

        results['hostname'] = hostname
        results['period'] = current_time
        results['pid'] = proc.info['pid']
        results['status'] = proc.info['status']
        results['create_ts'] = proc.info['create_time']

        # disk i/o
        #if 'io_counters' in proc.info:
        try:
            results['read_count'] = proc.info['io_counters'].read_count
            results['read_bytes'] = proc.info['io_counters'].read_bytes
            results['write_count'] = proc.info['io_counters'].write_count
            results['write_bytes'] = proc.info['io_counters'].write_bytes
        except:
            pass

        # memory
        results['rss'] = proc.info['memory_full_info'].rss
        results['vms'] = proc.info['memory_full_info'].vms
        results['shared'] = proc.info['memory_full_info'].shared
        results['data'] = proc.info['memory_full_info'].data
        results['dirty'] = proc.info['memory_full_info'].dirty
        results['uss'] = proc.info['memory_full_info'].uss
        results['pss'] = proc.info['memory_full_info'].pss
        results['swap'] = proc.info['memory_full_info'].swap
        results['mempct'] = proc.info['memory_percent']

        # cpu
        try:
            results['cpu_usr'] = proc.info['cpu_times'].user
            results['cpu_sys'] = proc.info['cpu_times'].system
            results['cpu_iowait'] = proc.info['cpu_times'].iowait
        except:
            pass

        # context switches
        results['ctxsw_vol'] = proc.info['num_ctx_switches'].voluntary
        results['ctxsw_invol'] = proc.info['num_ctx_switches'].involuntary

        print( json.dumps(results) )
        #exit(0)
