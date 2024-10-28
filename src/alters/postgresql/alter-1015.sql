/*
 * Used in dev
DROP TABLE templates.lock_history;
DROP FUNCTION public.load_lock_history( v_cluster_id int, v_prime boolean );
DROP TABLE templates.lock_information;
DROP FUNCTION public.load_lock_information( v_cluster_id int, v_prime boolean );
DROP TABLE templates.rsq_queries;
DROP FUNCTION public.load_rsq_queries( v_cluster_id int, v_prime boolean );
DROP TABLE templates.rsq_queries_waiting;
DROP FUNCTION public.load_rsq_queries_waiting( v_cluster_id int, v_prime boolean );
DROP TABLE templates.lock_transaction_information;
DROP FUNCTION public.load_lock_transaction_information( v_cluster_id int, v_prime boolean );

DROP TABLE metrics_1.lock_history;
DROP TABLE metrics_1.lock_information;
DROP TABLE metrics_1.lock_transaction_information;
DROP TABLE metrics_1.rsq_queries;
DROP TABLE metrics_1.rsq_queries_waiting;

DELETE FROM public.load_functions
 WHERE funcname IN (
'public.load_lock_history',
'public.load_lock_information',
'public.load_lock_transaction_information',
'public.load_rsq_queries',
'public.load_rsq_queries_waiting'
);

DELETE FROM partman.part_config
 WHERE template_table IN (
 'templates.lock_history',
 'templates.rsq_queries_waiting',
 'templates.rsq_queries',
 'templates.load_lock_information',
 'templates.lock_transaction_information'
);

DELETE FROM alters WHERE id = 1015;
 */


BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1015, 'lock history visibility');


INSERT INTO public.alter_requires (alter_id, required) VALUES
( 1015, '{1007, 1008, 1009, 1010}' );


CREATE TABLE templates.lock_history(
	hostname     text,
	period       timestamptz NOT NULL,
	db_name      text,
	lock_type    text,
	relschema    text,
	relname      text,
	res_queue    text,
	num_waiters  int
);

CREATE INDEX ON templates.lock_history(hostname, period);


