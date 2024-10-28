BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1008, 'network sar info added');


CREATE TABLE templates.network_dev(
        hostname      text,
        period        timestamptz NOT NULL,
        iface         text,
        rxpck_psec    float,
        txpck_psec    float,
        rxkb_psec     float,
        txkb_psec     float,
        rxcmp_psec    float,
        txcmp_psec    float,
        rxmcst_psec   float,
        ifutil_pct    float
);

CREATE INDEX ON templates.network_dev(hostname, period);

CREATE OR REPLACE FUNCTION public.load_network_dev( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'network_dev', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_network_dev', 'network_dev', 100, true, '_raw_network_dev_today', 1 );



CREATE TABLE templates.network_errors(
        hostname      text,
        period        timestamptz NOT NULL,
        iface         text,
	rxerr_psec  float,
	txerr_psec  float,
	coll_psec   float,
	rxdrop_psec float,
	txdrop_psec float,
	txcarr_psec float,
	rxfram_psec float,
	rxfifo_psec float,
	txfifo_psec float
);

CREATE INDEX ON templates.network_errors(hostname, period);

CREATE OR REPLACE FUNCTION public.load_network_errors( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'network_errors', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_network_errors', 'network_errors', 100, true, '_raw_network_errors_today', 1 );



CREATE TABLE templates.network_sockets(
        hostname      text,
        period        timestamptz NOT NULL,
	totsck        int,
	tcpsck        int,
	udpsck        int,
	rawsck        int,
	ip_frag       int,
	tcp_tw        int
);

CREATE INDEX ON templates.network_sockets(hostname, period);

CREATE OR REPLACE FUNCTION public.load_network_sockets( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'network_sockets', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_network_sockets', 'network_sockets', 100, true, '_raw_network_sockets_today', 1 );



CREATE TABLE templates.network_softproc(
        hostname      text,
        period        timestamptz NOT NULL,
	cpu           text,
	total_psec    float,
	dropd_psec    float,
	squeezd_psec  float,
	rx_rps_psec   float,
	flw_lim_psec  float
);

CREATE INDEX ON templates.network_softproc(hostname, period);

CREATE OR REPLACE FUNCTION public.load_network_softproc( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
	PERFORM * FROM public.loader_sar( v_cluster_id, 'network_softproc', v_prime );
	RETURN;
END;
$$ LANGUAGE 'plpgsql';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_network_softproc', 'network_softproc', 100, true, '_raw_network_softproc_today', 1 );


CREATE TABLE templates.swap(
        hostname      text,
        period        timestamptz NOT NULL,
        kbswpfree     int,
        kbswpused     int,
        swpused_pct   float,
        kbswpcad      int,
        swpcad_pct    float
);

CREATE INDEX ON templates.swap(hostname, period);

CREATE OR REPLACE FUNCTION public.load_swap( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
BEGIN
        PERFORM * FROM public.loader_sar( v_cluster_id, 'swap', v_prime );
        RETURN;
END;
$$ LANGUAGE 'plpgsql';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_swap', 'swap', 100, true, '_raw_swap_today', 1 );



COMMIT;
