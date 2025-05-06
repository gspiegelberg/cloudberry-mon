/**
 * Adjustments to alter-1045
 */
BEGIN;

INSERT INTO public.alters (id,summary) VALUES
( 1047, 'replaces alter 1045, adds query logging' );

/**
 * integer -> bigint conversion for existing tables including templates
 */
DO $$
BEGIN
RAISE NOTICE 'WARN: May take time depending on number of configured clusters and size of existing tables';
END $$;

DO $$
DECLARE
	rec record;
BEGIN
	FOR rec IN SELECT schemaname,relname FROM pg_stat_user_tables
	 WHERE relname = 'query_historical_statistics'
	LOOP
		EXECUTE 'ALTER TABLE '||rec.schemaname||'.'||rec.relname|| '
 ALTER COLUMN elapsed_t TYPE bigint,
 ALTER COLUMN tot_sys_t TYPE bigint,
 ALTER COLUMN tot_user_t TYPE bigint,
 ALTER COLUMN maxrss_kb TYPE bigint,
 ALTER COLUMN inblock TYPE bigint,
 ALTER COLUMN outblock TYPE bigint,
 ALTER COLUMN majflt TYPE bigint,
 ALTER COLUMN minflt TYPE bigint,
 ALTER COLUMN nvcsw TYPE bigint,
 ALTER COLUMN nivcsw TYPE bigint';
	END LOOP;
END $$;


/**
 * Query store
 */
CREATE TABLE templates.query_historical(
	period      timestamp with time zone NOT NULL,
	first_time  timestamp with time zone,
	last_time   timestamp with time zone,
	session     integer,
	cmdcount    integer,
	statement   text
);

CREATE INDEX ON templates.query_historical (period);
CREATE INDEX ON templates.query_historical (first_time, session, cmdcount);

/**
 * Summary, useful for faster access permitting drill-down
 */
CREATE TABLE templates.query_historical_summary(
	period      timestamp with time zone NOT NULL,
	last_time   timestamp with time zone,
	username    varchar(256),
	session     integer,
	cmdcount    integer,
	elapsed_t   bigint,
	tot_sys_t   bigint,
	tot_user_t  bigint,
	maxrss_kb   bigint,
	inblock     bigint,
	outblock    bigint,
	majflt      bigint,
	minflt      bigint,
	nvcsw       bigint,
	nivcsw      bigint,
	statement   text
);

CREATE INDEX ON templates.query_historical_summary (period);
CREATE INDEX ON templates.query_historical_summary (last_time, username);


/**
 * Replacement incorporating query logging
 */
CREATE OR REPLACE FUNCTION public.gen_query_historical_statistics(
	v_cluster_id int
	, v_prime boolean
) RETURNS VOID AS $$
DECLARE
	cmetrics     text;
	way_behind   boolean;
	qs_table     text;
	max_period   timestamptz;
	sql          text;
	cl_table     text;
