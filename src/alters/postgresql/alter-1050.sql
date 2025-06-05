BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1050, 'cputask (proc/s & context switches) added');

CREATE TABLE templates.cputask(
	hostname text,
	period   timestamptz NOT NULL,
	procs    float,
	cswch    float
);

CREATE INDEX ON templates.cputask(hostname, period);


CREATE OR REPLACE FUNCTION public.load_cputask( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'cputask', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_cputask', 'cputask', 100, true, '_raw_cputask_today', 1 );

/**
 * Add to existing, enabled clusters
 */
DO $$
DECLARE
	cserver  text;
	cmetrics text;
	logtbl   text;
BEGIN
	FOR cserver, cmetrics, logtbl IN
		SELECT public.cluster_server(c.id), public.cluster_metrics_schema(c.id), v.logtbl
		FROM public.clusters c, (VALUES (
	'__cputask_segments_today', '__cputask_master_today', '_raw_cputask_today',
	'__cputask_segments_yesterday', '__cputask_master_yesterday', '_raw_cputask_yesterday',
	'__cputask_segments_all', '__cputask_master_all', '_raw_cputask_all') ) AS v(logtbl)
	LOOP
		EXECUTE format('SELECT id = 1017 FROM %s.alters WHERE id = 1017', cmetrics) INTO alter_applied;
		IF NOT alter_applied THEN
			RAISE EXCEPTION 'Cluster % does not have alters/cloudberry/alter-1017.sql applied', public.cluster_id_from_schema(cmetrics);
		END IF;

		EXECUTE format(
		'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
		, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;

COMMIT;
