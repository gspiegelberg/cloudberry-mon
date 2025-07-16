BEGIN;

INSERT INTO public.alters (id,summary) VALUES
( 1042, 'expanding to include volserial column from source' );

-- TUrn off just cuz
UPDATE public.load_post_functions
   SET enabled = false
 WHERE postfunc = 'public.post_load_data_storage';

-- Drop and recreate existing mat views & foreign tables
DO $$
DECLARE
	cid      int;
	cmetrics text;
	cserver  text;
BEGIN
	FOR cid IN SELECT id FROM public.clusters
	LOOP
		cmetrics := public.cluster_metrics_schema( cid );
		EXECUTE 'DROP MATERIALIZED VIEW IF EXISTS '||cmetrics||'.data_storage_summary_mv';
		EXECUTE 'DROP FOREIGN TABLE IF EXISTS '||cmetrics||'._storage';
		EXECUTE 'DROP FOREIGN TABLE IF EXISTS '||cmetrics||'.__storage_segments';
		EXECUTE 'DROP FOREIGN TABLE IF EXISTS '||cmetrics||'.__storage_master';

		-- recreate
		cserver := public.cluster_server( cid );
		EXECUTE format('IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( _storage, __storage_segments, __storage_master ) FROM SERVER %s INTO %s', cserver, cmetrics);
	END LOOP;
END $$;

-- Replace function
CREATE OR REPLACE FUNCTION public.post_load_data_storage(
	v_cluster_id int
) RETURNS VOID AS $$
DECLARE
	cmetrics text;
BEGIN
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	PERFORM * FROM pg_class c, pg_namespace n
	  WHERE c.relname = 'data_storage_summary_mv'
	    AND c.relkind = 'm'
	    AND c.relnamespace = n.oid
	    AND n.nspname = cmetrics;

	IF NOT FOUND THEN

		EXECUTE format(
'CREATE MATERIALIZED VIEW %s.data_storage_summary_mv AS
SELECT ch.cluster_id
     , ch.hostname
     , ch.altname
     , ch.display_name
     , ch.is_mdw
     , gsc.datadir
     , s.device
     , s.mntpt
     , s.diskdevice      -- used with disk
     , s.volserial
  FROM public.cluster_hosts ch
       JOIN %s.cat_gp_segment_configuration gsc
         ON (gsc.hostname IN (ch.hostname, ch.altname, ch.display_name))
       JOIN %s._storage s
         ON (s.hostname IN (ch.hostname, ch.altname, ch.display_name))
 WHERE s.mntpt = ''/''||split_part(gsc.datadir, ''/'', 2)
   AND ch.cluster_id = %s
WITH DATA'
			, cmetrics, cmetrics, cmetrics, v_cluster_id
		);

	ELSE

		EXECUTE format(
			'REFRESH MATERIALIZED VIEW %s.data_storage_summary_mv WITH DATA'
			, cmetrics
		);

	END IF;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';

-- Execute function on all clusters
DO $$
DECLARE
	cid int;
BEGIN
	FOR cid IN SELECT id FROM public.clusters
	LOOP
		PERFORM public.post_load_data_storage( cid );
	END LOOP;
END $$;

-- Turn on what we turned off
UPDATE public.load_post_functions
   SET enabled = true
 WHERE postfunc = 'public.post_load_data_storage';

COMMIT;
