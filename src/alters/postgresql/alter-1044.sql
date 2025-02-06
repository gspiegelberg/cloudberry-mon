BEGIN;

INSERT INTO public.alters(id,summary) VALUES
( 1044, 'loader_sar optimization' );


/**
 * Optimization - if v_prime check target table to see if it is warranted
 */
CREATE OR REPLACE FUNCTION public._loader_sar( v_cluster_id int, v_metrics text, v_prime boolean )
RETURNS VOID AS $$
DECLARE
	cols1    text;
	cols2    text;
	today    date;
	sql      text;
	cfdw     text;
	cmetrics text;
	fdwtbl   text;
	all_check boolean;
BEGIN
	today    := date_trunc('day', now());
	cfdw     := public.cluster_fdw_schema( v_cluster_id );
	cmetrics := public.cluster_metrics_schema( v_cluster_id );

	SELECT INTO fdwtbl fdwtable FROM public.load_functions
	 WHERE tablename = v_metrics;

	-- Load everything available if v_prime
	IF v_prime THEN
		all_check := false;
		EXECUTE format('SELECT max(period) < date_trunc(''day'', now()) FROM %s.%s' , cmetrics, v_metrics)
		   INTO all_check;
		IF all_check THEN
			-- Verify *_all FDT exists
			PERFORM * FROM information_schema.tables
			  WHERE table_schema = cfdw AND table_name = replace(fdwtbl, 'today', 'all');
			IF FOUND THEN
				fdwtbl := replace(fdwtbl, 'today', 'all');
			END IF;
		END IF;
	END IF;

	SELECT INTO cols1 substr(array_agg, 2, length(array_agg)-2)
	  FROM (SELECT array_agg(column_name)::text
	          FROM information_schema.columns
	         WHERE table_schema||'.'||table_name = cmetrics||'.'||v_metrics)x;

	SELECT INTO cols2 substr(array_agg, 2, length(array_agg)-2)
	  FROM (SELECT array_agg('d.'||column_name)::text
	          FROM information_schema.columns
	         WHERE table_schema||'.'||table_name = cmetrics||'.'||v_metrics)x;

	sql := format(
		'INSERT INTO %s.%s (%s)
	WITH maxes AS (
	SELECT ch.hostname, COALESCE(max(period)::timestamp, ''2020-01-01 00:00:00''::timestamp) AS max
	  FROM public.cluster_hosts ch LEFT JOIN %s.%s d ON (ch.hostname = d.hostname)
	 GROUP BY 1
	)
	SELECT %s
	  FROM %s.%s d JOIN maxes m ON (d.hostname = m.hostname AND d.period > m.max)',
		cmetrics, v_metrics, cols1, cmetrics, v_metrics, cols2, cfdw, fdwtbl
	);

	-- RAISE NOTICE 'sql=%', sql;
	EXECUTE sql;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';

COMMIT;
