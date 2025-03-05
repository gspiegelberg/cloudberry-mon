Database Metric Gathering & Health Dashboard Backend

About:
========================================================================

CBmon is a set of scripts & schema to permit observability of one or many
CloudberryDB clusters in the abscence of Greenplum Command Center (GPCC). Very
likely can also monitor Greenplum (Broadcom) however equally likely to be
compatibility issues as one is now closed source.

Benefits, unlike GPCC, are that this system will catch up even when the database
is down. It leverages sar logs specifically those created by sysstat 11.7 found
in RHEL 8 and variants. As long as those files are being written to host metrics
will eventually appear.

Why not Prometheus? It's a fine product designed to do many things. Desire was
ease of extensibility without having to learn other tech's or languages,
maintainable, & live data direct from Cloudberry cluster. Tradeoffs.

Working Configurations:
========================================================================
 * RHEL 8 hosts
 * pre-Apache Cloudberry 1.6.0 & Apache Cloudberry main branch
 * RHEL 8 based CBmon PostgreSQL

Untested & needs work:
 * RHEL 9 hosts
 * Greenplum 6 & 7


Features:
========================================================================

 * Provides database on which any dashboard can be built (prefer grafana)

 * Ability to house data from one or many clusters

 * Remote access to Cloudberry catalogs

 * Method to collect host performance metrics stored in sar files

 * Remote execution of functions in Cloudberry

 * Easily extensible to pull additional information from remote Cloudberry
   cluster

 * Post data load functionality to create summaries or specific data points

 * Data kept as long as necessary or wanted

 * Requires only 2 scheduled jobs: data gathering, historical data management


Host Configuration:
========================================================================

More frequent intervals for sysstat is recommended otherwise metrics get watered
down as many from the system are averages between collection periods.

1. Install sysstat everywhere
```
gpssh -f allhosts sudo dnf -y install sysstat
```

2. Modify all cluster hosts to override sysstat-collect.timer to once/minute
```
sudo systemctl edit sysstat-collect.timer
```

   Paste:
```
   [Timer]
   OnCalendar=*:00/1
```
 
3. Creates ```/etc/systemd/system/sysstat-collect.timer.d/override.conf```   2. Reloads systemctl daemon-reload

   Automation:
```
cat << EOL > override.conf
[Timer]
OnCalendar=*:00/1
EOL

gpsync -f allhosts override.conf =:/tmp
gpssh -f allhosts sudo mkdir -p /etc/systemd/system/sysstat-collect.timer.d
gpssh -f allhosts sudo install -o root -g root -m 0644 /tmp/override.conf /etc/systemd/system/sysstat-collect.timer.d
gpssh -f allhosts rm -f /tmp/override.conf
gpssh -f allhosts sudo systemctl daemon-reload
gpssh -f allhosts sudo systemctl start sysstat-collect.timer
gpssh -f allhosts sudo systemctl enable sysstat-collect.timer
```
   NOTE for RHEL 9 variants:
```
   gpssh -f allhosts sudo systemctl start sysstat
   gpssh -f allhosts sudo systemctl enable sysstat
```
   RHEL 8/9 verify: Files should grow once/minute in ```/var/log/sa```
```
   ls -l /var/log/sa
   sar -f /var/log/sa/saDD -b
```
4. Copy tar to all hosts
```
gpsync -f allhosts cbmon.tar.gz =:/tmp
```

5. Unpack tar in ```/usr/local```
```
gpssh -f allhosts sudo tar xpfz /tmp/cbmon.tar.gz -C /usr/local
```

6. Change ownership

   gpssh -f allhosts sudo chown -R gpadmin:gpadmin /usr/local/cbmon


Cloudberry Configuration:
========================================================================
1. Change to alters directory
```
cd /usr/local/cbmon/alters/cloudberry
```

2. Load each in numeric order
```
/usr/local/cbmon/bin/load_cbalters -d MYDB -p PORT -U gpadmin
```

3. Configure pg_hba.conf to allow remote connections from PostgreSQL host
   & reload
```
gpstop -u
```


PostgreSQL Metrics Database Host Only
========================================================================

1. Unpack 
```
sudo tar xpfz /tmp/cbmon.tar.gz -C /usr/local
```

