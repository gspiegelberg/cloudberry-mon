BEGIN;

DO $$
BEGIN
	-- For metric gathering
	PERFORM * FROM pg_roles WHERE rolname = 'cbmon';
	IF NOT FOUND THEN
		RAISE NOTICE 'Creating cbmon role';
		CREATE ROLE cbmon WITH SUPERUSER LOGIN; -- revoke that later and lock down
	ELSE
		RAISE NOTICE 'role cbmon already exists';
	END IF;

	-- For grafana dashboard
	PERFORM * FROM pg_roles WHERE rolname = 'grafana';
	IF NOT FOUND THEN
		RAISE NOTICE 'Creating grafana role';
		CREATE ROLE grafana WITH LOGIN; -- revoke that later and lock down
	ELSE
		RAISE NOTICE 'role grafana already exists';
	END IF;
END $$;


ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafana;

GRANT USAGE ON SCHEMA public TO grafana;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafana;


CREATE TABLE public.alters(
	id      int PRIMARY KEY,
	created timestamptz NOT NULL DEFAULT now(),
	summary text
);

INSERT INTO public.alters(id,summary) VALUES
( 1000, 'base schema' );


CREATE EXTENSION IF NOT EXISTS postgres_fdw;


CREATE TABLE public.clusters(
	id      serial PRIMARY KEY,
	created timestamptz NOT NULL DEFAULT now(),
	name    varchar(256) NOT NULL,
	enabled boolean NOT NULL DEFAULT true,
	UNIQUE(name)
);

COMMENT ON COLUMN public.clusters.enabled IS 'false disables metric gathering';


CREATE TABLE public.cluster_hosts(
	id          serial PRIMARY KEY,
	cluster_id  int REFERENCES public.clusters(id) ON UPDATE CASCADE ON DELETE CASCADE,
	created     timestamptz NOT NULL DEFAULT now(),
	hostname    varchar(256) NOT NULL,
	altname     varchar(256),
	is_mdw      boolean NOT NULL DEFAULT false,
	UNIQUE(cluster_id,hostname)
);

CREATE TABLE public.cluster_attribs(
	id          serial PRIMARY KEY,
	cluster_id  int REFERENCES public.clusters(id) ON UPDATE CASCADE ON DELETE CASCADE,
	host_id     int REFERENCES public.cluster_hosts(id) ON UPDATE CASCADE ON DELETE CASCADE,
	domain      varchar(256) NOT NULL,
	value       varchar(256) NOT NULL
);

CREATE TABLE public.cluster_host_attribs(
	id          serial PRIMARY KEY,
	host_id     int REFERENCES public.cluster_hosts(id) ON UPDATE CASCADE ON DELETE CASCADE,
	domain      varchar(256) NOT NULL,
	value       varchar(256) NOT NULL
);

CREATE TABLE public.load_functions(
	id          serial PRIMARY KEY,
	created     timestamptz NOT NULL DEFAULT now(),
	funcname    text NOT NULL,
	tablename   text NOT NULL,
	fdwtable    text NOT NULL,
	priority    int  NOT NULL,
	enabled     boolean NOT NULL DEFAULT true,
	frequency   int  NOT NULL DEFAULT 1,
	UNIQUE(funcname),
	UNIQUE(tablename)
);

COMMENT ON COLUMN public.load_functions.funcname IS 'name as schema.function_name without parenthesis';
COMMENT ON COLUMN public.load_functions.tablename IS 'target table name without schema';
COMMENT ON COLUMN public.load_functions.fdwtable IS 'source foreign table name without schema';
COMMENT ON COLUMN public.load_functions.priority IS 'functions are called higher values first';
COMMENT ON COLUMN public.load_functions.enabled IS 'false disables specific metric gathering such as for debugging';
COMMENT ON COLUMN public.load_functions.frequency IS 'used as a modulo of minute of the week, eg 1 is every minute';


CREATE TABLE public.extra_tables(
        id            serial PRIMARY KEY,
        created       timestamptz NOT NULL DEFAULT now(),
        remote_schema text NOT NULL,
        remote_table  text NOT NULL,
        UNIQUE(remote_schema, remote_table)
);

