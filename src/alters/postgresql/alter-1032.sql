BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1032, 'pg_roles and function to handle it' );


-- For future clusters
INSERT INTO public.extra_tables(remote_schema, remote_table) VALUES
('cbmon', 'cat_pg_roles');


CREATE OR REPLACE FUNCTION public.create_fdw_table(
	v_cluster_id      int
	, v_remote_schema text
	, v_remote_table  text
	, v_replace       boolean DEFAULT false
	, v_is_catalog    boolean DEFAULT false
	, v_include_oid   boolean DEFAULT false
) RETURNS VOID AS $$
DECLARE
	cserver  text;
	cmetrics text;
	remote_schema text;
	remote_table  text;
	exists   int;
BEGIN
	cserver  := public.cluster_server( v_cluster_id);
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	remote_schema := v_remote_schema;
	remote_table  := v_remote_table;

	IF v_is_catalog THEN
		EXECUTE format(
			'SELECT count(*) FROM %s.catalog_views WHERE schemaname = %s AND tablename = %s'
			, cmetrics
			, quote_literal(remote_schema)
			, quote_literal(remote_table)
		) INTO exists;

		IF exists = 0 THEN

			EXECUTE format(
				'INSERT INTO %s.catalog_views (schemaname, tablename, include_oid) VALUES ( %s, %s, %s ) ON CONFLICT DO NOTHING'
				, cmetrics
				, quote_literal(remote_schema)
				, quote_literal(remote_table)
				, quote_literal(v_include_oid)
			);
		END IF;

		-- Executes remote function creating the view
		EXECUTE format(
			'SELECT * FROM %s.execute_create_catalog_views'
			, cmetrics
		);

		remote_table := 'cat_' || v_remote_table;
	END IF;


	IF v_replace THEN
		EXECUTE format(
			'DROP FOREIGN TABLE IF EXISTS %s.%s'
			, cmetrics, remote_table
		);
	END IF;

	EXECUTE format(
		'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
		, remote_table, cserver, cmetrics
	);

	RETURN;
END;
$$ LANGUAGE 'plpgsql';


-- Add catalog view
DO $$
DECLARE
	cid int;
BEGIN
	FOR cid IN SELECT id FROM public.clusters WHERE enabled
	LOOP
		PERFORM * FROM public.create_fdw_table(
			cid, 'pg_catalog', 'pg_roles', false, true, true
		);
	END LOOP;
END $$;


COMMIT;
