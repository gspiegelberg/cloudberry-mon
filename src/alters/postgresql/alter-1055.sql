BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1055, 'resource group catalogs, requires cloudberry/alter-1021');

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
	('cat_gp_resgroup_config'),
	('cat_gp_resgroup_status'),
	('cat_gp_resgroup_status_per_host'),
	('cat_gp_resgroup_iostats_per_host'),
	('cat_pg_resgroup') ) AS v(logtbl)
		 WHERE c.enabled
	LOOP
		EXECUTE format('SELECT id = 1021 FROM %s.alters WHERE id = 1021', cmetrics) INTO alter_applied;
		IF NOT alter_applied THEN
			RAISE EXCEPTION 'Cluster % does not have alters/cloudberry/alter-1021.sql applied', public.cluster_id_from_schema(cmetrics);
		END IF;

		EXECUTE format(
		'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
		, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;

COMMIT;