/**
 * Problem: pg_* catalogs do not work with FDW
 * Solutions:
 *  1) Create a remote view on top of relation
 *  2) Create remote function with view on top to access relations
 */
INSERT INTO public.extra_tables(remote_schema, remote_table) VALUES
('cbmon', 'cat_gp_segment_configuration'),
('cbmon', 'cat_gp_configuration_history'),
('cbmon', 'cat_pg_stat_activity'), -- N/A
('cbmon', 'cat_pg_locks'),         -- N/A
('cbmon', 'cat_pg_database'),      -- N/A
('cbmon', 'cat_pg_class'),         -- N/A
('cbmon', 'cat_pg_namespace'),     -- N/A
('cbmon', 'cat_pg_resqueue');


/**
 * Timestamp rounding functions better than date_trunc
 */
CREATE OR REPLACE FUNCTION ts_round( timestamp without time zone, INT ) RETURNS TIMESTAMP WITHOUT TIME ZONE AS $$
  SELECT 'epoch'::timestamp + '1 second'::INTERVAL * ( $2 * ( EXTRACT( epoch FROM $1 )::INT / $2 ) );
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION ts_round( timestamp with time zone, INT ) RETURNS TIMESTAMP WITH TIME ZONE AS $$
  SELECT 'epoch'::timestamp + '1 second'::INTERVAL * ( $2 * ( EXTRACT( epoch FROM $1 )::INT / $2 ) );
$$ LANGUAGE SQL IMMUTABLE;



/**
 * cluster & cluster_hosts functions
 */

CREATE OR REPLACE FUNCTION public.cluster_server( v_cluster_id int )
RETURNS text AS $$
        SELECT 'cluster_' || v_cluster_id || '_server';
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION public.cluster_server IS 'Name of foreign server for cluster';


CREATE OR REPLACE FUNCTION public.cluster_metrics_schema( v_cluster_id int )
RETURNS text AS $$
        SELECT 'metrics_' || v_cluster_id
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION public.cluster_metrics_schema IS 'Schema where cluster metrics are stored';


CREATE OR REPLACE FUNCTION public.cluster_fdw_schema( v_cluster_id int )
RETURNS text AS $$
        SELECT public.cluster_metrics_schema( v_cluster_id )
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION public.cluster_fdw_schema IS 'Schema where foreign tables are created';


CREATE OR REPLACE FUNCTION public.cluster_id_from_schema( v_schema text )
RETURNS int AS $$
	SELECT replace(v_schema, 'metrics_', '')::int
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION public.cluster_id_from_schema IS 'Get cluster id from a cluster metrics schema name';


CREATE OR REPLACE FUNCTION public.create_extra_tables( v_cluster_id int )
RETURNS VOID AS $$
DECLARE
        cfdw        text;
        cserver     text;
	dbmonschema text;
        rec         record;
        sql         text;
BEGIN
        cfdw    := public.cluster_fdw_schema( v_cluster_id );
        cserver := public.cluster_server( v_cluster_id );

        FOR rec IN SELECT * FROM public.extra_tables ORDER BY id
        LOOP
                PERFORM * FROM pg_class c LEFT JOIN pg_namespace n ON (n.oid = c.relnamespace)
                  WHERE c.relname = rec.remote_table
                    AND n.nspname = cfdw
                  ORDER BY 2, 3;

                IF FOUND THEN
                        -- skip if exists
                        CONTINUE;
                END IF;

                sql := format(
                        'IMPORT FOREIGN SCHEMA %s LIMIT TO ( %s ) FROM SERVER %s INTO %s',
                        rec.remote_schema, rec.remote_table, cserver, cfdw
                );
                EXECUTE sql;
        END LOOP;

        RETURN;
END;
$$ LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION public.create_host(
	v_cluster_id int,
	v_hostname   varchar(256),
	v_is_mdw     boolean
)
RETURNS int LANGUAGE 'plpgsql' AS $$
DECLARE
	hid int;
