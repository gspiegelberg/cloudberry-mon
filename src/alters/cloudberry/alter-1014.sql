BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1014, 'query stats from segment logs' );

DO $$
DECLARE
	val text;
BEGIN
	SELECT INTO val setting
	  FROM pg_settings
	 WHERE name = 'log_statement_stats';

	IF val <> 'on' THEN
		RAISE NOTICE 'Configuration check FAILED';
		RAISE NOTICE 'log_statement_stats MUST be set to ''on'' for this alter to have an effect';
		RAISE NOTICE '1. gpconfig -c log_statement_stats -v ''on''';
		RAISE NOTICE '2. gpstop -u';
	ELSE
		RAISE NOTICE 'Configuration check passed';
	END IF;
END $$;

CREATE READABLE EXTERNAL WEB TABLE cbmon.__query_stats_1hr(
        segment_id      int,
        logtime         text,
        loguser         text,
        logdatabase     text,
        logpid          text,
        logthread       text,
        logport         text,
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
	ru_utime        float,   -- see src/backend/tcop/postgres.c ShowUsage()
	ru_stime        float,   -- see also getrusage(2)
	elapse_t        float,
	tot_user_t      float,
	tot_sys_t       float,
        ru_maxrss_kb    int,
	ru_inblock      int,
	ru_outblock     int,
	raw_ru_inblock  int,
	raw_ru_outblock int,
	ru_majflt       int,
	ru_minflt       int,
	raw_ru_majflt   int,
	raw_ru_minflt   int,
	ru_nswap        int,
	raw_ru_nswap    int,
	ru_nsignals     int,
	raw_ru_nsignals int,
	ru_msgrvc       int,
	ru_msgsnd       int,
	raw_ru_msgrvc   int,
	raw_ru_msgsnd   int,
        ru_nvcsw        int,
	rn_nivcsw       int,
        raw_ru_nvcsw    int,
	raw_rn_nivcsw   int
) EXECUTE '/usr/local/cbmon/bin/segment_query_stats -H 1' ON ALL -- primary segment instances
  FORMAT 'CSV' (DELIMITER ','
                NULL ''
                ESCAPE '"'
                QUOTE '"'
                FILL MISSING FIELDS);


CREATE READABLE EXTERNAL WEB TABLE cbmon.__query_stats_24hrs(
        segment_id      int,
        logtime         text,
        loguser         text,
        logdatabase     text,
        logpid          text,
        logthread       text,
        logport         text,
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
	ru_utime        float,   -- see src/backend/tcop/postgres.c ShowUsage()
	ru_stime        float,   -- see also getrusage(2)
	elapse_t        float,
	tot_user_t      float,
	tot_sys_t       float,
        ru_maxrss_kb    int,
	ru_inblock      int,
	ru_outblock     int,
	raw_ru_inblock  int,
	raw_ru_outblock int,
	ru_majflt       int,
	ru_minflt       int,
	raw_ru_majflt   int,
	raw_ru_minflt   int,
	ru_nswap        int,
	raw_ru_nswap    int,
	ru_nsignals     int,
	raw_ru_nsignals int,
	ru_msgrvc       int,
	ru_msgsnd       int,
	raw_ru_msgrvc   int,
	raw_ru_msgsnd   int,
        ru_nvcsw        int,
	rn_nivcsw       int,
        raw_ru_nvcsw    int,
	raw_rn_nivcsw   int
) EXECUTE '/usr/local/cbmon/bin/segment_query_stats -H 24' ON ALL -- primary segment instances
  FORMAT 'CSV' (DELIMITER ','
                NULL ''
                ESCAPE '"'
                QUOTE '"'
                FILL MISSING FIELDS);


/**
 * Here to backfill when first deployed. Should not be left exposed.
 * Est 8500 secs execution for every 1M qualifying log entries
 * Depends on log size, noise, and existing performance of cluster
 */
CREATE READABLE EXTERNAL WEB TABLE cbmon.__query_stats_7days(
        segment_id      int,
        logtime         text,
        loguser         text,
        logdatabase     text,
        logpid          text,
        logthread       text,
        logport         text,
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
	ru_utime        float,   -- see src/backend/tcop/postgres.c ShowUsage()
	ru_stime        float,   -- see also getrusage(2)
	elapse_t        float,
	tot_user_t      float,
	tot_sys_t       float,
        ru_maxrss_kb    int,
	ru_inblock      int,
	ru_outblock     int,
	raw_ru_inblock  int,
	raw_ru_outblock int,
	ru_majflt       int,
	ru_minflt       int,
	raw_ru_majflt   int,
	raw_ru_minflt   int,
	ru_nswap        int,
	raw_ru_nswap    int,
	ru_nsignals     int,
	raw_ru_nsignals int,
	ru_msgrvc       int,
	ru_msgsnd       int,
	raw_ru_msgrvc   int,
	raw_ru_msgsnd   int,
        ru_nvcsw        int,
	rn_nivcsw       int,
        raw_ru_nvcsw    int,
	raw_rn_nivcsw   int
) EXECUTE '/usr/local/cbmon/bin/segment_query_stats -H 168' ON ALL -- primary segment instances
  FORMAT 'CSV' (DELIMITER ','
                NULL ''
                ESCAPE '"'
                QUOTE '"'
                FILL MISSING FIELDS);


COMMIT;
