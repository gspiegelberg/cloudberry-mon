BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1058, 'for pxf monitoring, requires cloudberry/alter-1021');

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
		('pxf_cluster_status'),
		('__pxf_status_segments'),
		('__pxf_status_master'),
		('pxf_status'),
		('__pxf_version_segments'),
		('__pxf_version_master'),
		('pxf_version'),
		('__pxf_which_segments'),
		('__pxf_which_master'),
		('pxf_which'),
		('__pxf_procs_segments'),
		('__pxf_procs_master'),
		('pxf_procs') ) AS v(logtbl)
		 WHERE c.enabled
	LOOP
		EXECUTE format('SELECT id = 1022 FROM %s.alters WHERE id = 1022', cmetrics) INTO alter_applied;
		IF NOT alter_applied THEN
			RAISE EXCEPTION 'Cluster % does not have alters/cloudberry/alter-1022.sql applied', public.cluster_id_from_schema(cmetrics);
		END IF;

		EXECUTE format(
		'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
		, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;

COMMIT;
