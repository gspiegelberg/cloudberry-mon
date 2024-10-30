BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1011, 'add better accessibility to coordinator log' );

/**
 * text-only types used b/c log can get corrupted
 * better to permit access and let SQL do the casting
 */

CREATE READABLE EXTERNAL WEB TABLE cbmon.__coordinator_log_24hrs(
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
) EXECUTE '/usr/local/cbmon/bin/log_reader -H 24' ON MASTER
  FORMAT 'CSV' (DELIMITER ','
                NULL '' 
                ESCAPE '"' 
                QUOTE '"' 
                FILL MISSING FIELDS);

CREATE READABLE EXTERNAL WEB TABLE cbmon.__coordinator_log_7days(
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
) EXECUTE '/usr/local/cbmon/bin/log_reader -H 168' ON MASTER
  FORMAT 'CSV' (DELIMITER ','
                NULL '' 
                ESCAPE '"' 
                QUOTE '"' 
                FILL MISSING FIELDS);

CREATE READABLE EXTERNAL WEB TABLE cbmon.__coordinator_log_1month(
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
) EXECUTE '/usr/local/cbmon/bin/log_reader -H 720' ON MASTER
  FORMAT 'CSV' (DELIMITER ','
                NULL '' 
                ESCAPE '"' 
                QUOTE '"' 
                FILL MISSING FIELDS);

CREATE READABLE EXTERNAL WEB TABLE cbmon.__coordinator_log_all(
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
) EXECUTE '/usr/local/cbmon/bin/log_reader -H 0' ON MASTER
  FORMAT 'CSV' (DELIMITER ','
                NULL '' 
                ESCAPE '"' 
                QUOTE '"' 
                FILL MISSING FIELDS);


COMMIT;

