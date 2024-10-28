BEGIN;

INSERT INTO public.alters(id,summary) VALUES
( 1011, 'post load functions to populate cluster_attribs' );



CREATE OR REPLACE FUNCTION public.post_load_cpu(
	v_cluster_id int
) RETURNS VOID AS $$
DECLARE
	cmetrics text;
	sql      text;
BEGIN
	PERFORM * FROM public.cluster_attribs
	  WHERE cluster_id = v_cluster_id
	    AND domain = 'segment.host.cores';
	IF FOUND THEN
		RETURN;
	END IF;

	cmetrics := public.cluster_metrics_schema(v_cluster_id);

	sql := format(
        'INSERT INTO public.cluster_attribs (cluster_id, domain, value)
        WITH period AS (SELECT min(max) AS max FROM (SELECT hostname, max(ts_round(period,60))
          FROM %s.cpu GROUP BY hostname) n
        )
        SELECT %s AS cluster_id, ''segment.host.cores'' AS domain, count(distinct cpu)::text AS value
          FROM %s.cpu c, period p
         WHERE ts_round(c.period,60) = p.max
           AND c.cpu <> ''all''
        UNION
        SELECT %s AS cluster_id, ''segment.hosts'' AS domain, count(distinct hostname)::text AS value
          FROM %s.cpu c, period p
         WHERE ts_round(c.period,60) = p.max'
		, cmetrics, v_cluster_id, cmetrics, v_cluster_id, cmetrics
	);
	EXECUTE sql;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_post_functions (load_function_id, postfunc, priority, frequency, enabled)
SELECT id AS load_function_id
     , 'public.post_load_cpu' AS postfunc
     , 100 AS priority
     , 10080 AS frequency
     , true AS enabled
  FROM public.load_functions
 WHERE tablename = 'cpu';


COMMIT;