CREATE OR REPLACE FUNCTION public.load_lock_history( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
DECLARE
	cmetric text;
	sql     text;
BEGIN
	cmetric := public.cluster_metrics_schema( v_cluster_id );

	sql := format('
INSERT INTO %s.lock_history (hostname, period, db_name, lock_type, relschema, relname, res_queue, num_waiters)
SELECT (SELECT hostname FROM public.cluster_hosts WHERE cluster_id = %s AND is_mdw) AS hostname,
       now() AS period,
       db.datname AS db_name,
       l.locktype AS lock_type,
       ns.nspname AS relschema,
       cl.relname AS relname,
       rq.rsqname AS res_queue,
       count(*) AS num_waiters
FROM ( SELECT * FROM %s.cat_pg_locks WHERE granted=''f'') l
LEFT JOIN %s.cat_pg_database db ON ( db.cat_oid = l.database )
LEFT JOIN %s.cat_pg_class cl ON ( cl.cat_oid = l.relation )
LEFT JOIN %s.cat_pg_namespace ns ON ( ns.cat_oid = cl.relnamespace )
LEFT JOIN %s.cat_pg_resqueue rq ON ( rq.cat_oid = l.objid )
GROUP BY 1, 2, 3, 4, 5, 6, 7'
		, cmetric, v_cluster_id, cmetric, cmetric, cmetric, cmetric, cmetric
	);
	EXECUTE sql;

	RETURN;
END;
$$ LANGUAGE 'plpgsql';

COMMENT ON FUNCTION public.load_lock_history(int, boolean) IS 'Snapshot of locks';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_lock_history', 'lock_history', 100, true, '', 1 );



CREATE TABLE templates.lock_information(
        hostname          text,
        period            timestamptz NOT NULL,
	gp_segment_id     int,
	relation_id       int,
        db_name           text,
	relschema         text,
	relname           text,
	wait_pid          int,
        wait_mode         text,
	wait_session_id   int,
	lock_session_id   int,
	lock_mode         text
);

CREATE INDEX ON templates.lock_information(hostname, period);


CREATE OR REPLACE FUNCTION public.load_lock_information( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
DECLARE
        cmetric text;
        sql     text;
BEGIN
        cmetric := public.cluster_metrics_schema( v_cluster_id );

        sql := format('
INSERT INTO %s.lock_information (hostname, period, gp_segment_id, relation_id, db_name, relschema, relname, wait_pid, wait_mode, wait_session_id, lock_session_id, lock_mode)
SELECT (SELECT hostname FROM public.cluster_hosts WHERE cluster_id = %s AND is_mdw) AS hostname,
       now() AS period,
       l1.gp_segment_id,
       l1.relation AS relid,
       db.datname AS "db_name",
       ns.nspname AS "relschema",
       cl.relname AS "relname",
       l1.pid AS wait_pid,
       l1.mode AS wait_mode,
       l1.mppsessionid AS wait_session_id, -- waiting session
       l2.mppsessionid AS lock_session_id, -- blocking session
       l2.mode AS lock_mode
FROM (SELECT * FROM %s.cat_pg_locks WHERE locktype=''relation'') l1
LEFT JOIN %s.cat_pg_locks l2 ON (l1.relation = l2.relation
                          AND l1.database = l2.database
                          AND l1.gp_segment_id = l2.gp_segment_id
                          AND NOT l1.granted
                          AND l2.granted)
LEFT JOIN %s.cat_pg_database db ON (l1.database = db.cat_oid)
LEFT JOIN %s.cat_pg_class cl ON (l1.relation = cl.cat_oid)
LEFT JOIN %s.cat_pg_namespace ns ON (ns.cat_oid = cl.relnamespace)
LEFT JOIN %s.cat_pg_stat_activity act1 ON (l1.mppsessionid = act1.sess_id)
LEFT JOIN %s.cat_pg_stat_activity act2 ON (l2.mppsessionid = act2.sess_id)
WHERE l2.granted
ORDER BY relid, gp_segment_id'
                , cmetric, v_cluster_id, cmetric, cmetric, cmetric, cmetric, cmetric, cmetric, cmetric
        );
        EXECUTE sql;

        RETURN;
END;
$$ LANGUAGE 'plpgsql';

COMMENT ON FUNCTION public.load_lock_information(int, boolean) IS 'Snapshot of waiting sessions and locking sessions';


INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_lock_information', 'lock_information', 100, true, '', 1 );



CREATE TABLE templates.rsq_queries(
        hostname      text,
        period        timestamptz NOT NULL,
        lock_type     text,
        res_queue     text,
        db_name       text,
        pid           int,
        session_id    int,
        query_prefix  text,
	query_blocked boolean,
	query_appname text,
	query_start   timestamptz
);

CREATE INDEX ON templates.rsq_queries(hostname, period);


CREATE OR REPLACE FUNCTION public.load_rsq_queries( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
DECLARE
        cmetric text;
        sql     text;
BEGIN
        cmetric := public.cluster_metrics_schema( v_cluster_id );

        sql := format('
INSERT INTO %s.rsq_queries (hostname, period, lock_type, res_queue, db_name, pid, session_id, query_prefix, query_blocked, query_appname, query_start)
SELECT (SELECT hostname FROM public.cluster_hosts WHERE cluster_id = %s AND is_mdw) AS hostname,
       now() AS period,
       l1.locktype AS lock_type,
       rq.rsqname AS rsqname,
       db.datname AS db_name,
       l1.pid AS pid,
       l1.mppsessionid AS session_id,
       substr(a.query, 1, 50) AS query_prefix,
       CASE WHEN (SELECT count(*) FROM %s.cat_pg_locks l2
                   WHERE l2.mppsessionid = l1.mppsessionid
                     AND not granted) > 0 THEN TRUE
            ELSE FALSE END AS query_blocked,
       a.application_name AS query_appname,
       a.query_start
FROM (SELECT * FROM %s.cat_pg_locks WHERE locktype = ''resource queue'' AND granted) l1
LEFT JOIN %s.cat_pg_stat_activity a ON (l1.mppsessionid = a.sess_id)
LEFT JOIN %s.cat_pg_resqueue rq ON (l1.objid = rq.cat_oid)
LEFT JOIN %s.cat_pg_database db ON (l1.database = db.cat_oid)
ORDER BY rsqname, session_id'
                , cmetric, v_cluster_id, cmetric, cmetric, cmetric, cmetric, cmetric
        );
        EXECUTE sql;

        RETURN;
END;
$$ LANGUAGE 'plpgsql';

COMMENT ON FUNCTION public.load_rsq_queries(int, boolean) IS 'Snapshot current queries';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_rsq_queries', 'rsq_queries', 100, true, '', 1 );



CREATE TABLE templates.rsq_queries_waiting(
        hostname      text,
        period        timestamptz NOT NULL,
	lock_type     text,
	rsqname       text,
	db_name       text,
	pid           int,
	session_id    int,
	query_start   timestamptz
);

CREATE INDEX ON templates.rsq_queries_waiting(hostname, period);


CREATE OR REPLACE FUNCTION public.load_rsq_queries_waiting( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
DECLARE
        cmetric text;
        sql     text;
BEGIN
        cmetric := public.cluster_metrics_schema( v_cluster_id );

        sql := format('
INSERT INTO %s.rsq_queries_waiting (hostname, period, lock_type, rsqname, db_name, pid, session_id, query_start)
SELECT (SELECT hostname FROM public.cluster_hosts WHERE cluster_id = %s AND is_mdw) AS hostname,
       now() AS period,
       l1.locktype AS lock_type,
       rq.rsqname,
       db.datname AS db_name,
       l1.pid,
       l1.mppsessionid AS session_id,
       a.query_start
FROM 
     (SELECT * FROM %s.cat_pg_locks WHERE locktype = ''resource queue'' AND not granted) l1
LEFT JOIN %s.cat_pg_stat_activity a ON (l1.mppsessionid = a.sess_id)
LEFT JOIN %s.cat_pg_resqueue rq ON (l1.objid = rq.cat_oid)
LEFT JOIN %s.cat_pg_database db ON (l1.database = db.cat_oid)
ORDER BY rsqname, session_id'
                , cmetric, v_cluster_id, cmetric, cmetric, cmetric, cmetric
        );
        EXECUTE sql;

        RETURN;
END;
$$ LANGUAGE 'plpgsql';

COMMENT ON FUNCTION public.load_rsq_queries_waiting(int, boolean) IS 'Snapshot current queries waiting in a resource queue';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_rsq_queries_waiting', 'rsq_queries_waiting', 100, true, '', 1 );



CREATE TABLE templates.lock_transaction_information(
        hostname             text,
        period               timestamptz NOT NULL,
	db_name              text,
	gp_segment_id        int,
	wait_lock_type       text,
	wait_transaction_id  xid,
	wait_pid             int,
	wait_mode            text,
	wait_session_id      int,
	lock_session_id      int,
	lock_mode            text
);

CREATE INDEX ON templates.lock_transaction_information(hostname, period);


CREATE OR REPLACE FUNCTION public.load_lock_transaction_information( v_cluster_id int, v_prime boolean )
RETURNS VOID AS $$
DECLARE
        cmetric text;
        sql     text;
BEGIN
        cmetric := public.cluster_metrics_schema( v_cluster_id );

        sql := format('
INSERT INTO %s.lock_transaction_information (hostname, period, gp_segment_id, wait_lock_type, wait_transaction_id, db_name, wait_pid, wait_mode, wait_session_id, lock_session_id, lock_mode)
SELECT (SELECT hostname FROM public.cluster_hosts WHERE cluster_id = %s AND is_mdw) AS hostname,
       now() AS period,
       l1.gp_segment_id AS segment_id,
       l1.locktype,
       l1.transactionid AS transaction_id,
       db.datname AS "database",
       l1.pid AS w_pid,
       l1.mode AS w_mode,
       l1.mppsessionid AS w_session, -- waiting session
       l2.mppsessionid AS b_session, -- blocking session
       l2.mode AS b_mode
FROM (SELECT * FROM %s.cat_pg_locks WHERE locktype = ''transactionid'') l1
LEFT JOIN %s.cat_pg_locks l2 ON (l1.transactionid = l2.transactionid
                          AND l1.gp_segment_id = l2.gp_segment_id
                          AND l1.granted
                          AND NOT l2.granted)
LEFT JOIN %s.cat_pg_database db ON (l1.database = db.cat_oid)
LEFT JOIN %s.cat_pg_stat_activity act1 ON (l1.mppsessionid = act1.sess_id)
LEFT JOIN %s.cat_pg_stat_activity act2 ON (l2.mppsessionid = act2.sess_id)
WHERE l2.granted
ORDER BY 1'
                , cmetric, v_cluster_id, cmetric, cmetric, cmetric, cmetric, cmetric
        );
        EXECUTE sql;

        RETURN;
END;
$$ LANGUAGE 'plpgsql';

COMMENT ON FUNCTION public.load_lock_transaction_information(int, boolean) IS 'Snapshot of transaction locks';

INSERT INTO public.load_functions (funcname,tablename,priority,enabled,fdwtable,frequency)
VALUES ( 'public.load_lock_transaction_information', 'lock_transaction_information', 100, true, '', 1 );


COMMIT;
