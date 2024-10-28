BEGIN;

INSERT INTO public.alters(id,summary) VALUES
( 1012, 'need gp_stat_activity & pg_settings' );

INSERT INTO public.extra_tables(remote_schema, remote_table) VALUES
('cbmon', 'cat_pg_settings'),
('cbmon', 'cat_gp_stat_activity');

SELECT create_extra_tables(id) FROM public.clusters;

COMMIT;
