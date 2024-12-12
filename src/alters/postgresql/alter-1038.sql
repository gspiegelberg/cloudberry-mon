BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1038, 'detailed lock information');


INSERT INTO public.alter_requires (alter_id, required) VALUES
( 1015, '{1007, 1008, 1009, 1010}' );


/**
 * relacl & relpartbound are not handled well by postgres_fdw
 * remove from existing cat_pg_class ft's
 */
/*
DO $$
DECLARE
	nsp text;
	sql text;
BEGIN
	FOR nsp IN
	SELECT nspname FROM pg_namespace
	 WHERE nspname ~ '^metrics_'
	LOOP
		sql := format(
			'ALTER FOREIGN TABLE %s.cat_pg_class DROP COLUMN relacl'
			, nsp
		);
		EXECUTE sql;

		sql := format(
			'ALTER FOREIGN TABLE %s.cat_pg_class DROP COLUMN relacl'
			, nsp
		);
		EXECUTE sql;
	END LOOP;
END $$;
*/


CREATE TABLE templates.lock_detail_history(
       hostname               text
     , period                 timestamptz NOT NULL
     , database               text
     , table_schema           text
     , table_name             text
     , lock_pid               int
     , wait_pid               int
     , lock_mode              text
     , wait_mode              text
     , lock_granted           boolean
     , wait_granted           boolean
     , lock_session_id        int
     , wait_session_id        int
     , lock_role              text
     , wait_role              text
     , lock_application_name  text
     , wait_application_name  text
     , lock_client_addr       inet
     , wait_client_addr       inet
     , lock_query_start       timestamptz
     , wait_query_start       timestamptz
     , lock_waitstart         timestamptz
     , wait_waitstart         timestamptz
     , lock_wait_event_type   text
     , wait_wait_event_type   text
     , lock_wait_event        text
     , wait_wait_event        text
     , lock_session_state     text
     , wait_session_state     text
     , lock_query             text
     , wait_query             text
);

CREATE INDEX ON templates.lock_detail_history(hostname, period);


CREATE OR REPLACE FUNCTION public.load_lock_detail_history(
	v_cluster_id int
	, v_prime boolean
) RETURNS VOID AS $$
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

	EXECUTE sql;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';


COMMENT ON FUNCTION public.load_lock_detail_history(int, boolean) IS 'Detailed lock information';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_lock_detail_history', 'lock_detail_history', 100, true, '', 1 );


COMMIT;