BEGIN
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	/**
	 * query_historical & query_historical_summary not covered by PROC load()
	 */
	PERFORM * FROM public.check_metric_table( v_cluster_id, 'query_historical' );
	PERFORM * FROM public.check_metric_table( v_cluster_id, 'query_historical_summary' );

	EXECUTE format('SELECT max(period) FROM %s.query_historical_statistics', cmetrics)
	   INTO max_period;

	/**
	 * v_prime will use 24hrs table if true but 7days table should be avoided.
	 * Churning though days of logs in an active cluster can take a very long
	 * time. If implemented, proceed with caution.
	 */
	IF v_prime AND max_period IS NULL THEN
		qs_table := '__query_stats_24hrs';
		cl_table := '__coordinator_log_24hrs';
		max_period := now() - interval'24 hours';
	ELSIF NOT v_prime AND max_period IS NULL THEN
		qs_table := '__query_stats_1hr';
		cl_table := '__coordinator_log_1hr';
		max_period := now() - interval'1 hour';
	ELSIF max_period < now() - interval'1 hour' THEN
		qs_table := '__query_stats_24hrs';
		cl_table := '__coordinator_log_24hrs';
	ELSE
		qs_table := '__query_stats_1hr';
		cl_table := '__coordinator_log_1hr';
	END IF;

	sql := format(
'INSERT INTO %s.query_historical_statistics
SELECT gsc.hostname                         AS hostname
     , now() AS period
     , logtime::timestamptz                 AS logtime
     , substr(loguser,1,256)                AS username
     , replace(logpid,''p'','''')::int          AS pid
     , replace(replace(logthread,''th-'',''''),''th'','''')::bigint  AS thread
     , logtransaction::int                  AS xact
     , replace(logsession,''con'','''')::int    AS session
     , replace(logcmdcount,''cmd'','''')::int   AS cmdcount
     , replace(logsegment,''seg'','''')::int    AS segment
     , replace(logslice,''slice'','''')::int    AS slice
     , replace(logdistxact,''dx'','''')::int    AS distxact
     , replace(loglocalxact,''x'','''')::int    AS localxact
     , replace(logsubxact,''sx'','''')::int     AS subxact
     , substr(logseverity,1,10)             AS severity
     , substr(logstate,1,10)                AS state
     , elapse_t::int                        AS elapsed_t
     , tot_sys_t::int                       AS tot_sys_t
     , tot_user_t::int                      AS tot_user_t
     , ru_maxrss_kb::int                    AS maxrss_kb
     , raw_ru_inblock::int                  AS inblock
     , raw_ru_outblock::int                 AS outblock
     , ru_majflt::int                       AS majflt
     , ru_minflt::int                       AS minflt
     , raw_ru_nvcsw::int                    AS nvcsw
     , raw_rn_nivcsw::int                   AS nivcsw
  FROM %s.%s q
       JOIN %s.cat_gp_segment_configuration gsc
         ON (replace(q.logsegment,''seg'','''')::int = gsc.content)
       JOIN public.cluster_hosts ch
         ON (gsc.hostname IN (ch.hostname, ch.altname))
 WHERE logtime::timestamptz > %s::timestamptz
 ORDER BY 1, 2'
	, cmetrics, cmetrics, qs_table, cmetrics, quote_literal(max_period)
);
	EXECUTE sql;

	sql := format(
'CREATE TEMP TABLE %s_clog AS SELECT replace(c.logsession, ''con'', '''')::int AS session
     , replace(c.logcmdcount, ''cmd'', '''')::int AS cmdcount
     , logdebug AS statement
  FROM %s.%s c
 WHERE logmessage = ''QUERY STATISTICS''
   AND ( -- query types of interest
          logdebug ~* ''select ''
       OR logdebug ~* ''create ''
       OR logdebug ~* ''insert ''
       OR logdebug ~* ''update ''
       OR logdebug ~* ''delete ''
       OR logdebug ~* ''declare ''
       OR logdebug ~* ''fetch ''
       OR logdebug ~* ''call ''
       OR logdebug ~* ''alter ''
       OR logdebug ~* ''copy ''
       )'
	, cmetrics, cmetrics, cl_table
	);
	EXECUTE sql;

	sql := format(
'INSERT INTO %s.query_historical
SELECT q.period
     , min(q.logtime) AS first_time
     , max(q.logtime) AS last_time
     , q.session, q.cmdcount, c.statement
  FROM %s.query_historical_statistics q
       JOIN %s_clog c
         ON (q.session = c.session AND
             q.cmdcount = c.cmdcount)
 GROUP BY 1, 4, 5, 6'
	, cmetrics, cmetrics, cmetrics
	);
	EXECUTE sql;

	sql := format(
'INSERT INTO %s.query_historical_summary
SELECT qhs.period
     , qh.last_time
     , username
     , qh.session
     , qh.cmdcount
     , sum(elapsed_t) AS elapsed
     , sum(tot_sys_t) AS tot_sys_t
     , sum(tot_user_t) AS tot_user_t
     , sum(maxrss_kb) AS maxrss_kb
     , sum(inblock) AS inblock
     , sum(outblock) AS outblock
     , sum(majflt) AS majflt
     , sum(minflt) AS minflt
     , sum(nvcsw) AS nvcsw
     , sum(nivcsw) AS nivcsw
     , qh.statement
  FROM %s.query_historical qh JOIN %s.query_historical_statistics qhs
       ON (qh.session = qhs.session
           AND qh.cmdcount = qhs.cmdcount
           AND qhs.logtime BETWEEN qh.first_time AND qh.last_time)
 WHERE qhs.period >= %s
 GROUP BY 1, 2, 3, 4, 5, 16'
	, cmetrics, cmetrics, cmetrics, quote_literal(max_period)
	);
	EXECUTE sql;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';


COMMIT;

