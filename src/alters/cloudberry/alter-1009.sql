BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1009, 'create view providing gp_stat_activity' );


INSERT INTO cbmon.catalog_views (schemaname, tablename, include_oid) VALUES
('pg_catalog', 'gp_stat_activity', FALSE);

SELECT * FROM cbmon.execute_create_catalog_views;

COMMIT;
