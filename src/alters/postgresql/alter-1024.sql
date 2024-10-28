BEGIN;


INSERT INTO public.alters(id,summary) VALUES
( 1024, 'fix to delete_cluster()' );


CREATE OR REPLACE FUNCTION public.delete_cluster(
	v_cluster_id int
)
RETURNS VOID LANGUAGE 'plpgsql' AS $$
DECLARE
	cmetrics text;
	sql      text;
BEGIN
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	DELETE FROM partman.part_config
	 WHERE parent_table ~ (format('^%s\.',cmetrics));

	DELETE FROM partman.part_config_sub
	 WHERE sub_parent ~ (format('^%s\.',cmetrics));

	PERFORM * FROM public.clusters WHERE id = v_cluster_id;
	IF FOUND THEN
		DELETE FROM public.clusters WHERE id = v_cluster_id;
		EXECUTE format('DROP SCHEMA %s CASCADE', cmetrics );
		EXECUTE format('DROP SERVER %s CASCADE', public.cluster_server( v_cluster_id ) );
	END IF;

	RETURN;
END;
$$;

COMMIT;
