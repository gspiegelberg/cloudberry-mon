BEGIN;

INSERT INTO public.alters(id,summary) VALUES
( 1001, 'deliver pg_partman' );


DO $$
BEGIN
	PERFORM * FROM pg_roles WHERE rolname = 'partman';
	IF NOT FOUND THEN
		RAISE NOTICE 'Creating partman role';
		CREATE ROLE partman WITH SUPERUSER LOGIN; -- revoke that later and lock down
	ELSE
		RAISE NOTICE 'role partman already exists';
	END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS partman;
ALTER SCHEMA partman OWNER TO partman;


DO $$
BEGIN
	RAISE NOTICE 'Also add to postgresql.conf:';
	RAISE NOTICE '   shared_preload_libraries = ''pg_partman_bgw''';
	RAISE NOTICE '   pg_partman_bgw.interval = 3600';
	RAISE NOTICE '   pg_partman_bgw.role = ''partman''';
	RAISE NOTICE '   pg_partman_bgw.dbname = ''cbmon''';
	RAISE NOTICE 'Requires a restart ';
END $$;
CREATE EXTENSION IF NOT EXISTS pg_partman WITH SCHEMA partman;

GRANT ALL ON SCHEMA partman TO partman;
GRANT ALL ON ALL TABLES IN SCHEMA partman TO partman;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA partman TO partman;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA partman TO partman;
GRANT TEMPORARY ON DATABASE cbmon TO partman;
GRANT CREATE ON DATABASE cbmon TO partman;

/**
 * TBD... don't know if it's necessary with partman privs
 */
-- GRANT ALL ON SCHEMA my_partition_schema TO partman;


COMMIT;

/**
 * Using
 * 
 * Step 1 - create partition table and whatever indexes
 * 
CREATE SCHEMA IF NOT EXISTS partman_test;

CREATE TABLE partman_test.time_taptest_table
    (col1 int,
    col2 text default 'stuff',
    col3 timestamptz NOT NULL DEFAULT now())
PARTITION BY RANGE (col3);

CREATE INDEX ON partman_test.time_taptest_table (col3);

 * 
 * Step 2 - create a template table
 * 

CREATE TABLE partman_test.time_taptest_table_template (LIKE partman_test.time_taptest_table);

ALTER TABLE partman_test.time_taptest_table_template ADD PRIMARY KEY (col1);

 * 
 * Step 3 - tell pg_partman about it
 * 

SELECT partman.create_parent(
      p_parent_table := 'partman_test.time_taptest_table'
    , p_control := 'col3'
    , p_interval := '1 day'
    , p_template_table := 'partman_test.time_taptest_table_template'
    , p_premake := 14
    , p_start_partition := '2024-10-01 00:00:00'::text
);

 *
 * Step 4 - adjust & run maint
 *
UPDATE partman.part_config SET 
 WHERE parent_table = 'partman_test.time_taptest_table';

CALL partman.run_maintenance_proc();


SELECT partman.create_parent(
      p_parent_table := 'x.test'
    , p_control := 'ts'
    , p_interval := '1 day'
    , p_template_table := 'x.test_template'
    , p_premake := 14
    , p_start_partition := '2024-10-01 00:00:00'::text
);


 */
