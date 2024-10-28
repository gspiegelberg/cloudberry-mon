BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1007, 'create views providing remote view into catalogs' );


CREATE TABLE cbmon.catalog_views(
	schemaname text,
	tablename  text,
	include_oid boolean,
	UNIQUE(schemaname,tablename)
);

INSERT INTO cbmon.catalog_views (schemaname, tablename, include_oid) VALUES
('pg_catalog', 'gp_segment_configuration', FALSE),
('pg_catalog', 'gp_configuration_history', FALSE),
('pg_catalog', 'pg_stat_activity', FALSE),
('pg_catalog', 'pg_locks', FALSE),
('pg_catalog', 'pg_database', TRUE),
('pg_catalog', 'pg_class', TRUE),
('pg_catalog', 'pg_namespace', TRUE),
('pg_catalog', 'pg_resqueue', TRUE);


CREATE OR REPLACE FUNCTION cbmon.create_catalog_views(
	v_replace boolean
)
RETURNS int AS $$
DECLARE
	rec     record;
	vname   text;
	oidtxt  text;
	created int;
BEGIN
	created := 0;
	FOR rec IN SELECT * FROM cbmon.catalog_views
	LOOP
		vname := 'cat_' || rec.tablename;

		PERFORM * FROM pg_views
		  WHERE schemaname = 'cbmon'
		    AND viewname = vname;
		IF FOUND THEN
			IF NOT v_replace THEN
				CONTINUE;
			END IF;
			EXECUTE format('DROP VIEW cbmon.%s', vname);
		END IF;

		/**
		 * Column oid exists on remote host using FDW.
		 * If oid is needed in remote query, oid is reserved
		 * therefore to expose it must have a different name.
		 */
		IF rec.include_oid THEN
			oidtxt := 'oid AS cat_oid,';
		ELSE
			oidtxt := '';
		END IF;

		EXECUTE format(
			'CREATE VIEW cbmon.%s AS SELECT %s * FROM %s.%s',
			vname, oidtxt, rec.schemaname, rec.tablename
		);
		created := created + 1;
	END LOOP;

	RETURN created;
END;
$$ LANGUAGE 'plpgsql';


/**
 * Calling out that this is a potential security risk as remote FDW
 * host may INSERT into cbmon.catalog_views information and call
 * either of these VIEW's executing the function.
 */
CREATE VIEW cbmon.execute_create_catalog_views AS
SELECT c AS created FROM cbmon.create_catalog_views( false ) AS c;

CREATE VIEW cbmon.execute_create_catalog_views_replace AS
SELECT c AS created FROM cbmon.create_catalog_views( true ) AS c;


COMMIT;
