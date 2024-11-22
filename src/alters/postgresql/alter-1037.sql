BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1037, 'ping monitoring of cluster hosts' );


INSERT INTO public.cluster_attribs (cluster_id, domain, value) VALUES
( NULL, 'shell.ping_test.ttl',   '1' ),
( NULL, 'shell.ping_test.count', '3' );


CREATE TABLE templates.pings(
        hostname     text,
        period       timestamptz,
        packets_sent int,
        packets_rcvd int,
        errors       int,
        packet_loss  int,
        ping_time    int,
        rtt_min      float,
        rtt_avg      float,
        rtt_max      float,
        rtt_mdev     float
);


CREATE OR REPLACE FUNCTION public.ping_test(
	v_cluster_id int
	, v_prime    boolean
) RETURNS VOID AS $$
DECLARE
	ping_count text;
	ping_ttl   text;
BEGIN
	SELECT INTO ping_count value
	  FROM public.cluster_attribs
	 WHERE (cluster_id = v_cluster_id OR cluster_id IS NULL)
	   AND domain = 'shell.ping_test.count'
	 ORDER BY cluster_id NULLS LAST
	 LIMIT 1;

	IF NOT FOUND THEN
		ping_count := '3';
	END IF;

	SELECT INTO ping_ttl value
	  FROM public.cluster_attribs
	 WHERE (cluster_id = v_cluster_id OR cluster_id IS NULL)
	   AND domain = 'shell.ping_test.ttl'
	 ORDER BY cluster_id NULLS LAST
	 LIMIT 1;

	IF NOT FOUND THEN
		ping_ttl := '1';
	END IF;

	PERFORM * FROM public._exec_cmd(
		v_cluster_id
		, format(
			'ping_test -c %s -p %s -t %s'
			, v_cluster_id
			, ping_count
			, ping_ttl )
		, 'pings'
		, '|'
	);

END;
$$ LANGUAGE 'plpgsql';


INSERT INTO public.load_shell_functions (funcname, tablename, fdwtable, priority, frequency, enabled) VALUES
( 'public.ping_test', 'pings', NULL, 100, 1, true );


COMMIT;
