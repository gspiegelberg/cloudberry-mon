BEGIN;
/**
 * lost track of some views leading to incomplete metrics schemas
 */

INSERT INTO cbmon.alters (id, summary) VALUES
( 1024, 'add potentially useful stat catalog views' );

-- DELETE FROM cbmon.catalog_views;

INSERT INTO cbmon.catalog_views ( schemaname, tablename , include_oid ) VALUES
( 'pg_catalog', 'pg_stat_all_indexes', false ),
( 'pg_catalog', 'pg_stat_all_tables', false ),
( 'pg_catalog', 'pg_stat_archiver', false ),
( 'pg_catalog', 'pg_stat_bgwriter', false ),
( 'pg_catalog', 'pg_stat_database', false ),
( 'pg_catalog', 'pg_stat_database_conflicts', false ),
( 'pg_catalog', 'pg_stat_gssapi', false ),
( 'pg_catalog', 'pg_stat_last_operation', false ),
( 'pg_catalog', 'pg_stat_last_shoperation', false ),
( 'pg_catalog', 'pg_stat_operations', false ),
( 'pg_catalog', 'pg_stat_progress_analyze', false ),
( 'pg_catalog', 'pg_stat_progress_basebackup', false ),
( 'pg_catalog', 'pg_stat_progress_cluster', false ),
( 'pg_catalog', 'pg_stat_progress_copy', false ),
( 'pg_catalog', 'pg_stat_progress_create_index', false ),
( 'pg_catalog', 'pg_stat_progress_vacuum', false ),
( 'pg_catalog', 'pg_stat_replication', false ),
( 'pg_catalog', 'pg_stat_resqueues', false ),
( 'pg_catalog', 'pg_stat_slru', false ),
( 'pg_catalog', 'pg_stat_ssl', false ),
( 'pg_catalog', 'pg_stat_subscription', false ),
( 'pg_catalog', 'pg_stat_sys_indexes', false ),
( 'pg_catalog', 'pg_stat_sys_tables', false ),
( 'pg_catalog', 'pg_stat_user_functions', false ),
( 'pg_catalog', 'pg_stat_user_indexes', false ),
( 'pg_catalog', 'pg_stat_user_tables', false ),
( 'pg_catalog', 'pg_stat_wal', false ),
( 'pg_catalog', 'pg_stat_wal_receiver', false ),
( 'pg_catalog', 'pg_stat_xact_all_tables', false ),
( 'pg_catalog', 'pg_stat_xact_sys_tables', false ),
( 'pg_catalog', 'pg_stat_xact_user_functions', false ),
( 'pg_catalog', 'pg_stat_xact_user_tables', false );

SELECT * FROM cbmon.execute_create_catalog_views_replace;

COMMIT;
