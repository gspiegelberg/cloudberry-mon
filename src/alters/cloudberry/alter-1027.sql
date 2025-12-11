BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1027, 'fix fetching segment stats' );


/**
 * Remove incorrect views
 */
DROP VIEW IF EXISTS
 cbmon.cat_pg_stat_all_indexes,
 cbmon.cat_pg_stat_all_tables,
 cbmon.cat_pg_stat_archiver,
 cbmon.cat_pg_stat_bgwriter,
 cbmon.cat_pg_stat_database,
 cbmon.cat_pg_stat_database_conflicts,
 cbmon.cat_pg_stat_gssapi,
 cbmon.cat_pg_stat_last_operation,
 cbmon.cat_pg_stat_last_shoperation,
 cbmon.cat_pg_stat_operations,
 cbmon.cat_pg_stat_progress_analyze,
 cbmon.cat_pg_stat_progress_basebackup,
 cbmon.cat_pg_stat_progress_cluster,
 cbmon.cat_pg_stat_progress_copy,
 cbmon.cat_pg_stat_progress_create_index,
 cbmon.cat_pg_stat_progress_vacuum,
 cbmon.cat_pg_stat_replication,
 cbmon.cat_pg_stat_resqueues,
 cbmon.cat_pg_stat_slru,
 cbmon.cat_pg_stat_ssl,
 cbmon.cat_pg_stat_subscription,
 cbmon.cat_pg_stat_sys_indexes,
 cbmon.cat_pg_stat_sys_tables,
 cbmon.cat_pg_stat_user_functions,
 cbmon.cat_pg_stat_user_indexes,
 cbmon.cat_pg_stat_user_tables,
 cbmon.cat_pg_stat_wal,
 cbmon.cat_pg_stat_wal_receiver,
 cbmon.cat_pg_stat_xact_all_tables,
 cbmon.cat_pg_stat_xact_sys_tables,
 cbmon.cat_pg_stat_xact_user_functions,
 cbmon.cat_pg_stat_xact_user_tables;


/**
 * Prevent from being recreated incorrectly
 */
DELETE FROM cbmon.catalog_views 
 WHERE schemaname = 'pg_catalog'
   AND tablename IN (
 'pg_stat_all_indexes',
 'pg_stat_all_tables',
 'pg_stat_archiver',
 'pg_stat_bgwriter',
 'pg_stat_database',
 'pg_stat_database_conflicts',
 'pg_stat_gssapi',
 'pg_stat_last_operation',
 'pg_stat_last_shoperation',
 'pg_stat_operations',
 'pg_stat_progress_analyze',
 'pg_stat_progress_basebackup',
 'pg_stat_progress_cluster',
 'pg_stat_progress_copy',
 'pg_stat_progress_create_index',
 'pg_stat_progress_vacuum',
 'pg_stat_replication',
 'pg_stat_resqueues',
 'pg_stat_slru',
 'pg_stat_ssl',
 'pg_stat_subscription',
 'pg_stat_sys_indexes',
 'pg_stat_sys_tables',
 'pg_stat_user_functions',
 'pg_stat_user_indexes',
 'pg_stat_user_tables',
 'pg_stat_wal',
 'pg_stat_wal_receiver',
 'pg_stat_xact_all_tables',
 'pg_stat_xact_sys_tables',
 'pg_stat_xact_user_functions',
 'pg_stat_xact_user_tables' );


/**
 * Create correctly
 */
DO $$
DECLARE
	cat text;
	sql text;
BEGIN
	FOR cat IN SELECT * FROM ( VALUES
		('pg_stat_all_indexes'),
		('pg_stat_all_tables'),
		('pg_stat_archiver'),
		('pg_stat_bgwriter'),
		('pg_stat_database'),
		('pg_stat_database_conflicts'),
		('pg_stat_gssapi'),
		('pg_stat_last_operation'),
		('pg_stat_last_shoperation'),
		('pg_stat_operations'),
		('pg_stat_progress_analyze'),
		('pg_stat_progress_basebackup'),
		('pg_stat_progress_cluster'),
		('pg_stat_progress_copy'),
		('pg_stat_progress_create_index'),
		('pg_stat_progress_vacuum'),
		('pg_stat_replication'),
		('pg_stat_resqueues'),
		('pg_stat_slru'),
		('pg_stat_ssl'),
		('pg_stat_subscription'),
		('pg_stat_sys_indexes'),
		('pg_stat_sys_tables'),
		('pg_stat_user_functions'),
		('pg_stat_user_indexes'),
		('pg_stat_user_tables'),
		('pg_stat_wal'),
		('pg_stat_wal_receiver'),
		('pg_stat_xact_all_tables'),
		('pg_stat_xact_sys_tables'),
		('pg_stat_xact_user_functions'),
		('pg_stat_xact_user_tables') ) AS v(x)
	LOOP
		sql := format(
			'CREATE VIEW cbmon.cat_%s AS SELECT * FROM gp_dist_random(%s)'
			, cat, quote_literal('pg_catalog.'||cat)
		);
		EXECUTE sql;
	END LOOP;
END $$;

COMMIT;
