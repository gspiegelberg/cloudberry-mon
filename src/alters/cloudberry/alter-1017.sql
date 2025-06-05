BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1017, 'sar_reader -w proc/s & context switch tables');

CREATE EXTERNAL WEB TABLE cbmon.__cputask_segments_today(
	hostname text,
	period   timestamptz,
	procs  float,
	cswch  float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -S "-w"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__cputask_master_today(
        hostname text,
        period   timestamptz,
	procs  float,
	cswch  float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -S "-w"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_cputask_today AS
SELECT * FROM cbmon.__cputask_segments_today
UNION
SELECT * FROM cbmon.__cputask_master_today;


CREATE EXTERNAL WEB TABLE cbmon.__cputask_segments_yesterday(
	hostname text,
	period   timestamptz,
	procs  float,
	cswch  float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -p -S "-w"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__cputask_master_yesterday(
        hostname text,
        period   timestamptz,
	procs  float,
	cswch  float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -p -S "-w"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_cputask_yesterday AS
SELECT * FROM cbmon.__cputask_segments_yesterday
UNION
SELECT * FROM cbmon.__cputask_master_yesterday;


CREATE EXTERNAL WEB TABLE cbmon.__cputask_segments_all(
	hostname text,
	period   timestamptz,
	procs  float,
	cswch  float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-w"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__cputask_master_all(
        hostname text,
        period   timestamptz,
	procs  float,
	cswch  float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-w"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_cputask_all AS
SELECT * FROM cbmon.__cputask_segments_all
UNION
SELECT * FROM cbmon.__cputask_master_all;

COMMIT;

