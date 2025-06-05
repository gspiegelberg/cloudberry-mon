BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1018, 'sar_reader -B paging statistics');

CREATE EXTERNAL WEB TABLE cbmon.__paging_segments_today(
	hostname  text,
	period    timestamptz,
	pgpgins   float,
	pgpgouts  float,
	faults    float,
	majflts   float,
	pgfrees   float,
	pgscanks  float,
	pgscands  float,
	pgsteals  float,
	vmeff_pct float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -S "-B"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__paging_master_today(
        hostname  text,
        period    timestamptz,
	pgpgins   float,
	pgpgouts  float,
	faults    float,
	majflts   float,
	pgfrees   float,
	pgscanks  float,
	pgscands  float,
	pgsteals  float,
	vmeff_pct float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -S "-B"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_paging_today AS
SELECT * FROM cbmon.__paging_segments_today
UNION
SELECT * FROM cbmon.__paging_master_today;


CREATE EXTERNAL WEB TABLE cbmon.__paging_segments_yesterday(
	hostname  text,
	period    timestamptz,
	pgpgins   float,
	pgpgouts  float,
	faults    float,
	majflts   float,
	pgfrees   float,
	pgscanks  float,
	pgscands  float,
	pgsteals  float,
	vmeff_pct float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -p -S "-B"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__paging_master_yesterday(
        hostname  text,
        period    timestamptz,
	pgpgins   float,
	pgpgouts  float,
	faults    float,
	majflts   float,
	pgfrees   float,
	pgscanks  float,
	pgscands  float,
	pgsteals  float,
	vmeff_pct float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -p -S "-B"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_paging_yesterday AS
SELECT * FROM cbmon.__paging_segments_yesterday
UNION
SELECT * FROM cbmon.__paging_master_yesterday;


CREATE EXTERNAL WEB TABLE cbmon.__paging_segments_all(
	hostname  text,
	period    timestamptz,
	pgpgins   float,
	pgpgouts  float,
	faults    float,
	majflts   float,
	pgfrees   float,
	pgscanks  float,
	pgscands  float,
	pgsteals  float,
	vmeff_pct float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-B"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__paging_master_all(
        hostname  text,
        period    timestamptz,
	pgpgins   float,
	pgpgouts  float,
	faults    float,
	majflts   float,
	pgfrees   float,
	pgscanks  float,
	pgscands  float,
	pgsteals  float,
	vmeff_pct float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-B"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_paging_all AS
SELECT * FROM cbmon.__paging_segments_all
UNION
SELECT * FROM cbmon.__paging_master_all;


COMMIT;
