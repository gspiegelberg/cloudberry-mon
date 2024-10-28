BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1004, 'cpu added');

CREATE TABLE templates.cpu(
	hostname text,
	period   timestamptz NOT NULL,
	cpu      varchar(4),
	usr      float,
	nice     float,
	sys      float,
	iowait   float,
	steal    float,
	irq      float,
	soft     float,
	guest    float,
	gnice    float,
	idle     float
);

CREATE INDEX ON templates.cpu(hostname, period);


CREATE OR REPLACE FUNCTION public.load_cpu( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'cpu', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_cpu', 'cpu', 100, true, '_raw_cpu_today', 1 );

COMMIT;
