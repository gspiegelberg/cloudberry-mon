BEGIN;

INSERT INTO public.alters (id,summary) VALUES
( 1048, 'add database uptime');

/**
 * Add to missing schemas
 */
DO $$
DECLARE
	cid integer;
	alter_applied boolean;
BEGIN
	FOR cid IN SELECT id FROM public.clusters WHERE enabled
	LOOP
		PERFORM * FROM pg_class c, pg_namespace n
		  WHERE c.relname = 'dbuptime'
		    AND c.relnamespace = n.oid
		    AND n.nspname = public.cluster_metrics_schema( cid );
		EXECUTE format('SELECT id = 1016 FROM %s.alters WHERE id = 1016', cmetrics) INTO alter_applied;
		IF NOT alter_applied THEN
			RAISE EXCEPTION 'Cluster % does not have alters/cloudberry/alter-1016.sql applied', public.cluster_id_from_schema(cmetrics);
		END IF;

		IF NOT FOUND THEN
			EXECUTE format('IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( dbuptime ) FROM SERVER %s INTO %s'
			, public.cluster_server( cid )
			, public.cluster_metrics_schema( cid ) );
		END IF;

	END LOOP;
END $$;

COMMIT;
