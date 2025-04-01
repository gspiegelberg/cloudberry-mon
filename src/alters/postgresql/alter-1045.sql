/**
 * Recommend using alter-1045 over alter-1043
 * Summaries from alter-1043 can be derived from alter-1045
 */
BEGIN;

INSERT INTO public.alters (id,summary) VALUES
( 1045, 'replaces alter 1043, retain query statistics for every query' );

/**
 * Back out alter-1043, will not remove existing query_stats_summary tables
 */
DO $$
BEGIN
PERFORM * FROM public.alters WHERE id = 1045;
IF FOUND THEN
	DELETE FROM public.gen_functions
	 WHERE funcname = 'public.gen_query_stats_summary';
END IF;
END $$;


/**
 * alter-1045
 */
CREATE TABLE templates.query_historical_statistics(
	hostname    text,
	period      timestamp with time zone NOT NULL,
	logtime     timestamp with time zone,
	username    varchar(256),
	pid         integer,
	thread      bigint,
	xact        integer,
	session     integer,
	cmdcount    integer,
	segment     integer,
	slice       integer,
	distxact    integer,
	localxact   integer,
	subxact     integer,
	severity    varchar(10),
	state       varchar(10),
	elapsed_t   bigint,
	tot_sys_t   bigint,
	tot_user_t  bigint,
	maxrss_kb   bigint,
	inblock     bigint,
	outblock    bigint,
	majflt      bigint,
	minflt      bigint,
	nvcsw       bigint,
	nivcsw      bigint
);

CREATE INDEX ON templates.query_historical_statistics(hostname, period);
/**
 * Indexes supporting drill-down
 */
CREATE INDEX ON templates.query_historical_statistics(hostname, period, username);
CREATE INDEX ON templates.query_historical_statistics(hostname, period, username, session);

COMMENT ON TABLE templates.query_historical_statistics
     IS 'See getrusage(2) man page for column measurements';


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
BEGIN
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	EXECUTE format('SELECT max(period) FROM %s.query_historical_statistics', cmetrics)
	   INTO max_period;

	/**
	 * v_prime will use 24hrs table if true but 7days table should be avoided.
	 * Churning though days of logs in an active cluster can take a very long
	 * time. If implemented, proceed with caution.
	 */
	IF v_prime AND max_period IS NULL THEN
		qs_table := '__query_stats_24hrs';
		max_period := now() - interval'24 hours';
	ELSIF NOT v_prime AND max_period IS NULL THEN
		max_period := now() - interval'1 hour';
	ELSIF max_period < now() - interval'1 hour' THEN
		qs_table := '__query_stats_24hrs';
	ELSE
		qs_table := '__query_stats_1hr';
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
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.gen_query_historical_statistics', 'query_historical_statistics', 1, true, '', 900 );


COMMIT;
