BEGIN;

INSERT INTO public.alters (id,summary) VALUES
( 1043, 'retain hourly by role query stats' );


CREATE TABLE templates.query_stats_summary(
	hostname        text,
	period           timestamptz NOT NULL,
	period_interval  int,
	username         varchar(256),
	tot_elapsed_sec  float,
	tot_user_sec     float,
	tot_sys_sec      float,
	maxrss_kb        bigint,
	read_kb          bigint,
	write_kb         bigint,
	majflt           bigint,
	minflt           bigint,
	nvcsw            bigint,
	nivcsw           bigint
);

CREATE INDEX ON templates.query_stats_summary(hostname, period);


CREATE OR REPLACE FUNCTION public.gen_query_stats_summary(
	v_cluster_id int
	, v_prime boolean )
RETURNS VOID AS $$
DECLARE
	cmetrics     text;
	way_behind   boolean;
	qs_table     text;
	max_period   timestamptz;
	sql           text;
BEGIN
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	qs_table := '__query_stats_1hr';
	EXECUTE format('SELECT max(period_interval) FROM %s.query_stats_summary', cmetrics) INTO max_period;

	IF v_prime THEN
		IF now() - max_period > interval'24 hours' THEN
			-- Hope this rarely happens
			qs_table := '__query_stats_7days';
		ELSIF now() - max_period > interval'1 hour' THEN
			qs_table := '__query_stats_24hrs';
		END IF;
	END IF;

	sql := format(
'INSERT INTO %s.query_stats_summary
SELECT ts_round(logtime::timestamptz, intv) AS period_interval
     , loguser AS username
     , sum(elapse_t) AS elapsed_t
     , sum(tot_sys_t) AS tot_sys_t
     , sum(tot_user_t) AS tot_user_t
     , sum(ru_maxrss_kb) AS maxrss_kb
     , sum(raw_ru_inblock)/2 AS read_kb
     , sum(raw_ru_outblock)/2 AS write_kb
     , sum(ru_majflt) AS majflt
     , sum(ru_minflt) AS minflt
     , sum(raw_ru_nvcsw) AS nvcsw
     , sum(raw_rn_nivcsw) AS nivcsw
  FROM %s.__query_stats_1hr, (VALUES (60, 300, 900)) AS v(intv)
 WHERE loguser NOT IN (''gpadmin'',''svc_dba_monitor'')
   AND logtime::timestamptz < %s
 GROUP BY 1, 2
 ORDER BY 1, 2'
	, cmetrics, cmetrics, quote_literal(max_period)
);

	RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.gen_functions (funcname, tablename, priority, enabled, fdwtable, frequency)
VALUES ( 'public.gen_query_stats_summary', 'query_stats_summary', 1, true, '', 900 );


COMMIT;
