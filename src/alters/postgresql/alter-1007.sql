BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1007, 'memory added');

CREATE TABLE templates.memory(
	hostname text,
	period   timestamptz NOT NULL,
	kbmemfree     int,
	kbavail       int,
	kbmemused     int,
	memused_pct   float,
	kbbuffers     int,
	kbcached      int,
	kbcommit      int,
	commit_pct    float,
	kbactive      int,
	kbinact       int,
	kbdirty       int,
	kbanonpg      int,
	kbslab        int,
	kbkstack      int,
	kbpgtbl       int,
	kbvmused      int
);

CREATE INDEX ON templates.memory(hostname, period);


CREATE OR REPLACE FUNCTION public.load_memory( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'memory', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_memory', 'memory', 100, true, '_raw_memory_today', 1 );

COMMIT;
