BEGIN;


INSERT INTO cbmon.alters (id, summary) VALUES
( 1019, 'active backends shows resource consumption of running queries');


DROP VIEW IF EXISTS cbmon.live_backends;
DROP EXTERNAL TABLE IF EXISTS cbmon._live_master_backends;
DROP EXTERNAL TABLE IF EXISTS cbmon._live_segment_backends;

CREATE EXTERNAL WEB TABLE cbmon._live_master_backends(
	j json
) EXECUTE '/usr/local/cbmon/bin/active_backends.py' ON MASTER
  FORMAT 'TEXT' (FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon._live_segment_backends(
	j json
) EXECUTE '/usr/local/cbmon/bin/active_backends.py' ON HOST
  FORMAT 'TEXT' (FILL MISSING FIELDS);

CREATE VIEW cbmon.live_backends AS
SELECT j->>'hostname' AS hostname
     , to_timestamp((j->>'period')::float) AS period
     , (j->>'create_ts')::float AS create_ts
     , (j->>'pid')::int AS pid
     , j->>'status' AS status
     , (j->>'server_port')::int AS server_port
     , j->>'role' AS role
     , j->>'database' AS database
     , (j->>'client_ip')::inet AS client_ip
     , (j->>'client_port')::int AS client_port
     , (j->>'session_id')::int AS session_id
     , (j->>'cmdno')::int AS cmdno
     , (j->>'content')::int AS content
     , (j->>'slice')::int AS slice
     , j->>'sqlcmd' AS sqlcmd
     , (j->>'read_count')::bigint AS read_count
     , (j->>'read_bytes')::bigint AS read_bytes
     , (j->>'write_count')::bigint AS write_count
     , (j->>'write_bytes')::bigint AS write_bytes
     , (j->>'rss')::bigint AS rss
     , (j->>'vms')::bigint AS vms
     , (j->>'shared')::bigint AS shared
     , (j->>'data')::bigint AS data
     , (j->>'dirty')::bigint AS dirty
     , (j->>'uss')::bigint AS uss
     , (j->>'pss')::bigint AS pss
     , (j->>'swap')::bigint AS swap
     , (j->>'mempct')::float AS mempct
     , (j->>'cpu_usr')::float AS cpu_usr
     , (j->>'cpu_sys')::float AS cpu_sys
     , (j->>'cpu_iowait')::float AS cpu_iowait
     , (j->>'ctxsw_vol')::int AS ctxsw_vol
     , (j->>'ctxsw_invol')::int AS ctxsw_invol
  FROM (
SELECT j FROM cbmon._live_master_backends
UNION ALL
SELECT j FROM cbmon._live_segment_backends) src;

COMMIT;

