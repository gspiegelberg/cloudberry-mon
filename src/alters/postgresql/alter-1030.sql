BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1030, 'adding query summary generation' );


INSERT INTO public.gen_functions
 (funcname, tablename, fdwtable, priority, frequency, enabled ) VALUES
( 'public.gen_query_log_counts1', 'query_log_counts', '__coordinator_log_1hr', 75, 1, true ),
( 'public.gen_query_log_counts5', 'query_log_counts', '__coordinator_log_1hr', 70, 1, true ),
( 'public.gen_query_log_counts15', 'query_log_counts', '__coordinator_log_1hr', 65, 1, true );


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
		('__coordinator_log_1hr'),
		('__coordinator_log_1month'),
		('__coordinator_log_24hrs'),
		('__coordinator_log_7days'),
		('__coordinator_log_all') ) AS v(logtbl)
	LOOP
		EXECUTE format(
			'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
			, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;


CREATE TABLE templates.query_log_counts(
	period          timestamptz NOT NULL,
	period_interval int,
	username        text,
	loghost         text,
	queries         int
);


CREATE TABLE public.summary_tracking(
	cluster_id      int NOT NULL REFERENCES public.clusters(id) ON UPDATE CASCADE ON DELETE CASCADE,
	summary_table   varchar(256) NOT NULL,
	period_interval int NOT NULL,
	last_period_end timestamptz NOT NULL
);


CREATE OR REPLACE FUNCTION public._gen_query_log_counts(
	v_cluster_id int
	, v_prime boolean
	, v_intv int
) RETURNS VOID AS $$
DECLARE
	cmetrics    text;
	first_run   boolean;
	last_period timestamptz;
	log_table   text;
	maxperiod   timestamptz;
	minperiod   timestamptz;
	sql         text;
	this_table  text := 'query_log_counts';
BEGIN
	/**
	 * Only when v_prime is true AND no summary exists will it be enforced
	 */
	cmetrics := public.cluster_metrics_schema( v_cluster_id );
	first_run := false;
	log_table := '__coordinator_log_1hr';

	EXECUTE format('
SELECT last_period_end
  FROM public.summary_tracking
 WHERE cluster_id = %s
   AND summary_table = %s
   AND period_interval = %s'
		, v_cluster_id, quote_literal(this_table), v_intv)
	   INTO minperiod;

	-- first run / summary empty, how far to look back?
	IF minperiod IS NULL THEN
		first_run := true;

		-- how far to look back
		IF v_prime THEN
			-- 7 days might be painful/slow enough, let's not go 1 month
			log_table := '__coordinator_log_7days';
			minperiod := public.ts_round(clock_timestamp() - interval'7 days', v_intv);
		ELSE
			-- look back 1 hour if table empty rounding to v_intv
			minperiod := public.ts_round(clock_timestamp() - interval'1 hour', v_intv);
		END IF;
	END IF;

	-- do not include current period if in the middle of it
	maxperiod := public.ts_round(clock_timestamp() - (v_intv * interval'1 second'), v_intv);

	IF (minperiod + v_intv * interval'1 second') = maxperiod THEN
		-- nothing to do
		RETURN;
	END IF;

	sql := format('
WITH ins AS (
INSERT INTO %s.%s
(period, period_interval, username, loghost, queries)
SELECT public.ts_round(l.logtime::timestamptz, %s) AS period
     , %s AS period_interval
     , l.loguser AS username
     , l.loghost AS client_addr
     , count(*) AS queries
  FROM %s.%s l
 WHERE public.ts_round(l.logtime::timestamptz, %s) > %s
   AND public.ts_round(l.logtime::timestamptz, %s) < %s
   AND l.logmessage ~ ''^statement: ''
 GROUP BY 1, 2, 3, 4
 ORDER BY 1, 2, 3, 4
RETURNING period 
)
SELECT max(period) FROM ins
'
		, cmetrics, this_table, v_intv, v_intv, cmetrics, log_table
		, v_intv, quote_literal(minperiod)
		, v_intv, quote_literal(maxperiod)
	);

	EXECUTE sql INTO last_period;

	IF last_period = NULL THEN
		-- just in case
		RETURN;
	END IF;

	IF first_run THEN
		INSERT INTO public.summary_tracking (cluster_id, summary_table, period_interval, last_period_end)
		VALUES ( v_cluster_id, this_table, v_intv, last_period );
	ELSE
		UPDATE public.summary_tracking st
		   SET last_period_end = last_period
		 WHERE cluster_id = v_cluster_id
		   AND summary_table = this_table
		   AND period_interval = v_intv;
	END IF;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION public.gen_query_log_counts1(
	v_cluster_id int
	, v_prime    boolean
) RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public._gen_query_log_counts(v_cluster_id, v_prime, 60);
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION public.gen_query_log_counts5(
	v_cluster_id int
	, v_prime    boolean
) RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public._gen_query_log_counts(v_cluster_id, v_prime, 300);
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION public.gen_query_log_counts15(
	v_cluster_id int
	, v_prime    boolean
) RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public._gen_query_log_counts(v_cluster_id, v_prime, 900);
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


COMMIT;
