BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1025, 'allow for finding core dump files' );

CREATE EXTERNAL WEB TABLE cbmon.__segment_cores(
        hostname text,
        path     text,
        process  text,
        signal   int,
        uid      int,
        gid      int,
        pid      int,
        ts       bigint
) EXECUTE '/usr/local/cbmon/bin/find-cores' ON HOST
  FORMAT 'CSV' ( DELIMITER ',' );

CREATE EXTERNAL WEB TABLE cbmon.__master_cores(
        hostname text,
        path     text,
        process  text,
        signal   int,
        uid      int,
        gid      int,
        pid      int,
        ts       bigint
) EXECUTE '/usr/local/cbmon/bin/find-cores' ON COORDINATOR
  FORMAT 'CSV' ( DELIMITER ',' );

CREATE VIEW cbmon._cluster_cores AS
SELECT * FROM cbmon.__segment_cores
UNION ALL
SELECT * FROM cbmon.__master_cores;

COMMIT;
