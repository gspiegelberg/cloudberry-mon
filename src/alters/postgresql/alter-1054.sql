BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1054, 'add support EDB Warehouse PG or Cloudberry');


CREATE OR REPLACE FUNCTION public.cb_long_running_query_history(
	v_cluster_id int
	, v_threshold interval
) RETURNS text AS $$
DECLARE
	cmetric  text := public.cluster_metrics_schema( v_cluster_id );
BEGIN
        RETURN format('
INSERT INTO %s.long_running_query_history (hostname, period, gp_segment_id, datid
     , datname , pid , sess_id , leader_pid , usesysid , usename , application_name
     , client_addr , client_hostname , client_port , backend_start , xact_start
     , query_start , state_change , wait_event_type , wait_event , state , backend_xid
     , backend_xmin , query_id , query , backend_type , rsgid , rsgname, spill_size_bytes)
WITH gwe AS (
SELECT sess_id
     , sum(size) AS spill_size
  FROM %s.cat_gp_workfile_entries
 GROUP BY 1
)
SELECT (SELECT hostname FROM public.cluster_hosts WHERE cluster_id = %s AND is_mdw) AS hostname
     , now() AS period , gp_segment_id , datid , datname , pid , gsa.sess_id , leader_pid
     , usesysid , usename , application_name , client_addr , client_hostname , client_port
     , backend_start , xact_start , query_start , state_change , wait_event_type
     , wait_event , state , backend_xid , backend_xmin , query_id , query
     , backend_type , rsgid , rsgname, gwe.spill_size
  FROM %s.cat_gp_stat_activity gsa
       LEFT JOIN gwe ON (gsa.sess_id = gwe.sess_id)
 WHERE gsa.sess_id > 1
   AND gsa.gp_segment_id = -1
   AND gsa.state = ''active''
   AND (now() - query_start) > (%s)::interval'
                , cmetric, cmetric, v_cluster_id, cmetric
                , quote_literal(v_threshold)
        );
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;


CREATE OR REPLACE FUNCTION public.whpg_long_running_query_history(
	v_cluster_id int
	, v_threshold interval
) RETURNS text AS $$
DECLARE
	cmetric  text := public.cluster_metrics_schema( v_cluster_id );
BEGIN
	/**
	 * pg_stat_activity.leader_pid added in PG 13
	 * pg_stat_activity.query_id added in PG 14
	 */
        RETURN format('
INSERT INTO %s.long_running_query_history (hostname, period, gp_segment_id, datid
     , datname , pid , sess_id , leader_pid , usesysid , usename , application_name
     , client_addr , client_hostname , client_port , backend_start , xact_start
     , query_start , state_change , wait_event_type , wait_event , state , backend_xid
     , backend_xmin , query_id , query , backend_type , rsgid , rsgname, spill_size_bytes)
WITH gwe AS (
SELECT sess_id
     , sum(size) AS spill_size
  FROM %s.cat_gp_workfile_entries
 GROUP BY 1
)
SELECT (SELECT hostname FROM public.cluster_hosts WHERE cluster_id = %s AND is_mdw) AS hostname
     , now() AS period , gp_segment_id , datid , datname , pid , gsa.sess_id , NULL AS leader_pid
     , usesysid , usename , application_name , client_addr , client_hostname , client_port
     , backend_start , xact_start , query_start , state_change , wait_event_type
     , wait_event , state , backend_xid , backend_xmin , NULL AS query_id , query
     , backend_type , rsgid , rsgname, gwe.spill_size
  FROM %s.cat_gp_stat_activity gsa
       LEFT JOIN gwe ON (gsa.sess_id = gwe.sess_id)
 WHERE gsa.sess_id > 1
   AND gsa.gp_segment_id = -1
   AND gsa.state = ''active''
   AND (now() - query_start) > (%s)::interval'
                , cmetric, cmetric, v_cluster_id, cmetric
                , quote_literal(v_threshold)
        );
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;


CREATE OR REPLACE FUNCTION public.load_long_running_query_history(
	v_cluster_id int
	, v_prime boolean
) RETURNS VOID AS $$
DECLARE
	cmetric   text := public.cluster_metrics_schema( v_cluster_id );
	metrictbl text;
	sql       text;
	threshold interval;
BEGIN
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

	sql := CASE
                WHEN public.is_warehousepg( v_cluster_id ) OR public.is_greenplum( v_cluster_id )
			THEN public.whpg_long_running_query_history( v_cluster_id, threshold )
		WHEN public.is_cloudberry( v_cluster_id )
			THEN public.cb_long_running_query_history( v_cluster_id, threshold )
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
