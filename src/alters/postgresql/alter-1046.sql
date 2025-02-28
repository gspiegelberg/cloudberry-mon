BEGIN;

INSERT INTO public.alters(id,summary) VALUES
( 1046, 'overloading public.load to permit single load function calls' );


CREATE OR REPLACE PROCEDURE public.load(
	v_cluster_id int
	, v_analyze boolean
	, v_prime boolean 
	, v_funcid int
	, v_override_freq boolean DEFAULT false
) AS $$
/**
 * v_funcid must not be NULL
 * v_fundid must match public.load_funcions.id
 * v_override_freq set to true will ignore public.load_functions.frequency
 */
DECLARE
	funcid   int;
	func     text;
	pfunc    text;
	tbl      text;
	sql      text;
	mow      int;
	cmetrics text;
	start    timestamptz;
	finish   timestamptz;
	status   text;
	v_state   text;
	v_msg     text;
	v_detail  text;
	v_hint    text;
	v_context text;
	ts_txstart timestamptz;
BEGIN
	/**
	 * Main entry point for loading remote cbmon data
	 */
	IF v_funcid IS NULL THEN
		RAISE EXCEPTION 'v_funcid cannot be NULL';
		return;
	END IF;

	PERFORM * FROM public.clusters WHERE id = v_cluster_id AND enabled;
	IF NOT FOUND THEN
		RAISE NOTICE 'Cluster % not enabled', v_cluster_id;
		RETURN;
	END IF;

	ts_txstart := now();
	mow := extract(epoch from now() - date_trunc('week', now()))::int / 60;

	FOR funcid, func, tbl IN
	SELECT id, funcname, tablename
	  FROM public.load_functions
	 WHERE ((public.minute_of_week() % frequency) = 0 OR v_override_freq )
	   AND enabled
	   AND id = v_funcid
	 ORDER BY priority DESC
	LOOP
	    BEGIN
		start := clock_timestamp();
		RAISE DEBUG 'cluster.id %, starting func %', v_cluster_id, func;

		PERFORM * FROM public.check_metric_table( v_cluster_id, tbl );
		sql := format('SELECT * FROM %s(%s, %s::boolean)', func, v_cluster_id, quote_literal(v_prime));

		EXECUTE sql;

             	status := 'success';
	    EXCEPTION 
		WHEN OTHERS THEN 
		GET STACKED DIAGNOSTICS
			v_state   = returned_sqlstate,
			v_msg     = message_text,
			v_detail  = pg_exception_detail,
			v_hint    = pg_exception_hint,
			v_context = pg_exception_context;

             	status := format('failed with exception: %s, %s', v_msg, v_context);
		RAISE DEBUG 'cluster.id %, funcname % exception %', v_cluster_id, func, status;
	    END; 
		finish := clock_timestamp();
		INSERT INTO public.load_status (cluster_id, load_function_id, start_ts, finish_ts, summary, txstart)
		VALUES (v_cluster_id, funcid, start, finish, status, ts_txstart);

		FOR pfunc IN
		SELECT postfunc FROM public.load_post_functions
		 WHERE load_function_id = funcid
		   AND ( (public.minute_of_week() % frequency) = 0
                         OR v_prime
                         OR v_override_func)
		   AND enabled
		 ORDER BY priority DESC
		LOOP
		    BEGIN
			start := clock_timestamp();

			sql := format('SELECT * FROM %s(%s)', pfunc, v_cluster_id );
			EXECUTE sql;

			status := 'post load '||pfunc||' success';
		    EXCEPTION
			WHEN OTHERS THEN
			GET STACKED DIAGNOSTICS
			v_state   = returned_sqlstate,
			v_msg     = message_text,
			v_detail  = pg_exception_detail,
			v_hint    = pg_exception_hint,
			v_context = pg_exception_context;

	             	status := format('post load %s failed with exception: %s, %s', pfunc, v_msg, v_context);
			RAISE DEBUG 'cluster.id %, pfunc % exception %', v_cluster_id, pfunc, status;
		    END; 

			finish := clock_timestamp();
			INSERT INTO public.load_status (cluster_id, load_function_id, start_ts, finish_ts, summary, txstart)
			VALUES (v_cluster_id, funcid, start, finish, status, ts_txstart);
		END LOOP;

		COMMIT;
	END LOOP;

	IF v_analyze THEN
		cmetrics := public.cluster_metrics_schema( v_cluster_id );
		FOR tbl IN
			SELECT tablename
			  FROM public.load_functions
			 WHERE (public.minute_of_week() % frequency) = 0
			   AND id = v_funcid
			   AND enabled
			 ORDER BY priority DESC
		LOOP
			RAISE NOTICE 'Analyzing %.%', cmetrics, tbl;
			sql := format( 'ANALYZE %s.%s', cmetrics, tbl );
			EXECUTE sql;
		END LOOP;
	END IF;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';


COMMIT;
