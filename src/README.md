Database Metric Gathering & Health Dashboard

About:
========================================================================

MeGaHeDa because I think it's fun & funny. Just a nickname. Will be referred to as cbmon.

MeGaHeDa is a set of scripts & schema to permit observability of one or many CloudberryDB
clusters in the abscence of Greenplum Command Center (GPCC). Could potentially also monitor
Greenplum (Broadcom) however there will likely be issues with differences between the two.

Benefits, unlike GPCC, are that this system will catch up even when the database is down.
It leverages sar logs specifically those created by sysstat 11.7 found in RHEL 8 and variants.
As long as those files are being written to host metrics will eventually appear.

Features:
========================================================================

1. Provides database on which any dashboard can be built (prefer grafana)

2. Ability to house data from one or many clusters

3. Remote access to Cloudberry catalogs

4. Method to collect host performance metrics stored in sar files

5. Remote execution of functions in Cloudberry

6. Easily extensible to pull additional information from remote Cloudberry cluster

7. Post data load functionality to create summaries or specific data points

8. Data kept as long as necessary

9. Requires only 2 scheduled jobs: data gathering, historical data management


Host Configuration:
========================================================================

More frequent intervals for sysstat is recommended otherwise metrics get watered down as many
from the system are averages between collection periods.

1. Install sysstat everywhere
   gpssh -f allhosts sudo dnf -y install sysstat

2. Modify all cluster hosts to override sysstat-collect.timer to once/minute
   sudo systemctl edit sysstat-collect.timer

   Paste:
   [Timer]
   OnCalendar=*:00/1

   NOTE in case of automation:
   1. Creates /etc/systemd/system/sysstat-collect.timer.d/override.conf
   2. Reloads systemctl daemon-reload

   Automation:
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
   

3. Copy tar to all hosts
   gpsync -f allhosts cbmon.tar.gz =:/tmp

4. Unpack tar in /usr/local
   gpssh -f allhosts sudo tar xpfz /tmp/cbmon.tar.gz -C /usr/local

5. Change ownership
   gpssh -f allhosts sudo chown -R gpadmin:gpadmin /usr/local/cbmon


Cloudberry Configuration:
========================================================================
1. Create sar database
    createdb cbmon

2. Change to alters directory
    cd /usr/local/cbmon/alters/cloudberry

3. Load each in numeric order
    psql -d cbmon -f alter-1000.sql
    psql -d cbmon -f alter-1001.sql
    psql -d cbmon -f alter-1002.sql
    psql -d cbmon -f alter-XXXX.sql

4. Configure pg_hba.conf to allow remote connections from PostgreSQL host & reload
    gpstop -u


PostgreSQL Metrics Database Host Only
========================================================================

1. Unpack
   sudo tar xpfz /tmp/cbmon.tar.gz -C /usr/local

2. Change ownership to postgres
   sudo chown -R postgres:postgres /usr/local/cbmon

3. Install PostgreSQL 16, pg_partman and grafana packages
    dnf -y install postgresql16 postgresql16-contrib postgresql16-server grafana pg_partman_16

4. Initialize PostgreSQL

5. Load alters in order
    cd /usr/local/cbmon/alters/postgresql
    psql -d cbmon -f alter-1000.sql
    psql -d cbmon -f alter-1001.sql
    psql -d cbmon -f alter-1002.sql
    psql -d cbmon -f alter-XXXX.sql

6. Configure postgresql.conf per alter output permitting pg_partman usage
    shared_preload_libraries = 'pg_partman_bgw'
    pg_partman_bgw.interval = 3600'
    pg_partman_bgw.role = 'partman'
    pg_partman_bgw.dbname = 'cbmon'

7. Configure pg_hba.conf to permit grafana & cbmon user access & restart
    systemctl restart postgresql-16

8. Configure grafana for your environment & start
    systemctl start grafana

9. Enable PostgreSQL & grafana to start on reboot
    systemctl enable postgresql-16
    systemctl enable grafana



Enabling loader process
========================================================================

1. Edit etc/config and cbmon_loader.service to reflect cluster ID

2. Install service file replacing <<CLUSTER_ID>> with cluster ID
   sudo install -o root -g root -m 0644 \
     /usr/local/cbmon/etc/cbmon_loader.service \
     /etc/systemd/system/cbmon_loader-c<<CLUSTER_ID>>.service

3. Reload
   sudo systemctl daemon-reload

4. Start, verify and enable replacing <<CLUSTER_ID>> with cluster ID
   sudo systemctl start cbmon_loader-c<<CLUSTER_ID>>
   sudo systemctl status cbmon_loader-c<<CLUSTER_ID>>
   sudo systemctl enable cbmon_loader-c<<CLUSTER_ID>>



Enabling summareies process
========================================================================

1. Edit etc/config and cbmon_summaries.service to reflect cluster ID

2. Install service file replacing <<CLUSTER_ID>> with cluster ID
   sudo install -o root -g root -m 0644 \
     /usr/local/cbmon/etc/cbmon_summaries.service \
     /etc/systemd/system/cbmon_summaries-c<<CLUSTER_ID>>.service

3. Reload
   sudo systemctl daemon-reload

4. Start, verify and enable replacing <<CLUSTER_ID>> with cluster ID
   sudo systemctl start cbmon_loader-c<<CLUSTER_ID>>
   sudo systemctl status cbmon_loader-c<<CLUSTER_ID>>
   sudo systemctl enable cbmon_loader-c<<CLUSTER_ID>>



