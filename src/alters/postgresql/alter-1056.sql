UPDATE partman.part_config
   SET retention = '7 days'
 WHERE parent_table = 'metrics_1.query_historical_statistics'

/**
 * Will replace query_historical_statistics gathering
 */
BEGIN;

INSERT INTO public.alters (id,summary) VALUES
( 1056, 'capture live backends metrics' );


/**
 * Query store
 */
CREATE TABLE templates.live_backend_historical(
        hostname    text,
        period      timestamp with time zone NOT NULL,
        create_ts   double precision,
        pid         integer,
        status      text,
        server_port integer,
        role        text,
        database    text,
        client_ip   inet,
        client_port integer,
        session_id  integer,
        cmdno       integer,
        content     integer,
        slice       integer,
        sqlcmd      text,
        read_count  bigint,
        read_bytes  bigint,
        write_count bigint,
        write_bytes bigint,
        rss         bigint,
        vms         bigint,
        shared      bigint,
        data        bigint,
        dirty       bigint,
        uss         bigint,
        pss         bigint,
        swap        bigint,
        mempct      double precision,
        cpu_usr     double precision,
        cpu_sys     double precision,
        cpu_iowait  double precision,
        ctxsw_vol   integer,
        ctxsw_invol integer
);

CREATE INDEX ON templates.live_backend_historical (period);
CREATE INDEX ON templates.live_backend_historical (role, session_id, cmdno, pid);


/**
 * Effectively a snapshot of current running state / resource consumption
 */
CREATE OR REPLACE FUNCTION public.load_live_backend_historical(
        v_cluster_id int
        , v_prime boolean
) RETURNS VOID AS $$
DECLARE
        cmetrics     text;
        way_behind   boolean;
        qs_table     text;
        max_period   timestamptz;
        sql          text;
        cl_table     text;
BEGIN
        cmetrics := public.cluster_metrics_schema( v_cluster_id );

        /**
         * Verify metrics table exists
         */
        PERFORM * FROM public.check_metric_table( v_cluster_id, 'live_backend_historical' );

        sql := format('INSERT INTO %s.live_backend_historical SELECT * FROM %s.live_backends'
                , cmetrics, cmetrics
        );
        EXECUTE sql;

        RETURN;
END;
$$ LANGUAGE 'plpgsql';

INSERT INTO public.load_functions
 (funcname, tablename, fdwtable, priority, enabled, frequency) VALUES
 ('public.load_live_backend_historical', 'live_backend_historical', '', 100, true::boolean, 1);

COMMIT;
