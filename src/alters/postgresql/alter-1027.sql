BEGIN;

INSERT INTO public.alters (id,summary) VALUES
( 1027, 'mat view to help with dashboard performance' );


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
  FROM public.cluster_hosts ch
       JOIN %s.cat_gp_segment_configuration gsc
         ON (ch.hostname = gsc.hostname OR ch.altname = gsc.hostname)
       JOIN %s._storage s
         ON (ch.hostname = s.hostname OR ch.altname = s.hostname)
 WHERE s.mntpt = ''/''||split_part(gsc.datadir, ''/'', 2)
WITH DATA'
			, cmetrics, cmetrics, cmetrics
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


INSERT INTO public.load_post_functions (load_function_id, postfunc, priority, frequency, enabled)
SELECT id AS load_function_id
     , 'public.post_load_data_storage' AS postfunc
     , 100 AS priority
     , 1440 AS frequency          -- once daily
     , true AS enabled
  FROM public.load_functions
 WHERE tablename = 'disk_space';  -- after disk_space


COMMIT;
