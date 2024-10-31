BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1012, 'added for quicker response' );

CREATE READABLE EXTERNAL WEB TABLE cbmon.__coordinator_log_1hr(
        logtime         text,
        loguser         text,
        logdatabase     text,
        logpid          text,
        logthread       text,
        loghost         text,
        logport         text,
        logsessiontime  text,
        logtransaction  text,
        logsession      text,
        logcmdcount     text,
        logsegment      text,
        logslice        text,
        logdistxact     text,
        loglocalxact    text,
        logsubxact      text,
        logseverity     text,
        logstate        text,
        logmessage      text,
        logdetail       text,
        loghint         text,
        logquery        text,
        logquerypos     text,
        logcontext      text,
        logdebug        text,
        logcursorpos    text,
        logfunction     text,
        logfile         text,
        logline         text,
        logstack        text
) EXECUTE '/usr/local/cbmon/bin/log_reader -H 1' ON MASTER
  FORMAT 'CSV' (DELIMITER ','
                NULL ''
                ESCAPE '"'
                QUOTE '"'
                FILL MISSING FIELDS);

COMMIT;
