BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1051, 'paging statistics added');

CREATE TABLE templates.paging(
	hostname  text,
	period    timestamptz NOT NULL,
	pgpgins   float,
	pgpgouts  float,
	faults    float,
	majflts   float,
	pgfrees   float,
	pgscanks  float,
	pgscands  float,
	pgsteals  float,
	vmeff_pct float
);

CREATE INDEX ON templates.paging(hostname, period);


CREATE OR REPLACE FUNCTION public.load_paging( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'paging', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_paging', 'paging', 100, true, '_raw_paging_today', 1 );

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
	('cbmon.__paging_segments_today'), ('cbmon.__paging_master_today'), ('cbmon._raw_paging_today'),
	('cbmon.__paging_segments_yesterday'), ('cbmon.__paging_master_yesterday'), ('cbmon._raw_paging_yesterday'),
	('cbmon.__paging_segments_all'), ('cbmon.__paging_master_all'), ('cbmon._raw_paging_all') ) AS v(logtbl)
	LOOP
		EXECUTE format('SELECT id = 1018 FROM %s.alters WHERE id = 1018', cmetrics) INTO alter_applied;
		IF NOT alter_applied THEN
			RAISE EXCEPTION 'Cluster % does not have alters/cloudberry/alter-1018.sql applied', public.cluster_id_from_schema(cmetrics);
		END IF;

		EXECUTE format(
		'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
		, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;

COMMIT;