BEGIN
	PERFORM * FROM public.clusters WHERE id = v_cluster_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Cluster id % does not exist', v_cluster_id;
	END IF;

	PERFORM * FROM public.cluster_hosts WHERE cluster_id = v_cluster_id AND hostname = v_hostname;
	IF FOUND THEN
		RAISE EXCEPTION 'Host % already exists', v_name;
	END IF;

	INSERT INTO public.cluster_hosts (cluster_id, hostname, is_mdw) VALUES
	( v_cluster_id, v_hostname, v_is_mdw)
	RETURNING id INTO hid;

	RETURN hid;
END;
$$;


CREATE OR REPLACE FUNCTION public.create_cluster(
	v_name        varchar(256),
	v_mdwname     varchar(256),
	v_mdwip       varchar(16),
	v_port        int,
	v_cbmondb     varchar(256),
	v_cbmonschema varchar(256),
	v_user        varchar(256),
	v_pass        varchar(256)
)
RETURNS int LANGUAGE 'plpgsql'
AS $$
DECLARE
	cid int;
	cfdw text;
	cmetrics text;
	cserver text;
	sql text;
BEGIN
	PERFORM * FROM public.clusters WHERE name = v_name;
	IF FOUND THEN
		RAISE EXCEPTION 'Cluster % already exists', v_name;
	END IF;

	IF v_mdwip IS NULL THEN
		RAISE EXCEPTION 'v_mdwip cannot be NULL';
	END IF;

	INSERT INTO public.clusters (name) VALUES (v_name) RETURNING id INTO cid;
	PERFORM * FROM public.create_host(cid, v_mdwname, true);

	cfdw     := public.cluster_fdw_schema( cid );
	cmetrics := public.cluster_metrics_schema( cid );
	cserver  := public.cluster_server( cid );

	-- create foreign server
	sql := format(
		'CREATE SERVER %s FOREIGN DATA WRAPPER postgres_fdw OPTIONS(host %s, port %s, dbname %s)',
		cserver, quote_literal(v_mdwip), quote_literal(v_port), quote_literal(v_cbmondb)
	);
	EXECUTE sql;

	-- create user mapping
	sql := format(
		'CREATE USER MAPPING FOR cbmon SERVER %s OPTIONS (user %s, password %s)',
		cserver, quote_literal(v_user), quote_literal(v_pass)
	);
	EXECUTE sql;

	-- create metrics schema
	sql := format(
		'CREATE SCHEMA IF NOT EXISTS %s',
		cmetrics
	);
	EXECUTE sql;

	sql := format(
		'IMPORT FOREIGN SCHEMA %s FROM SERVER %s INTO %s',
		v_cbmonschema, cserver, cfdw
	);
	EXECUTE sql;

	-- add more tables
	PERFORM * FROM public.create_extra_tables( cid );

	-- add segment hosts
	sql := format(
		'SELECT public.create_host( %s, hostname, false )
		    FROM (SELECT DISTINCT hostname FROM %s.cat_gp_segment_configuration WHERE content >= 0) x',
		cid, cfdw
	);
	EXECUTE sql;

	RETURN cid;
END;
$$;

/*
COMMENT ON FUNCTION public.create_cluster (v_name) IS 'Cluster name, must be unique';
COMMENT ON FUNCTION public.create_cluster (v_mdwname) IS 'Remote database mdw host name';
COMMENT ON FUNCTION public.create_cluster (v_mdwip) IS 'Remote database mdw host IP';
COMMENT ON FUNCTION public.create_cluster (v_port) IS 'Remote database port';
COMMENT ON FUNCTION public.create_cluster (v_cbmondb) IS 'Remote database cbmon database name';
COMMENT ON FUNCTION public.create_cluster (v_cbmonschema) IS 'Remote database cbmon schema';
COMMENT ON FUNCTION public.create_cluster (v_user) IS 'Remote database user';
COMMENT ON FUNCTION public.create_cluster (v_pass) IS 'Remote database user password';
*/

COMMIT;

/**
 * Test

SELECT public.create_cluster(
	'Test 1'
	, 'mdw'
	, '10.10.2.80'
	, 5432
	, 'sar'
	, 'sar'
	, 'gpadmin'
	, 'gpadmin'
);

 */
