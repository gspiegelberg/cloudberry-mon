BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1067, 'Add pxf memory stats from jcmd script');

CREATE TABLE templates.pxf_memory_stats(
        period timestamptz NOT NULL,
        hostname text,
        total_reserved_kb integer,
        total_committed_kb integer,
        java_heap_reserved_kb integer,
        java_heap_committed_kb integer,
        class_reserved_kb integer,
        class_committed_kb integer,
        thread_reserved_kb integer,
        thread_committed_kb integer,
        code_reserved_kb integer,
        code_committed_kb integer,
        gc_reserved_kb integer,
        gc_committed_kb integer,
        compiler_reserved_kb integer,
        compiler_committed_kb integer,
        internal_reserved_kb integer,
        internal_committed_kb integer,
        other_reserved_kb integer,
        other_committed_kb integer,
        symbol_reserved_kb integer,
        symbol_committed_kb integer,
        native_memory_tracking_reserved_kb integer,
        native_memory_tracking_committed_kb integer,
        shared_class_space_reserved_kb integer,
        shared_class_space_committed_kb integer,
        arena_chunk_reserved_kb integer,
        arena_chunk_committed_kb integer,
        logging_reserved_kb integer,
        logging_committed_kb integer,
        arguments_reserved_kb integer,
        arguments_committed_kb integer,
        module_reserved_kb integer,
        module_committed_kb integer,
        synchronizer_reserved_kb integer,
        synchronizer_committed_kb integer,
        safepoint_reserved_kb integer,
        safepoint_committed_kb integer
);

CREATE OR REPLACE FUNCTION public.load_pxf_memory_stats(
  v_cluster_id int,
  v_prime boolean
) RETURNS VOID AS $$
DECLARE
  cmetrics text;
  sql      text;
BEGIN
  cmetrics := public.cluster_metrics_schema( v_cluster_id );
  sql := format(
    'INSERT INTO %s.pxf_memory_stats SELECT * FROM %s._pxf_memory_stats'
    , cmetrics, cmetrics
  );
  EXECUTE sql;
  RETURN;
END;
$$ LANGUAGE 'plpgsql';

INSERT INTO public.load_functions (funcname, tablename, priority, enabled, fdwtable, frequency)
VALUES ( 'public.load_pxf_memory_stats', 'pxf_memory_stats', 100, true, '_pxf_memory_stats', 1 );

DO $$
DECLARE
	cserver  text;
	cmetrics text;
	logtbl   text;
	alter_applied boolean;
BEGIN
	FOR cserver, cmetrics, logtbl IN
		SELECT public.cluster_server(c.id), public.cluster_metrics_schema(c.id), v.logtbl
		FROM public.clusters c, (VALUES ('_pxf_memory_stats') ) AS v(logtbl)
		 WHERE c.enabled
	LOOP
		EXECUTE format('SELECT id = 1026 FROM %s.alters WHERE id = 1026', cmetrics) INTO alter_applied;
		IF NOT alter_applied THEN
			RAISE EXCEPTION 'Cluster % does not have alters/cloudberry/alter-1026.sql applied', public.
cluster_id_from_schema(cmetrics);
		END IF;

		EXECUTE format(
		'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
		, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;

COMMIT;


