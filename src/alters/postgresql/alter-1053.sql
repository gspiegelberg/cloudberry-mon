BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1053, 'add support for EDB Warehouse PG or Cloudberry');

/**
 * Functions for use in functions where SQL may vary depending on tech in use
 */
DROP FUNCTION is_warehousepg();
DROP FUNCTION is_cloudberry();
DROP FUNCTION is_greenplum();

CREATE OR REPLACE FUNCTION public.is_warehousepg( v_cluster_id int )
RETURNS boolean AS $$
DECLARE
	tf boolean;
BEGIN
	EXECUTE format(
		'SELECT CASE WHEN version ~ ''WHPG.*WarehousePG'' THEN true ELSE false END FROM %s.version'
		, public.cluster_metrics_schema( v_cluster_id)
	) INTO tf;
	RETURN tf;
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;


CREATE OR REPLACE FUNCTION public.is_cloudberry( v_cluster_id int )
RETURNS boolean AS $$
DECLARE
	tf boolean;
BEGIN
	EXECUTE format(
		'SELECT CASE WHEN version ~ ''Cloudberry'' THEN true ELSE false END FROM %s.version'
		, public.cluster_metrics_schema( v_cluster_id)
	) INTO tf;
	RETURN tf;
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;


CREATE OR REPLACE FUNCTION public.is_greenplum( v_cluster_id int )
RETURNS boolean AS $$
DECLARE
	tf boolean;
BEGIN
	EXECUTE format(
		'SELECT CASE WHEN version ~ ''Greenplum'' AND NOT public.is_warehousepg(%s) THEN true ELSE false END FROM %s.version'
		, v_cluster_id, public.cluster_metrics_schema( v_cluster_id)
	) INTO tf;
	RETURN tf;
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;



CREATE OR REPLACE FUNCTION public.cb_lock_detail_history(
	v_cluster_id int
) RETURNS text AS $$
DECLARE
	cmetrics text;
	sql      text;
BEGIN
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	sql := format('
INSERT INTO %s.lock_detail_history
WITH lockers AS (
SELECT l.locktype, l.database, l.relation, l.mode, l.granted, l.waitstart, l.mppsessionid
     , psa.*
  FROM %s.cat_pg_locks l
       JOIN %s.cat_pg_stat_activity psa
         ON (l.mppsessionid = psa.sess_id)
 WHERE l.granted
   AND l.gp_segment_id = -1
), waiters AS (
SELECT l.locktype, l.database, l.relation, l.mode, l.granted, l.waitstart, l.mppsessionid
     , psa.*
  FROM %s.cat_pg_locks l
       JOIN %s.cat_pg_stat_activity psa
         ON (l.mppsessionid = psa.sess_id)
 WHERE NOT l.granted
   AND l.gp_segment_id = -1
)
SELECT (SELECT hostname FROM public.cluster_hosts WHERE cluster_id = %s AND is_mdw) AS hostname
     , now() AS period
     , l.datname AS database
     , pn.nspname AS table_schema
     , pc.relname AS table_name
     , l.pid AS lock_pid
     , w.pid AS wait_pid
     , l.mode AS lock_mode
     , w.mode AS wait_mode
     , l.granted AS lock_granted
     , w.granted AS wait_granted
     , l.mppsessionid AS lock_session_id
     , w.mppsessionid AS wait_session_id
     , l.usename AS lock_role
     , w.usename AS wait_role
     , l.application_name AS lock_application_name
     , w.application_name AS wait_application_name
     , l.client_addr AS lock_client_addr
     , w.client_addr AS wait_client_addr
     , l.query_start AS lock_query_start
     , w.query_start AS wait_query_start
     , l.waitstart AS lock_waitstart
     , w.waitstart AS wait_waitstart
     , l.wait_event_type AS lock_wait_event_type
     , w.wait_event_type AS wait_wait_event_type
     , l.wait_event AS lock_wait_event
     , w.wait_event AS wait_wait_event
     , l.state AS lock_session_state
     , w.state AS wait_session_state
     , l.query AS lock_query
     , w.query AS wait_query
  FROM lockers l JOIN waiters w
       USING (database, relation)
       JOIN %s.cat_pg_class pc ON (l.relation = pc.cat_oid)
       JOIN %s.cat_pg_namespace pn ON (pc.relnamespace = pn.cat_oid)'
	, cmetrics, cmetrics, cmetrics, cmetrics
        , cmetrics, v_cluster_id, cmetrics, cmetrics
	);

	RETURN sql;
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;


