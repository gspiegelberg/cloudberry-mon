/**
 * 1. Update /usr/local/cbmon on all hosts
 * 2. Execute this alter on all Cloudberry clusters before
 *    alters/postgresql/alter-1042.sql
 * 3. Execute alters/postgresql/alter-1042.sql on PostgreSQL
 *    cbmon database
 */
BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1016, 'report database uptime');

CREATE EXTERNAL WEB TABLE cbmon.dbuptime (
    uptime timestamp without time zone
) EXECUTE 'stat -c %y $MASTER_DATA_DIRECTORY/postmaster.pid | awk ''{printf("%s %s",$1,$2)}''' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

COMMIT;
