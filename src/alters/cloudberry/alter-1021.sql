BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1021, 'catalogs for resource group visibility' );


INSERT INTO cbmon.catalog_views (schemaname, tablename, include_oid) VALUES
('gp_toolkit', 'gp_resgroup_config', FALSE),
('gp_toolkit', 'gp_resgroup_status', FALSE),
('gp_toolkit', 'gp_resgroup_status_per_host', FALSE),
('gp_toolkit', 'gp_resgroup_iostats_per_host', FALSE),
('gp_toolkit', 'pg_resgroup', FALSE);

-- Create on MPP host
SELECT * FROM cbmon.execute_create_catalog_views;

COMMIT;
