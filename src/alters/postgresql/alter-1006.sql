BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1006, 'disk_space added');

CREATE TABLE templates.disk_space(
	hostname text,
	period   timestamptz NOT NULL,
	mntpt        text,
	total_kbs    bigint,
	used_kbs     bigint,
	avail_kbs    bigint
);

CREATE INDEX ON templates.disk_space(hostname, period);


CREATE OR REPLACE FUNCTION public.load_disk_space( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'disk_space', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_disk_space', 'disk_space', 50, true, '_disk_space_all', 1 );

COMMIT;
