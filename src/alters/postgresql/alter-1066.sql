BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1066, 'adding pg side of mpp alter-1025 to find core dumps' );

/**
 * Add to existing, enabled clusters
 */
DO $$
DECLARE
	cserver  text;
	cmetrics text;
	logtbl   text;
	alter_applied boolean;
BEGIN
	FOR cserver, cmetrics, logtbl IN
		SELECT public.cluster_server(c.id), public.cluster_metrics_schema(c.id), v.logtbl
		FROM public.clusters c, (VALUES
		( '__segment_cores' ),
		( '__master_cores' ),
		( '_cluster_cores' )
	) AS v(logtbl)
		 WHERE c.enabled
	LOOP
		EXECUTE format('SELECT id = 1025 FROM %s.alters WHERE id = 1025', cmetrics) INTO alter_applied;
		IF NOT alter_applied THEN
			RAISE EXCEPTION 'Cluster % does not have alters/cloudberry/alter-1025.sql applied', public.cluster_id_from_schema(cmetrics);
		END IF;

		EXECUTE format(
		'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
		, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;


CREATE TABLE templates.cluster_cores(
        period   timestamptz NOT NULL,
        hostname text,
        path     text,
        process  text,
        signal   int,
        uid      int,
        gid      int,
        pid      int,
        ts       bigint
);

CREATE INDEX ON templates.cluster_cores(hostname, period);


CREATE OR REPLACE FUNCTION public.load_cluster_cores( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
DECLARE
	cmetrics text;
	first_run boolean;
	last_period timestamptz;
	minperiod timestamptz;
	sql text;
	this_table text;
BEGIN
	cmetrics := public.cluster_metrics_schema( v_cluster_id ) ;
	this_table := 'cluster_cores';

	EXECUTE format(
	'SELECT last_period_end FROM public.summary_tracking WHERE cluster_id = %s AND summary_table = %s'
	, v_cluster_id, quote_literal(this_table)
	) INTO minperiod;

	first_run := false;
	IF minperiod IS NULL THEN
		-- match how back find-cores looks
		minperiod := clock_timestamp() - interval'7 days';
		first_run := true;
	END IF;

	sql := format(
	'WITH ins AS (
INSERT INTO %s.cluster_cores
SELECT now() AS period, hostname, path, process, signal, uid, gid, pid, ts
  FROM %s._cluster_cores
 WHERE ts > %s
 RETURNING ts
)
SELECT to_timestamp(max(ts)) FROM ins'
	, cmetrics, cmetrics, extract(epoch from minperiod)
	);

	EXECUTE sql INTO last_period;

	IF last_period IS NOT NULL THEN
		IF first_run THEN
			INSERT INTO public.summary_tracking (cluster_id, summary_table, period_interval, last_period_end)
			VALUES ( v_cluster_id, this_table, 0, last_period );
		ELSE
			UPDATE public.summary_tracking
			   SET last_period_end = last_period
			 WHERE cluster_id = v_cluster_id
			   AND summary_table = this_table
			   AND period_interval = 0;
		END IF;
	END IF;

        RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_cluster_cores', 'cluster_cores', 100, true, '_cluster_cores', 1 );


COMMIT;
