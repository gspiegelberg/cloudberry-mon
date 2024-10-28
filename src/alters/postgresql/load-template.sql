BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( {ALTER_ID}, '{ALTER_DESC}');

/**
 * Metrics/historical tables are partitioned and managed by pg_partman and calling public.load() procedure
 * Templates must be created in templates schema
 * Templates should have all required indexes and constraints
 */
CREATE TABLE templates.{METRIC_TABLE_TEMPLATE}(
	hostname text,
	period   timestamptz NOT NULL,
	{METRIC_COLUMNS}
);

CREATE INDEX ON templates.{METRIC_TABLE_INDEX}(hostname, period);


/**
 * Function called by public.load() must accept cluster.id and boolean
 * where boolean can be used to trigger a load of all remote information
 * if available. Function can safely ignore v_prime if information not
 * available such as disk space.
 */
CREATE OR REPLACE FUNCTION public.{METRIC_LOAD_FUNCTION}( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	/**
	 * Use the following if leveraging public.loader_sar()
	 * PERFORM * FROM public.loader_sar( v_cluster_id, 'METRIC_TABLE_TEMPLATE}', v_prime );
	 *
	 * Alternatively, METRIC_LOAD_FUNCTION may do it's own custom querying in place
	 * of using public.loader_sar()
	 */
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


/**
 * funcname is 'public.METRIC_LOAD_FUNCTION'
 * tablename is name of metrics/historical table without cluster
 * priority is order in loading process. Long running load functions should have a lower priority.
 * enabled should be true however may be turned off to disable for all clusters
 * fdwtable required only if METRIC_LOAD_FUNCTION leverages public.loader_sar()
 * frequency is (public.minute_of_week() % frequency) = 0 where 1 is every minute, 60 every hour and so on 
 */
INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.{METRIC_LOAD_FUNCTION}', '{METRIC_TABLE_TEMPALTE}', 100, true, '{METRIC_FDW_TABLE}', 1 );

COMMIT;
