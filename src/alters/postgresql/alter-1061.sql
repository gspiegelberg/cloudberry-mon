BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1061, 'Add all remaining pg_catalog.pg_stat_* views');

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
		( 'cat_pg_stat_all_indexes' ),
		( 'cat_pg_stat_all_tables' ),
		( 'cat_pg_stat_archiver' ),
		( 'cat_pg_stat_bgwriter' ),
		( 'cat_pg_stat_database' ),
		( 'cat_pg_stat_database_conflicts' ),
		( 'cat_pg_stat_gssapi' ),
		( 'cat_pg_stat_last_operation' ),
		( 'cat_pg_stat_last_shoperation' ),
		( 'cat_pg_stat_operations' ),
		( 'cat_pg_stat_progress_analyze' ),
		( 'cat_pg_stat_progress_basebackup' ),
		( 'cat_pg_stat_progress_cluster' ),
		( 'cat_pg_stat_progress_copy' ),
		( 'cat_pg_stat_progress_create_index' ),
		( 'cat_pg_stat_progress_vacuum' ),
		( 'cat_pg_stat_replication' ),
		( 'cat_pg_stat_resqueues' ),
		( 'cat_pg_stat_slru' ),
		( 'cat_pg_stat_ssl' ),
		( 'cat_pg_stat_subscription' ),
		( 'cat_pg_stat_sys_indexes' ),
		( 'cat_pg_stat_sys_tables' ),
		( 'cat_pg_stat_user_functions' ),
		( 'cat_pg_stat_user_indexes' ),
		( 'cat_pg_stat_user_tables' ),
		( 'cat_pg_stat_wal' ),
		( 'cat_pg_stat_wal_receiver' ),
		( 'cat_pg_stat_xact_all_tables' ),
		( 'cat_pg_stat_xact_sys_tables' ),
		( 'cat_pg_stat_xact_user_functions' ),
		( 'cat_pg_stat_xact_user_tables' )
	) AS v(logtbl)
		 WHERE c.enabled
	LOOP
		EXECUTE format('SELECT id = 1024 FROM %s.alters WHERE id = 1024', cmetrics) INTO alter_applied;
		IF NOT alter_applied THEN
			RAISE EXCEPTION 'Cluster % does not have alters/cloudberry/alter-1024.sql applied', public.cluster_id_from_schema(cmetrics);
		END IF;

		EXECUTE format(
		'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
		, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;

COMMIT;
