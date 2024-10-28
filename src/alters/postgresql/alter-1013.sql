BEGIN;

INSERT INTO public.alters(id,summary) VALUES
( 1013, 'need database version' );

DO $$
DECLARE
	cid     int;
	cserver text;
	cmetric text;
BEGIN
	FOR cid, cserver, cmetric IN	
	SELECT id, public.cluster_server(id), public.cluster_metrics_schema(id)
	  FROM public.clusters
	LOOP
		EXECUTE format(
			'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( version ) FROM SERVER %s INTO %s'
			, cserver, cmetric
		);
	END LOOP;
END $$;

COMMIT;
