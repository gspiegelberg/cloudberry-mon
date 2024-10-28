BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1003, 'loadavg added');

CREATE TABLE templates.ldavg(
	hostname text,
	period   timestamptz NOT NULL,
	runq_sz  float,
	plist_sz float,
	ldavg_1  float,
	ldavg_5  float,
	ldavg_15 float,
	blocked  float
);

CREATE INDEX ON templates.ldavg(hostname, period);


CREATE OR REPLACE FUNCTION public.load_ldavg( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'ldavg', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_ldavg', 'ldavg', 100, true, '_raw_ldavg_today', 1 );

COMMIT;
