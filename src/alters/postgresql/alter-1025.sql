BEGIN;

INSERT INTO public.alters(id,summary) VALUES
( 1025, 'update for partition management' );


/**
 * Defaults for all clusters. Following should be castable to these types:
 * integer  metrics.premake
 * text     metrics.retention
 *          HOWEVER partman must be able to cast as interval
 * text     metrics.retention.schema
 *          May be 'NULL'::text and will get handled later
 * boolean  metrics.retention.keep_index
 * boolean  metrics.retention.keep_table
 */
INSERT INTO public.cluster_attribs (cluster_id, domain, value) VALUES
( NULL, 'metrics.premake',   '14' ),
( NULL, 'metrics.retention', '90 days' ),
( NULL, 'metrics.retention.schema', 'NULL' ),
( NULL, 'metrics.retention.keep_index', 'FALSE' ),
( NULL, 'metrics.retention.keep_table', 'FALSE' );


CREATE OR REPLACE FUNCTION public.check_metric_table(
	v_cluster_id int, 
	v_metric_table text
)
RETURNS VOID AS $$
DECLARE
	cmetrics text;
	sql  text;
	b    boolean;
	ppremake       int;
	pretention     text;
	pret_schema    text;
	pret_keepindex boolean;
	pret_keeptable boolean;
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

	-- fetch settings for partition
	SELECT INTO ppremake value::int FROM public.cluster_attribs
	 WHERE (cluster_id IS NULL OR cluster_id = v_cluster_id)
	   AND domain = 'metrics.premake'
	 ORDER BY cluster_id NULLS LAST
	 LIMIT 1;

	SELECT INTO pretention value FROM public.cluster_attribs
	 WHERE (cluster_id IS NULL OR cluster_id = v_cluster_id)
	   AND domain = 'metrics.retention'
	 ORDER BY cluster_id NULLS LAST
	 LIMIT 1;

	SELECT INTO pret_schema CASE WHEN value = 'NULL' THEN NULL ELSE value END
	  FROM public.cluster_attribs
	 WHERE (cluster_id IS NULL OR cluster_id = v_cluster_id)
	   AND domain = 'metrics.retention.schema'
	 ORDER BY cluster_id NULLS LAST
	 LIMIT 1;

	SELECT INTO pret_keepindex value::boolean FROM public.cluster_attribs
	 WHERE (cluster_id IS NULL OR cluster_id = v_cluster_id)
	   AND domain = 'metrics.retention.keep_index'
	 ORDER BY cluster_id NULLS LAST
	 LIMIT 1;

	SELECT INTO pret_keeptable value::boolean FROM public.cluster_attribs
	 WHERE (cluster_id IS NULL OR cluster_id = v_cluster_id)
	   AND domain = 'metrics.retention.keep_table'
	 ORDER BY cluster_id NULLS LAST
	 LIMIT 1;

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
	    , p_premake := %s
	    , p_start_partition := ts.period
	) FROM (SELECT date_trunc(''day'', now() - interval''31 days'')::text AS period) ts',
		cmetrics, v_metric_table, v_metric_table, ppremake
	);
	EXECUTE sql INTO b;

	UPDATE partman.part_config SET
		retention = pretention
		, retention_schema = pret_schema
		, retention_keep_index = pret_keepindex
		, retention_keep_table = pret_keeptable
	 WHERE parent_table = format('%s.%s', cmetrics, v_metric_table);

	RETURN;

END;
$$ LANGUAGE 'plpgsql';

COMMIT;
