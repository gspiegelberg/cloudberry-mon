BEGIN;


INSERT INTO public.alters(id,summary) VALUES
( 1023, 'increase cursor fetch size from 100 (default) to 100000' );


/**
 * For adjusting foreign tables after creation
 */
CREATE OR REPLACE FUNCTION public.adjust_foreign_tables(
	v_cluster_id int
) RETURNS VOID AS $$
DECLARE
	cmetric text;
	fsize   int;
	option  text;
	sql     text;
	rec     record;
BEGIN
	cmetric := public.cluster_metrics_schema(v_cluster_id);
	SELECT INTO fsize value::int
	  FROM public.cluster_attribs
	 WHERE cluster_id = v_cluster_id
	   AND domain = 'cbmon.fetch_size';
	IF fsize IS NULL THEN
		fsize := 100000;
	END IF;

	FOR rec IN
	SELECT c.oid AS ftoid, n.nspname, c.relname
	  FROM pg_class c
	       JOIN pg_namespace n ON (c.relnamespace=n.oid)
	 WHERE relkind = 'f'
	   AND n.nspname = cmetric
	LOOP
		PERFORM * 
		  FROM (SELECT unnest(ftoptions)
			  FROM pg_foreign_table
			 WHERE ftrelid = rec.ftoid
		       ) x
		 WHERE unnest::text ~ 'fetch_size=';
		IF FOUND THEN
			option := 'SET';
		ELSE
			option := 'ADD';
		END IF;

		sql := format(
			'ALTER FOREIGN TABLE %s.%s OPTIONS(%s fetch_size ''%s'')'
			, rec.nspname, rec.relname, option, fsize
		);
		EXECUTE sql;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


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
	cserver  text;
	fsize    int;
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

        SELECT INTO fsize value::int
          FROM public.cluster_attribs
         WHERE cluster_id IS NULL
           AND domain = 'cbmon.fetch_size';
        IF fsize IS NULL THEN
                fsize := 100000;
        END IF;

	-- create foreign server
	sql := format(
		'CREATE SERVER %s FOREIGN DATA WRAPPER postgres_fdw OPTIONS(host %s, port %s, dbname %s, fetch_size %s)'
		, cserver, quote_literal(v_mdwip)
		, quote_literal(v_port), quote_literal(v_cbmondb)
		, quote_literal(fsize)
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
		    FROM (SELECT DISTINCT hostname FROM %s.cat_gp_segment_configuration WHERE content >= 0 AND hostname <> %s) x',
		cid, cfdw, quote_literal(v_mdwname)
	);
	EXECUTE sql;

	RETURN cid;
END;
$$;


COMMIT;
