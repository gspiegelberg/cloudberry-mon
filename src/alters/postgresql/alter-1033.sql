BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1033, 'live uptime/ldavg access' );


-- Additional remote ext tables for pre-existing clusters
DO $$
DECLARE
	cserver  text;
	cmetrics text;
	logtbl   text;
BEGIN
	FOR cserver, cmetrics, logtbl IN
	SELECT public.cluster_server(c.id), public.cluster_metrics_schema(c.id), v.logtbl
	  FROM public.clusters c, (VALUES
		('_live_uptime') ) AS v(logtbl)
	LOOP
		EXECUTE format(
			'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
			, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;


COMMIT;