2. Change ownership to postgres
```
sudo chown -R postgres:postgres /usr/local/cbmon
```

3. Install PostgreSQL 16, pg_partman and grafana packages. No conceivable reason a version of PostgreSQL >=16 would not work.
```
dnf -y install postgresql16 postgresql16-contrib postgresql16-server grafana pg_partman_16
```

4. Initialize PostgreSQL

5. Create ```cbmon``` role with SUPERUSER privs

6. Create ```cbmon``` database owned by role ```cbmon```

7. Load alters in order
```
/usr/local/cbmon/bin/load_pgalters -d cbmon -p PORT -U cbmon
```
    
8. Configure ```postgresql.conf``` per alter output permitting ```pg_partman``` usage
```
    shared_preload_libraries = 'pg_partman_bgw'
    pg_partman_bgw.interval = 3600'
    pg_partman_bgw.role = 'partman'
    pg_partman_bgw.dbname = 'cbmon'
```
7. Configure pg_hba.conf to permit grafana & cbmon user access & restart
```
systemctl restart postgresql-16
```

8. Configure grafana for your environment & start
```
systemctl start grafana
```

9. Enable PostgreSQL & grafana to start on reboot
```
systemctl enable postgresql-16
systemctl enable grafana
```


Option 1 - Enabling systemd loader process
========================================================================

1. Edit ```etc/config``` and ```cbmon_loader.service``` to reflect cluster ID

2. Install service file replacing <<CLUSTER_ID>> with cluster ID
```
   sudo install -o root -g root -m 0644 \
     /usr/local/cbmon/etc/cbmon_loader.service \
     /etc/systemd/system/cbmon_loader-c<<CLUSTER_ID>>.service
```
3. Reload
```
sudo systemctl daemon-reload
```

4. Start, verify and enable replacing <<CLUSTER_ID>> with cluster ID
```
sudo systemctl start cbmon_loader-c<<CLUSTER_ID>>
sudo systemctl status cbmon_loader-c<<CLUSTER_ID>>
sudo systemctl enable cbmon_loader-c<<CLUSTER_ID>>
```

Option 2 - Enabling Message Driven Loader
========================================================================

Cloudberry clusters can be large with high core counts and with sysstat-collect.timer tuned
running once/minute, files in ```/var/log/sa``` can become large. This can delay delivering
metrics to ```cbmon``` database and ultimately grafana or whatever visualization tech is used.

Implementing a loader process capable of performing metrics load work in parallel is ncessary
versus the original systemd loader running serially.

Unlike cbmon_loader.service, parallel_loader is not configured to a specific cluster
therefore able to service requests for any.

1. Install RabbitMQ & configure adding users, vhost and queues
2. Install python3 pika module
```
sudo pip3 install pika
```
3. Configure ```etc/config.ini``` for RabbitMQ instance
4. Install ```parallel_loader.service``` in ```/etc/systemd/system```
5. Reload systemd, start and enable new service
```
sudo systemctl daemon-reload
sudo systemctl start parallel_loader.service
sudo systemctl enable parallel_loader.service
```

6. Create cron jobs for each cluster
```
* * * * * PYTHONPATH=/usr/local/cbmon/bin/pylib /usr/local/cbmon/bin/send_loader_request --config /usr/local/cbmon/etc/config.ini -C <<CLUSTER_ID>> --load-all
```



Enabling summaries process
========================================================================

1. Edit ```etc/config``` and ```cbmon_summaries.service``` to reflect cluster ID

2. Install service file replacing <<CLUSTER_ID>> with cluster ID
```
   sudo install -o root -g root -m 0644 \
     /usr/local/cbmon/etc/cbmon_summaries.service \
     /etc/systemd/system/cbmon_summaries-c<<CLUSTER_ID>>.service
```

3. Reload
```
sudo systemctl daemon-reload
```

4. Start, verify and enable replacing <<CLUSTER_ID>> with cluster ID
```
sudo systemctl start cbmon_summaries-c<<CLUSTER_ID>>
sudo systemctl status cbmon_summaries-c<<CLUSTER_ID>>
sudo systemctl enable cbmon_summaries-c<<CLUSTER_ID>>
```


