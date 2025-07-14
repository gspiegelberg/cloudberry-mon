BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1052, 'postgresql side of active backends');

/**
 * Add to existing, enabled clusters
 */
DO $$
DECLARE
	cserver  text;
	cmetrics text;
	logtbl   text;
	alter_applied boolean;
BEGIN
	FOR cserver, cmetrics, logtbl IN
		SELECT public.cluster_server(c.id), public.cluster_metrics_schema(c.id), v.logtbl
		FROM public.clusters c, (VALUES 
	('_live_master_backends'),
	('_live_segment_backends'),
	('live_backends'),
		 WHERE c.enabled
	LOOP
		EXECUTE format('SELECT id = 1019 FROM %s.alters WHERE id = 1019', cmetrics) INTO alter_applied;
		IF NOT alter_applied THEN
			RAISE EXCEPTION 'Cluster % does not have alters/cloudberry/alter-1019.sql applied', public.cluster_id_from_schema(cmetrics);
		END IF;

		EXECUTE format(
		'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
		, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;

COMMIT;
