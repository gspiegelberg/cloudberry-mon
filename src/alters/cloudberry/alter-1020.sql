BEGIN;
/**
 * lost track of some views leading to incomplete metrics schemas
 */

INSERT INTO cbmon.alters (id, summary) VALUES
( 1020, 'address missing catalog views' );

DELETE FROM cbmon.catalog_views;

INSERT INTO cbmon.catalog_views ( schemaname, tablename , include_oid ) VALUES
( 'pg_catalog', 'gp_configuration_history', false ),
( 'gp_toolkit', 'gp_locks_on_relation', false ),
( 'gp_toolkit', 'gp_locks_on_resqueue', false ),
( 'gp_toolkit', 'gp_param_settings_seg_value_diffs', false ),
( 'gp_toolkit', 'gp_partitions', false ),
( 'pg_catalog', 'gp_segment_configuration', false ),
( 'pg_catalog', 'gp_stat_activity', false ),
( 'pg_catalog', 'gp_stat_archiver', false ),
( 'pg_catalog', 'gp_stat_replication', false ),
( 'gp_toolkit', 'gp_workfile_entries', false ),
( 'gp_toolkit', 'gp_workfile_mgr_used_diskspace', false ),
( 'gp_toolkit', 'gp_workfile_usage_per_query', false ),
( 'gp_toolkit', 'gp_workfile_usage_per_segment', false ),
( 'pg_catalog', 'pg_class', true ),
( 'pg_catalog', 'pg_database', true ),
( 'pg_catalog', 'pg_locks', false ),
( 'pg_catalog', 'pg_namespace', true ),
( 'pg_catalog', 'pg_resqueue', true ),
( 'pg_catalog', 'pg_roles', true ),
( 'pg_catalog', 'pg_settings', false ),
( 'pg_catalog', 'pg_stat_activity', false ),
( 'gp_toolkit', 'resgroup_session_level_memory_consumption', false );

SELECT * FROM cbmon.execute_create_catalog_views_replace;

COMMIT;
