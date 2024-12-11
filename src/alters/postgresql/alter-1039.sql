BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1039, 'Include query spill');


INSERT INTO public.alter_requires (alter_id, required) VALUES
( 1022, '{1007, 1009}' );


/**
 * Add spill_size_bytes to all parent and template tables
 */
DO $$
DECLARE 
	rel text;
BEGIN
	FOR rel IN
	SELECT format('%s.%s', pn.nspname, pc.relname) AS rel
	  FROM pg_class pc
	       JOIN pg_namespace pn ON (pc.relnamespace = pn.oid)
	 WHERE pc.relname = 'long_running_query_history'
	   AND pc.relkind IN ( 'r', 'p' )
	 ORDER BY 
	 (CASE WHEN pn.nspname = 'templates' THEN 0
	       WHEN pn.nspname <> 'templates' AND pc.relname = 'long_running_query_history' THEN 1
	       ELSE 2 END) ASC, 1 ASC
	LOOP
		EXECUTE format(
			'ALTER TABLE %s ADD COLUMN spill_size_bytes bigint'
			, rel
		);
	END LOOP;
END $$; 


/**
 * Update including spill size
 */
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
		, quote_literal(threshold)
	);
	EXECUTE sql;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';

COMMENT ON FUNCTION public.load_long_running_query_history(int, boolean) IS 'Snapshot of long running queries';


COMMIT;
