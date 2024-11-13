BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1035, 'pg_roles and function to handle it' );


-- For future clusters
INSERT INTO public.extra_tables(remote_schema, remote_table) VALUES
('cbmon', 'cat_gp_locks_on_relation'),
('cbmon', 'cat_gp_locks_on_resqueue'),
('cbmon', 'cat_gp_partitions'),
('cbmon', 'cat_gp_param_settings_seg_value_diffs'),
('cbmon', 'cat_gp_workfile_entries'),
('cbmon', 'cat_gp_workfile_mgr_used_diskspace'),
('cbmon', 'cat_gp_workfile_usage_per_query'),
('cbmon', 'cat_gp_workfile_usage_per_segment'),
('cbmon', 'cat_resgroup_session_level_memory_consumption');


-- Add catalog views to existing clusters
DO $$
DECLARE
	cid int;
	cattbl text;
BEGIN
	FOR cid IN SELECT id FROM public.clusters WHERE enabled
	LOOP
		FOR cattbl IN SELECT tbl FROM (VALUES
		('gp_locks_on_relation'),
		('gp_locks_on_resqueue'),
		('gp_partitions'),
		('gp_param_settings_seg_value_diffs'),
		('gp_workfile_entries'),
		('gp_workfile_mgr_used_diskspace'),
		('gp_workfile_usage_per_query'),
		('gp_workfile_usage_per_segment'),
		('resgroup_session_level_memory_consumption')) v(tbl)
		LOOP
			PERFORM * FROM public.create_fdw_table(
				cid, 'gp_toolkit', cattbl, false, true, false
			);
		END LOOP;
	END LOOP;
END $$;


COMMIT;