CREATE OR REPLACE FUNCTION public.whpg_lock_detail_history(
	v_cluster_id int
) RETURNS text AS $$
DECLARE
	cmetrics text;
	sql      text;
BEGIN
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	/**
	 * pg_lock_status() waitstart column added in PG 14 hence why missing
	 * in GP & WHPG
	 */
	sql := format('
INSERT INTO %s.lock_detail_history
WITH lockers AS (
SELECT l.locktype, l.database, l.relation, l.mode, l.granted, NULL::timestamptz AS waitstart, l.mppsessionid
     , psa.*
  FROM %s.cat_pg_locks l
       JOIN %s.cat_pg_stat_activity psa
         ON (l.mppsessionid = psa.sess_id)
 WHERE l.granted
   AND l.gp_segment_id = -1
), waiters AS (
SELECT l.locktype, l.database, l.relation, l.mode, l.granted, NULL::timestamptz AS waitstart, l.mppsessionid
     , psa.*
  FROM %s.cat_pg_locks l
       JOIN %s.cat_pg_stat_activity psa
         ON (l.mppsessionid = psa.sess_id)
 WHERE NOT l.granted
   AND l.gp_segment_id = -1
)
SELECT (SELECT hostname FROM public.cluster_hosts WHERE cluster_id = %s AND is_mdw) AS hostname
     , now() AS period
     , l.datname AS database
     , pn.nspname AS table_schema
     , pc.relname AS table_name
     , l.pid AS lock_pid
     , w.pid AS wait_pid
     , l.mode AS lock_mode
     , w.mode AS wait_mode
     , l.granted AS lock_granted
     , w.granted AS wait_granted
     , l.mppsessionid AS lock_session_id
     , w.mppsessionid AS wait_session_id
     , l.usename AS lock_role
     , w.usename AS wait_role
     , l.application_name AS lock_application_name
     , w.application_name AS wait_application_name
     , l.client_addr AS lock_client_addr
     , w.client_addr AS wait_client_addr
     , l.query_start AS lock_query_start
     , w.query_start AS wait_query_start
     , l.waitstart AS lock_waitstart
     , w.waitstart AS wait_waitstart
     , l.wait_event_type AS lock_wait_event_type
     , w.wait_event_type AS wait_wait_event_type
     , l.wait_event AS lock_wait_event
     , w.wait_event AS wait_wait_event
     , l.state AS lock_session_state
     , w.state AS wait_session_state
     , l.query AS lock_query
     , w.query AS wait_query
  FROM lockers l JOIN waiters w
       USING (database, relation)
       JOIN %s.cat_pg_class pc ON (l.relation = pc.cat_oid)
       JOIN %s.cat_pg_namespace pn ON (pc.relnamespace = pn.cat_oid)'
	, cmetrics, cmetrics, cmetrics, cmetrics
        , cmetrics, v_cluster_id, cmetrics, cmetrics
	);

	RETURN sql;
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;


CREATE OR REPLACE FUNCTION public.load_lock_detail_history(
	v_cluster_id int
	, v_prime boolean
) RETURNS VOID AS $$
DECLARE
	sql       text;
BEGIN
	sql := CASE
		WHEN public.is_warehousepg( v_cluster_id) OR public.is_greenplum( v_cluster_id )
			THEN public.whpg_lock_detail_history( v_cluster_id )
		WHEN public.is_cloudberry( v_cluster_id )
			THEN public.cb_lock_detail_history( v_cluster_id )
		ELSE
			NULL::text
	END;

	IF sql IS NULL THEN
		RAISE EXCEPTION 'unknown MPP PostgreSQL';
	END IF;

	EXECUTE sql;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';


COMMIT;
