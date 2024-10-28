/**
 * Functions cannot be directly called via postgres_fdw.
 * Solution for relatively static information is provide a
 * MAT VIEW which can be pulled via postgres_fdw.
 *
 * Not perfect but permits scheduling according to transaction
 * current time based upon minute of the year.
 * Examples:
 *   freq 1 = every minute
 *   freq 5 = every 5 minutes
 *   freq 1440 = every 24 hours
 *   freq 10080 = once a week
 *   freq 43200 = every 30 days or roughly once per month
 *   freq 129600 = once every 90 days or per quarter (roughly)
 *   freq 525600 = once in any year
 *   freq 527040 = once in a leap year
 *
 * DO NOT CHANGE now() to clock_timestamp()
 * If in a long running execution a window could be missed
 */
BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1006, 'able to restore MAT VIEWs periodically');

CREATE TABLE cbmon.matviews(
	ts        timestamptz NOT NULL DEFAULT now(),
	mvname    varchar(256) NOT NULL,
	frequency int NOT NULL 
) DISTRIBUTED RANDOMLY;


CREATE OR REPLACE FUNCTION cbmon.minutes_in_year()
RETURNS int AS $$
SELECT extract(epoch from
	(date_trunc('year', now())::timestamp + interval'1 year') -
	(date_trunc('year',now())::timestamp))::int / 60;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION cbmon.minute_of_year()
RETURNS int AS $$
SELECT extract(epoch from
	(now()::timestamp -
	 date_trunc('year', now())::timestamp))::int / 60;
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION cbmon.matview_maintenance()
RETURNS boolean AS $$
DECLARE
	moy     int;
	rec     record;
	sql     text;
BEGIN
	moy := cbmon.minute_of_year();

	FOR rec IN
		SELECT * FROM cbmon.matviews
		 WHERE moy % frequency = 0
	LOOP
		sql := format(
			'REFRESH MATERIALIZED VIEW cbmon.%s WITH DATA',
			rec.mvname
		);
		EXECUTE sql;
	END LOOP;

	RETURN true;
END;
$$ LANGUAGE 'plpgsql';


CREATE VIEW cbmon.matview_refresh AS
SELECT * FROM cbmon.matview_maintenance();


INSERT INTO cbmon.matviews (mvname, frequency) VALUES
( '_storage', 10080 );


COMMIT;
