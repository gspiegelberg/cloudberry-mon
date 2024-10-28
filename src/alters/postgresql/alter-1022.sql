/**
 * Not meant to capture every query. Designed to look for queries
 * running over 5 minutes (default) or tunable by cluster in
 * public.cluster_attribs with a row like that below except where
 * cluster_id is NOT NULL.
 */
BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1022, 'long running query history');


INSERT INTO public.alter_requires (alter_id, required) VALUES
( 1022, '{1007, 1009}' );


INSERT INTO public.cluster_attribs (cluster_id,domain,value) VALUES
( NULL, 'load_function.long_running_query.threshold', '5 minutes');


CREATE TABLE templates.long_running_query_history(
	hostname         text,
	period           timestamptz NOT NULL
     , gp_segment_id     integer
     , datid             oid
     , datname           name
     , pid               integer
     , sess_id           integer
     , leader_pid        integer
     , usesysid          oid
     , usename           name
     , application_name  text
     , client_addr       inet
     , client_hostname   text
     , client_port       integer
     , backend_start     timestamptz
     , xact_start        timestamptz
     , query_start       timestamptz
     , state_change      timestamptz
     , wait_event_type   text
     , wait_event        text
     , state             text
     , backend_xid       xid
     , backend_xmin      xid
     , query_id          bigint
     , query             text
     , backend_type      text
     , rsgid             integer
     , rsgname           text
);

CREATE INDEX ON templates.long_running_query_history(hostname, period);


CREATE OR REPLACE FUNCTION public.load_long_running_query_history(
	v_cluster_id int
	, v_prime boolean
) RETURNS VOID AS $$
DECLARE
	cmetric   text;
	metrictbl text;
	sql       text;
	threshold interval;
BEGIN
	cmetric := public.cluster_metrics_schema( v_cluster_id );

	SELECT INTO metrictbl tablename FROM public.load_functions
	 WHERE funcname = 'public.load_long_running_query_history'
	 LIMIT 1;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'load_function missing record where funcname = load_long_running_query_history';
		RETURN;
	END IF;

	PERFORM * FROM public.check_metric_table(
		v_cluster_id, metrictbl
	);

	SELECT INTO threshold (value)::interval
	  FROM public.cluster_attribs
	 WHERE (cluster_id = v_cluster_id
	    OR cluster_id IS NULL)
	   AND domain = 'load_function.long_running_query.threshold'
	 ORDER BY cluster_id NULLS LAST
	 LIMIT 1;

	IF threshold IS NULL THEN
		threshold := '5 minutes';
	END IF;

	sql := format('
INSERT INTO %s.long_running_query_history (hostname, period, gp_segment_id, datid
     , datname , pid , sess_id , leader_pid , usesysid , usename , application_name
     , client_addr , client_hostname , client_port , backend_start , xact_start
     , query_start , state_change , wait_event_type , wait_event , state , backend_xid
     , backend_xmin , query_id , query , backend_type , rsgid , rsgname)
SELECT (SELECT hostname FROM public.cluster_hosts WHERE cluster_id = %s AND is_mdw) AS hostname
     , now() AS period , gp_segment_id , datid , datname , pid , sess_id , leader_pid
     , usesysid , usename , application_name , client_addr , client_hostname , client_port
     , backend_start , xact_start , query_start , state_change , wait_event_type
     , wait_event , state , backend_xid , backend_xmin , query_id , query
     , backend_type , rsgid , rsgname
  FROM %s.cat_gp_stat_activity gsa
 WHERE gsa.sess_id > 1
   AND gsa.gp_segment_id = -1
   AND gsa.state = ''active''
   AND (now() - query_start) > (%s)::interval '
		, cmetric, v_cluster_id, cmetric
		, quote_literal(threshold)
	);
	EXECUTE sql;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';

COMMENT ON FUNCTION public.load_long_running_query_history(int, boolean) IS 'Snapshot of locks';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_long_running_query_history', 'long_running_query_history', 100, true, '', 1 );


COMMIT;
