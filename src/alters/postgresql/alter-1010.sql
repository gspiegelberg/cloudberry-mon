BEGIN;

INSERT INTO public.alters(id,summary) VALUES
( 1010, 'post load function calling' );


CREATE TABLE public.load_post_functions(
	load_function_id  int NOT NULL REFERENCES public.load_functions(id) ON UPDATE CASCADE ON DELETE CASCADE,
	created           timestamptz NOT NULL DEFAULT clock_timestamp(),
	postfunc          varchar(256) NOT NULL,
	priority          int DEFAULT 100,
	frequency         int DEFAULT 60,
	enabled           boolean DEFAULT true
);


CREATE OR REPLACE PROCEDURE public.load(
	v_cluster_id int
	, v_analyze boolean
	, v_prime boolean 
) AS $$
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
BEGIN
	/**
	 * Main entry point for loading remote cbmon data
	 */
	mow := extract(epoch from now() - date_trunc('week', now()))::int / 60;

	FOR funcid, func, tbl IN
	SELECT id, funcname, tablename
	  FROM public.load_functions
	 WHERE (public.minute_of_week() % frequency) = 0
	   AND enabled
	 ORDER BY priority DESC
	LOOP
		start := clock_timestamp();

		PERFORM * FROM public.check_metric_table( v_cluster_id, tbl );
		sql := format('SELECT * FROM %s(%s, %s::boolean)', func, v_cluster_id, quote_literal(v_prime));

		/**
	 	 * @todo Add exception handling if load func fails and continue with other functions
		 */
		EXECUTE sql;

		finish := clock_timestamp();
		INSERT INTO public.load_status (cluster_id, load_function_id, start_ts, finish_ts, summary)
		VALUES (v_cluster_id, funcid, start, finish, 'success');

		FOR pfunc IN
		SELECT postfunc FROM public.load_post_functions
		 WHERE load_function_id = funcid
		   AND ( (public.minute_of_week() % frequency) = 0 OR v_prime )
		   AND enabled
		 ORDER BY priority DESC
		LOOP
			start := clock_timestamp();

			sql := format('SELECT * FROM %s(%s)', pfunc, v_cluster_id );
			EXECUTE sql;

			finish := clock_timestamp();
			INSERT INTO public.load_status (cluster_id, load_function_id, start_ts, finish_ts, summary)
			VALUES (v_cluster_id, funcid, start, finish, 'post load '||pfunc||' success');
		END LOOP;

		COMMIT;
	END LOOP;

	IF v_analyze THEN
		cmetrics := public.cluster_metrics_schema( v_cluster_id );
		FOR tbl IN
			SELECT tablename
			  FROM public.load_functions
			 WHERE (public.minute_of_week() % frequency) = 0
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
