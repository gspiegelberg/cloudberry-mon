BEGIN;

INSERT INTO public.alters(id,summary) VALUES
( 1002, 'load_functions' );


CREATE SCHEMA IF NOT EXISTS templates;



CREATE OR REPLACE FUNCTION public.minute_of_week()
RETURNS int AS $$
SELECT extract(epoch from
	(now()::timestamp -
	 date_trunc('week', now())::timestamp))::int / 60;
$$ LANGUAGE SQL STABLE;


CREATE OR REPLACE FUNCTION public.check_metric_table(
	v_cluster_id int, 
	v_metric_table text
)
RETURNS VOID AS $$
DECLARE
	cmetrics text;
	sql  text;
	b    boolean;
BEGIN
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	PERFORM * FROM pg_stat_user_tables
	  WHERE schemaname = cmetrics
            AND relname = v_metric_table;
	IF FOUND THEN
		-- Exists, verification it is maintained MUST be done external
		-- CALL partman.run_maintenance_proc();
		RETURN;
	END IF; 

	-- Creates parent table
	sql := format(
		'CREATE TABLE IF NOT EXISTS %s.%s( LIKE templates.%s INCLUDING ALL ) PARTITION BY RANGE (period)',
		cmetrics, v_metric_table, v_metric_table
	);
	EXECUTE sql;

	-- Configures and builds out partitions
	sql := format('SELECT partman.create_parent(
	      p_parent_table := ''%s.%s''
	    , p_control := ''period''
	    , p_interval := ''1 day''
	    , p_template_table := ''templates.%s''
	    , p_premake := 14
	    , p_start_partition := ts.period
	) FROM (SELECT date_trunc(''day'', now() - interval''31 days'')::text AS period) ts',
		cmetrics, v_metric_table, v_metric_table
	);
	EXECUTE sql INTO b;

	RETURN;

END;
$$ LANGUAGE 'plpgsql';


CREATE TABLE public.load_status(
	cluster_id        int NOT NULL REFERENCES public.clusters(id) ON UPDATE CASCADE ON DELETE CASCADE,
	load_function_id  int NOT NULL REFERENCES public.load_functions(id) ON UPDATE CASCADE ON DELETE CASCADE,
	created           timestamptz NOT NULL DEFAULT clock_timestamp(),
	start_ts          timestamptz NOT NULL,
	finish_ts         timestamptz NOT NULL,
	summary           varchar(256)
);

/**
 * Main entry point for loading remote cbmon data
 * @todo turn into a producedure adding commits after every loop
 * @todo add per cluster per load_function last run time
 */
CREATE OR REPLACE PROCEDURE public.load( v_cluster_id int, v_analyze boolean, v_prime boolean )
AS $$
DECLARE
	funcid int;
	func  text;
	tbl   text;
	sql   text;
	mow   int;
	cmetrics text;
	start timestamptz;
	finish timestamptz;
BEGIN
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
		EXECUTE sql;

		finish := clock_timestamp();
		INSERT INTO public.load_status (cluster_id, load_function_id, start_ts, finish_ts, summary)
		VALUES (v_cluster_id, funcid, start, finish, 'success');

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


CREATE OR REPLACE PROCEDURE public.load( v_cluster_name text, v_analyze boolean )
AS $$
DECLARE
	cid int;
BEGIN
	SELECT INTO cid id FROM public.clusters WHERE name = v_cluster_name;
	IF FOUND THEN
		CALL public.load( id, v_analyze, false );
	ELSE
		RAISE EXCEPTION 'Cluster ''%'' does not exist', v_cluster_name;
	END IF;
	
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION public._loader_sar( v_cluster_id int, v_metrics text, v_prime boolean )
RETURNS VOID AS $$
DECLARE
	cols1    text;
	cols2    text;
	today    date;
	sql      text;
	cfdw     text;
	cmetrics text;
	fdwtbl   text;
BEGIN
	today    := date_trunc('day', now());
	cfdw     := public.cluster_fdw_schema( v_cluster_id );
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	SELECT INTO fdwtbl fdwtable FROM public.load_functions
	 WHERE tablename = v_metrics;

	-- Load everything available if v_prime
	IF v_prime THEN
		-- Verify *_all FDT exists
		PERFORM * FROM information_schema.tables
		  WHERE table_schema = cfdw AND table_name = replace(fdwtbl, 'today', 'all');
		IF FOUND THEN
			fdwtbl := replace(fdwtbl, 'today', 'all');
		END IF;
	END IF;

	SELECT INTO cols1 substr(array_agg, 2, length(array_agg)-2)
	  FROM (SELECT array_agg(column_name)::text
	          FROM information_schema.columns
	         WHERE table_schema||'.'||table_name = cmetrics||'.'||v_metrics)x;

	SELECT INTO cols2 substr(array_agg, 2, length(array_agg)-2)
	  FROM (SELECT array_agg('d.'||column_name)::text
	          FROM information_schema.columns
	         WHERE table_schema||'.'||table_name = cmetrics||'.'||v_metrics)x;

	sql := format(
		'INSERT INTO %s.%s (%s)
	WITH maxes AS (
	SELECT ch.hostname, COALESCE(max(period)::timestamp, ''2020-01-01 00:00:00''::timestamp) AS max
	  FROM public.cluster_hosts ch LEFT JOIN %s.%s d ON (ch.hostname = d.hostname)
	 GROUP BY 1
	)
	SELECT %s
	  FROM %s.%s d JOIN maxes m ON (d.hostname = m.hostname AND d.period > m.max)',
		cmetrics, v_metrics, cols1, cmetrics, v_metrics, cols2, cfdw, fdwtbl
	);

	-- RAISE NOTICE 'sql=%', sql;
	EXECUTE sql;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION public.loader_sar( v_cluster_id int, v_metrics text, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public._loader_sar( v_cluster_id, v_metrics, v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


COMMIT;




/**
 * NOTES
 * Using
 * 
 * Step 1 - create partition table and whatever indexes
 * 
CREATE SCHEMA IF NOT EXISTS partman_test;

CREATE TABLE partman_test.time_taptest_table
    (col1 int,
    col2 text default 'stuff',
    col3 timestamptz NOT NULL DEFAULT now())
PARTITION BY RANGE (col3);

CREATE INDEX ON partman_test.time_taptest_table (col3);

 * 
 * Step 2 - create a template table
 * 

CREATE TABLE partman_test.time_taptest_table_template (LIKE partman_test.time_taptest_table);

ALTER TABLE partman_test.time_taptest_table_template ADD PRIMARY KEY (col1);

 * 
 * Step 3 - tell pg_partman about it
 * 

SELECT partman.create_parent(
      p_parent_table := 'partman_test.time_taptest_table'
    , p_control := 'col3'
    , p_interval := '1 day'
    , p_template_table := 'partman_test.time_taptest_table_template'
    , p_premake := 14
    , p_start_partition := '2024-10-01 00:00:00'::text
);

 *
 * Step 4 - adjust & run maint
 *
UPDATE partman.part_config SET 
 WHERE parent_table = 'partman_test.time_taptest_table';

CALL partman.run_maintenance_proc();


SELECT partman.create_parent(
      p_parent_table := 'x.test'
    , p_control := 'ts'
    , p_interval := '1 day'
    , p_template_table := 'x.test_template'
    , p_premake := 14
    , p_start_partition := '2024-10-01 00:00:00'::text
);


 */
