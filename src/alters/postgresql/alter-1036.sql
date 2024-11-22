BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1036, 'shell based test scaffoling' );


CREATE TABLE public.load_shell_functions(
	id         serial PRIMARY KEY,
	created    timestamptz NOT NULL default now(),
	funcname   text NOT NULL,
	tablename  text NOT NULL,
	fdwtable   text,
	priority   int NOT NULL,
	frequency  int NOT NULL default 15,       -- 15 minute default
	enabled    boolean NOT NULL default true,
	UNIQUE(funcname)
);


CREATE TABLE public.load_shell_status(
	cluster_id        int NOT NULL REFERENCES public.clusters(id) ON UPDATE CASCADE ON DELETE CASCADE,
	load_shell_function_id   int NOT NULL REFERENCES public.load_shell_functions(id) ON UPDATE CASCADE ON DELETE CASCADE,
	created           timestamptz NOT NULL DEFAULT clock_timestamp(),
	txstart           timestamptz NOT NULL,
	start_ts          timestamptz NOT NULL,
	finish_ts         timestamptz NOT NULL,
	summary           text
);


/**
 * Utility function allowing execution of shell command within database
 * Contract between caller & shell is:
 * 1. shell must exist in /usr/local/cbmon/bin
 * 2. command may not contain an abolute path
 * 3. CID is replaced with cluster.id
 * 4. output of shell matches v_dsttable where v_dsttable may be a
 *    metrics table or, best practice, unlogged intermediate table
 *    where caller will handle truncation and movement to final table
 */
CREATE OR REPLACE FUNCTION public._exec_cmd(
	v_cluster_id int
	, v_command  text
	, v_dsttable text
	, v_delimiter varchar(1) DEFAULT '|'
) RETURNS int LANGUAGE 'plpgsql' AS $func$
DECLARE
	cmetrics text;
	command  text;
	n        int;
	sql      text;
BEGIN
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	-- simply security - test v_command for leading /
	IF ltrim(v_command) ~ '^/' THEN
		RAISE EXCEPTION 'absolute paths not permitted';
	END IF;

	-- provide path
	-- replace CID strings with v_cluster_id
	command := '/usr/local/cbmon/bin/' || ltrim(replace(v_command, 'CID', v_cluster_id::text));

	sql := format(
		$eq$ COPY %s.%s FROM PROGRAM %s WITH CSV DELIMITER %s $eq$
		, cmetrics
		, v_dsttable
		, quote_literal(v_command)
		, quote_literal(v_delimiter)
	);

	EXECUTE sql;
	GET DIAGNOSTICS n = row_count;

	RETURN n;
END;
$func$;


CREATE OR REPLACE PROCEDURE public.load_shell(
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
	status   text;
	v_state   text;
	v_msg     text;
	v_detail  text;
	v_hint    text;
	v_context text;
	ts_txstart timestamptz;
BEGIN
	PERFORM * FROM public.clusters WHERE id = v_cluster_id AND enabled;
	IF NOT FOUND THEN
		RAISE NOTICE 'Cluster % not enabled', v_cluster_id;
		RETURN;
	END IF;

	ts_txstart := now();
	mow := extract(epoch from now() - date_trunc('week', now()))::int / 60;

	FOR funcid, func, tbl IN
	SELECT id, funcname, tablename
	  FROM public.load_shell_functions
	 WHERE (public.minute_of_week() % frequency) = 0
	   AND enabled
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
		INSERT INTO public.load_shell_status (cluster_id, load_shell_function_id, start_ts, finish_ts, summary, txstart)
		VALUES (v_cluster_id, funcid, start, finish, status, ts_txstart);

		COMMIT;
	END LOOP;

	IF v_analyze THEN
		cmetrics := public.cluster_metrics_schema( v_cluster_id );
		FOR tbl IN
			SELECT tablename
			  FROM public.load_shell_functions
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
