BEGIN;


INSERT INTO public.alters(id,summary) VALUES
( 1017, 'function to remove a cluster' );


CREATE OR REPLACE FUNCTION public.delete_cluster(
	v_cluster_id int
)
RETURNS VOID LANGUAGE 'plpgsql' AS $$
DECLARE
	sql text;
BEGIN
	PERFORM * FROM public.clusters WHERE id = v_cluster_id;
	IF FOUND THEN
		DELETE FROM public.clusters WHERE id = v_cluster_id;
		EXECUTE format('DROP SCHEMA %s CASCADE', public.cluster_metrics_schema( v_cluster_id ) );
		EXECUTE format('DROP SERVER %s CASCADE', public.cluster_server( v_cluster_id ) );
	END IF;

	RETURN;
END;
$$;

COMMIT;
