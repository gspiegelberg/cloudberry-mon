BEGIN;
/**
 * Scans past 7 days of mdw logs (default & slow):
 * CALL public.load(1, true, true, 26, true);
 *
 * Quick prime:
 * CALL public.load(1, true, false, 26, true);
 */
INSERT INTO public.alters (id, summary) VALUES
( 1063, 'mdw log error collector' );


CREATE TABLE templates.mdw_error_log(
   period            timestamptz NOT NULL,
   logtime           timestamptz NOT NULL,
   username          name,
   database          name,
   pid               int,
   thread            text,
   host              text,
   port              int,
   sessiontime       timestamptz,
   transaction       text,
   session           int,
   cmdcount          int,
   segment           int,
   slice             int,
   distxact          text,
   localxact         text,
   subxact           text,
   severity          text,
   state             text,
   message           text,
   detail            text,
   hint              text,
   query             text,
   querypos          text,
   context           text,
   debug             text,
   cursorpos         text,
   function          text,
   file              text,
   line              text,
   stack             text
);

CREATE INDEX ON templates.mdw_error_log (period);
CREATE INDEX ON templates.mdw_error_log (logtime);


CREATE OR REPLACE FUNCTION public.load_mdw_error_log(
	v_cluster_id int
	, v_prime boolean
) RETURNS VOID AS $$
DECLARE
	cmetrics    text;
	first_run   boolean;
	last_period timestamptz;
	log_table   text;
	minperiod   timestamptz;
	sql         text;
	this_table  text := 'mdw_error_log';
	rec         record;
BEGIN
	/**
	 * Only when v_prime is true AND no summary exists will it be enforced
	 */
	cmetrics := public.cluster_metrics_schema( v_cluster_id );
	first_run := false;
	log_table := '__coordinator_log_1hr';

	EXECUTE format(
		'SELECT last_period_end FROM public.summary_tracking WHERE cluster_id = %s AND summary_table = %s'
		, v_cluster_id, quote_literal(this_table) 
	) INTO minperiod;

	-- first run / summary empty, how far to look back?
	IF minperiod IS NULL THEN
		first_run := true;

		-- how far to look back, look back 1 hour unless v_prime
		minperiod := clock_timestamp() - interval'1 hour';

		IF v_prime THEN
			-- 7 days might be painful/slow enough, let's not go 1 month
			log_table := '__coordinator_log_7days';
			minperiod := clock_timestamp() - interval'7 days';
		END IF;
	END IF;

	sql := format(
		'WITH ins AS (
INSERT INTO %s.mdw_error_log
SELECT now() AS period, logtime::timestamptz, loguser::name, logdatabase::name
     , replace(logpid, ''p'', '''')::int
     , replace(logthread, ''th-'', '''')::text
     , loghost::text, logport::int, logsessiontime::timestamptz
     , logtransaction::text
     , replace(logsession, ''con'', '''')::int
     , replace(logcmdcount, ''cmd'', '''')::int
     , replace(logsegment, ''seg'', '''')::int
     , replace(logslice, ''slice'', '''')::int
     , logdistxact::text , loglocalxact::text , logsubxact::text , logseverity::text
     , logstate::text , logmessage::text , logdetail::text , loghint::text
     , logquery::text , logquerypos::text , logcontext::text , logdebug::text
     , logcursorpos::text , logfunction::text , logfile::text , logline::text , logstack::text
  FROM %s.%s
 WHERE logstate <> ''00000''
   AND logtime::timestamptz > %s::timestamptz
 ORDER BY logtime::timestamptz
)
SELECT max(logtime) FROM ins'
		, cmetrics, cmetrics, log_table, quote_literal(minperiod) );

	EXECUTE sql INTO last_period;

	IF first_run THEN
		INSERT INTO public.summary_tracking (cluster_id, summary_table, period_interval, last_period_end)
		VALUES ( v_cluster_id, this_table, 0, last_period );
	ELSE
		UPDATE public.summary_tracking st
		   SET last_period_end = last_period
		 WHERE cluster_id = v_cluster_id
		   AND summary_table = this_table
		   AND period_interval = 0;
	END IF;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';

INSERT INTO public.load_functions
 (funcname, tablename, fdwtable, priority, enabled, frequency) VALUES
 ('public.load_mdw_error_log', 'mdw_error_log', '', 100, true::boolean, 300);


COMMIT;
