BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1040, 'gather query execution statistics from segment logs' );


-- Additional remote ext tables for pre-existing clusters
DO $$
DECLARE
	cserver  text;
	cmetrics text;
	logtbl   text;
BEGIN
	FOR cserver, cmetrics, logtbl IN
	SELECT public.cluster_server(c.id), public.cluster_metrics_schema(c.id), v.logtbl
	FROM public.clusters c, (VALUES
		('__query_stats_1hr'),
		('__query_stats_24hrs'),
		('__query_stats_7days') ) AS v(logtbl)
	LOOP
		PERFORM n.nspname, c.relname
		   FROM pg_class c JOIN pg_namespace n ON (c.relnamespace = n.oid)
		  WHERE c.relname = logtbl AND n.nspname = cmetrics;
		IF FOUND THEN
			CONTINUE;
		END IF;

		EXECUTE format(
			'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
			, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;


CREATE TABLE templates.query_statistics(
	hostname        text,
	period          timestamptz NOT NULL,
	segment_id      int,
	logtime         timestamptz,	-- conversion needed
	loguser         text,
	logdatabase     text,
	logpid          int,	-- conversion needed
	logthread       text,
	logport         int,	-- conversion needed
	logtransaction  int,	-- conversion needed
	logsession      int,	-- conversion needed
	logcmdcount     int,	-- conversion needed
	logsegment      text,
	logslice        text,
	logdistxact     text,
	loglocalxact    text,
	logsubxact      text,
	logseverity     text,
	logstate        text,
	ru_utime        float,   -- see src/backend/tcop/postgres.c ShowUsage()
	ru_stime        float,   -- see also getrusage(2)
	elapse_t        float,
	tot_user_t      float,
	tot_sys_t       float,
	ru_maxrss_kb    int,
	ru_inblock      int,
	ru_outblock     int,
	raw_ru_inblock  int,
	raw_ru_outblock int,
	ru_majflt       int,
	ru_minflt       int,
	raw_ru_majflt   int,
	raw_ru_minflt   int,
	ru_nswap        int,
	raw_ru_nswap    int,
	ru_nsignals     int,
	raw_ru_nsignals int,
	ru_msgrvc       int,
	ru_msgsnd       int,
	raw_ru_msgrvc   int,
	raw_ru_msgsnd   int,
	ru_nvcsw        int,
	rn_nivcsw       int,
	raw_ru_nvcsw    int,
	raw_rn_nivcsw   int
);

CREATE INDEX ON templates.query_statistics (hostname,period);

COMMENT ON TABLE templates.query_statistics IS 'See ShowUsage() in src/backend/tcop/postgres.c';
COMMENT ON COLUMN templates.query_statistics.ru_nswap IS 'Unmaintained by Linux';
COMMENT ON COLUMN templates.query_statistics.raw_ru_nswap IS 'Unmaintained by Linux';
COMMENT ON COLUMN templates.query_statistics.ru_nsignals IS 'Unmaintained by Linux';
COMMENT ON COLUMN templates.query_statistics.raw_ru_nsignals IS 'Unmaintained by Linux';
COMMENT ON COLUMN templates.query_statistics.ru_msgrvc IS 'Unmaintained by Linux';
COMMENT ON COLUMN templates.query_statistics.raw_ru_msgrvc IS 'Unmaintained by Linux';
COMMENT ON COLUMN templates.query_statistics.ru_msgsnd IS 'Unmaintained by Linux';
COMMENT ON COLUMN templates.query_statistics.raw_ru_msgsnd IS 'Unmaintained by Linux';


CREATE OR REPLACE FUNCTION public.load_query_statistics(
	v_cluster_id int
	, v_prime    boolean
) RETURNS VOID AS $$
DECLARE
	cmetric   text;
	lastts    timestamptz;
	query_log text;
	sql       text;
BEGIN
	cmetric := public.cluster_metrics_schema( v_cluster_id );

	query_log := '__query_stats_1hr';
	IF v_prime THEN
		/**
		 * Determine if priming is really necessary
		 */
		EXECUTE format(
			'SELECT max(period) FROM %s.query_statistics'
			, cmetrics
		) INTO lastts;

		IF lastts IS NULL OR lastts > now() - interval'1 hour' THEN
			/**
			 * Useful when stats haven't been collected for some time 
			 * (but let's try to avoid)
			 */
			query_log := '__query_stats_24hrs';
			lastts := now() - interval'24 hours';
		END IF;
	END IF;

	/**
	 * Using ft query_log, pull everything 
	 */
	sql := format('INSERT INTO %s.query_statistics
SELECT dss.hostname
     , now() AS period
     , segment_id
     , logtime::timestamptz,
     , loguser
     , logdatabase
     , replage(logpid, ''p'', '''')::int
     , logthread
     , logport::int
     , logtransaction::int
     , replace(logsession, ''con'', '''')::int
     , replace(logcmdcount, ''cmd'', '''')::int
     , logsegment
     , logslice
     , logdistxact
     , loglocalxact
     , logsubxact
     , logseverity
     , logstate
     , ru_utime
     , ru_stime
     , elapse_t
     , tot_user_t
     , tot_sys_t
     , ru_maxrss_kb
     , ru_inblock
     , ru_outblock
     , raw_ru_inblock
     , raw_ru_outblock
     , ru_majflt
     , ru_minflt
     , raw_ru_majflt
     , raw_ru_minflt
     , ru_nswap
     , raw_ru_nswap
     , ru_nsignals
     , raw_ru_nsignals
     , ru_msgrvc
     , ru_msgsnd
     , raw_ru_msgrvc
     , raw_ru_msgsnd
     , ru_nvcsw
     , rn_nivcsw
     , raw_ru_nvcsw
     , raw_rn_nivcsw
  FROM %s.%s qs
       JOIN %s.cat_gp_segment_configuration gsc
         ON (qs.segment_id = gsc.content)
       JOIN (SELECT DISTINCT hostname, altname FROM %s.data_storage_summary_mv) dss
         ON (gsc.hostname = gss.hostname OR gsc.hostname = dss.altname)
 WHERE qs.logtime::timestamptz > %s'
		, cmetric, cmetric, query_log, cmetric, cmetric
		, quote_literal(lastts)
	);

	EXECUTE sql;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';


/**
 * Lower priority & 15-minute frequency due to length of job
 */
INSERT INTO public.load_shell_functions (funcname, tablename, fdwtable, priority, frequency, enabled) VALUES
( 'public.load_shell_query_statistics', 'query_statistics', NULL, 10, 15, true );


COMMIT;
