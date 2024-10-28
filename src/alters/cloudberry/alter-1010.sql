BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1010, 'create view providing version' );


CREATE VIEW cbmon.version AS
SELECT version() AS version;


INSERT INTO cbmon.catalog_views (schemaname, tablename, include_oid) VALUES
('pg_catalog', 'pg_settings', FALSE);

SELECT * FROM cbmon.execute_create_catalog_views;

COMMIT;
