BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1003, 'ext tables to determine uptime of database and storage device info');

CREATE EXTERNAL WEB TABLE cbmon.dbuptime(
  uptime  timestamp
) EXECUTE 'stat -c %y $MASTER_DATA_DIRECTORY/postmaster.pid | awk ''{printf("%s %s",$1,$2)}''' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);


/**
 * To map dev<major>:<minor> to device & mount point
 */
CREATE EXTERNAL WEB TABLE cbmon.__storage_segments(
        hostname text,
	device   text,
	mntpt    text,
	major    int,
	minor    int
) EXECUTE '/usr/local/cbmon/bin/partitions.sh' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);


CREATE EXTERNAL WEB TABLE cbmon.__storage_master(
        hostname text,
	device   text,
	mntpt    text,
	major    int,
	minor    int
) EXECUTE '/usr/local/cbmon/bin/partitions.sh' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

/**
 * Should be refreshed periodically in case storage is swapped in & out
 */
CREATE MATERIALIZED VIEW cbmon._storage AS
SELECT now()::timestamptz AS period
     , s.hostname, s.device, s.mntpt, s.major, s.minor, format('dev%s-%s', s.major, s.minor) AS diskdevice
  FROM cbmon.__storage_segments s 
UNION
SELECT now()::timestamptz AS period
     , s.hostname, s.device, s.mntpt, s.major, s.minor, format('dev%s-%s', s.major, s.minor) AS diskdevice
  FROM cbmon.__storage_master s
WITH DATA;


COMMIT;
