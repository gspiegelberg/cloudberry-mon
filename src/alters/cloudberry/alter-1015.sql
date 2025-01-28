/**
 * 1. Update /usr/local/cbmon on all hosts
 * 2. Execute this alter on all Cloudberry clusters before
 *    alters/postgresql/alter-1042.sql
 * 3. Execute alters/postgresql/alter-1042.sql on PostgreSQL
 *    cbmon database
 */
BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1015, 'add disk device serial');

DROP MATERIALIZED VIEW cbmon._storage;
DROP EXTERNAL TABLE cbmon.__storage_segments;
DROP EXTERNAL TABLE cbmon.__storage_master;

/**
 * To map dev<major>:<minor> to device & mount point
 */
CREATE EXTERNAL WEB TABLE cbmon.__storage_segments(
        hostname text,
	device   text,
	mntpt    text,
	major    int,
	minor    int,
	volserial text
) EXECUTE '/usr/local/cbmon/bin/partitions.sh' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);


CREATE EXTERNAL WEB TABLE cbmon.__storage_master(
        hostname text,
	device   text,
	mntpt    text,
	major    int,
	minor    int,
	volserial text
) EXECUTE '/usr/local/cbmon/bin/partitions.sh' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

/**
 * Should be refreshed periodically in case storage is swapped in & out
 */
CREATE MATERIALIZED VIEW cbmon._storage AS
SELECT now()::timestamptz AS period
     , s.hostname, s.device, s.mntpt, s.major, s.minor, format('dev%s-%s', s.major, s.minor) AS diskdevice, s.volserial
  FROM cbmon.__storage_segments s 
UNION
SELECT now()::timestamptz AS period
     , s.hostname, s.device, s.mntpt, s.major, s.minor, format('dev%s-%s', s.major, s.minor) AS diskdevice, s.volserial
  FROM cbmon.__storage_master s
WITH DATA;


COMMIT;
