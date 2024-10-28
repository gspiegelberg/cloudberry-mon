BEGIN;


INSERT INTO public.alters(id,summary) VALUES
( 1016, 'address single host clusters' );


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
		RAISE EXCEPTION 'Host % already exists', v_hostname;
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
		    FROM (SELECT DISTINCT hostname FROM %s.cat_gp_segment_configuration WHERE content >= 0 AND hostname <> %s) x',
		cid, cfdw, quote_literal(v_mdwname)
	);
	EXECUTE sql;

	RETURN cid;
END;
$$;


COMMIT;
