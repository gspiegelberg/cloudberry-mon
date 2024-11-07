BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1013, 'permit live uptime / load feedback' );


CREATE READABLE EXTERNAL WEB TABLE cbmon.__uptime_segments(
        hostname     text,
        uptime       float,
        ldavg_1      float,
        ldavg_5      float,
        ldavg_15     float,
        running_proc int,
        total_proc   int,
        last_pid     int
) EXECUTE 'awk -v hn=$(hostname) -v upt=$(awk ''{print $1}'' /proc/uptime) ''{gsub(/\//," ",$4);printf("%s %s %s\n",hn,upt,$0)}'' /proc/loadavg' ON HOST
  FORMAT 'TEXT' (DELIMITER ' '
                FILL MISSING FIELDS);


CREATE READABLE EXTERNAL WEB TABLE cbmon.__uptime_master(
	hostname     text,
	uptime       float,
	ldavg_1      float,
	ldavg_5      float,
	ldavg_15     float,
	running_proc int,
	total_proc   int,
	last_pid     int
) EXECUTE 'awk -v hn=$(hostname) -v upt=$(awk ''{print $1}'' /proc/uptime) ''{gsub(/\//," ",$4);printf("%s %s %s\n",hn,upt,$0)}'' /proc/loadavg' ON MASTER
  FORMAT 'TEXT' (DELIMITER ' '
                FILL MISSING FIELDS);


CREATE VIEW cbmon._live_uptime AS
SELECT * FROM cbmon.__uptime_segments
UNION
SELECT * FROM cbmon.__uptime_master;


COMMIT;
