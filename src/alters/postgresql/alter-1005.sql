BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1005, 'disk added');

CREATE TABLE templates.disk(
	hostname text,
	period   timestamptz NOT NULL,
	device   text,
	tps      float,
	rkbs     float,
	wkbs     float,
	areq_sz  float,
	aqu_sz   float,
	await    float,
	svctm    float,
	util_pct float
);

CREATE INDEX ON templates.disk(hostname, period);


CREATE OR REPLACE FUNCTION public.load_disk( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'disk', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_disk', 'disk', 100, true, '_raw_disk_today', 1 );

COMMIT;
