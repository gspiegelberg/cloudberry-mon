--
-- Cloudberry Schema
--

CREATE SCHEMA cbmon;

ALTER SCHEMA cbmon OWNER TO gpadmin;

--
-- Name: create_catalog_views(boolean); Type: FUNCTION; Schema: cbmon; Owner: gpadmin
--

CREATE FUNCTION cbmon.create_catalog_views(v_replace boolean) RETURNS integer
    LANGUAGE plpgsql NO SQL
    AS $$
DECLARE
	rec     record;
	vname   text;
	oidtxt  text;
	created int;
BEGIN
	created := 0;
	FOR rec IN SELECT * FROM cbmon.catalog_views
	LOOP
		vname := 'cat_' || rec.tablename;

		PERFORM * FROM pg_views
		  WHERE schemaname = 'cbmon'
		    AND viewname = vname;
		IF FOUND THEN
			IF NOT v_replace THEN
				CONTINUE;
			END IF;
			EXECUTE format('DROP VIEW cbmon.%s', vname);
		END IF;

		/**
		 * Column oid exists on remote host using FDW.
		 * If oid is needed in remote query, oid is reserved
		 * therefore to expose it must have a different name.
		 */
		IF rec.include_oid THEN
			oidtxt := 'oid AS cat_oid,';
		ELSE
			oidtxt := '';
		END IF;

		EXECUTE format(
			'CREATE VIEW cbmon.%s AS SELECT %s * FROM %s.%s',
			vname, oidtxt, rec.schemaname, rec.tablename
		);
		created := created + 1;
	END LOOP;

	RETURN created;
END;
$$;


ALTER FUNCTION cbmon.create_catalog_views(v_replace boolean) OWNER TO gpadmin;

--
-- Name: matview_maintenance(); Type: FUNCTION; Schema: cbmon; Owner: gpadmin
--

CREATE FUNCTION cbmon.matview_maintenance() RETURNS boolean
    LANGUAGE plpgsql NO SQL
    AS $$
DECLARE
	moy     int;
	rec     record;
	sql     text;
BEGIN
	moy := cbmon.minute_of_year();

	FOR rec IN
		SELECT * FROM cbmon.matviews
		 WHERE moy % frequency = 0
	LOOP
		sql := format(
			'REFRESH MATERIALIZED VIEW cbmon.%s WITH DATA',
			rec.mvname
		);
		EXECUTE sql;
	END LOOP;

	RETURN true;
END;
$$;


ALTER FUNCTION cbmon.matview_maintenance() OWNER TO gpadmin;

--
-- Name: minute_of_year(); Type: FUNCTION; Schema: cbmon; Owner: gpadmin
--

CREATE FUNCTION cbmon.minute_of_year() RETURNS integer
    LANGUAGE sql STABLE CONTAINS SQL
    AS $$
SELECT extract(epoch from
	(now()::timestamp -
	 date_trunc('year', now())::timestamp))::int / 60;
$$;


ALTER FUNCTION cbmon.minute_of_year() OWNER TO gpadmin;

--
-- Name: minutes_in_year(); Type: FUNCTION; Schema: cbmon; Owner: gpadmin
--

CREATE FUNCTION cbmon.minutes_in_year() RETURNS integer
    LANGUAGE sql STABLE CONTAINS SQL
    AS $$
SELECT extract(epoch from
	(date_trunc('year', now())::timestamp + interval'1 year') -
	(date_trunc('year',now())::timestamp))::int / 60;
$$;


ALTER FUNCTION cbmon.minutes_in_year() OWNER TO gpadmin;

SET default_tablespace = '';

--
-- Name: __coordinator_log_1hr; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__coordinator_log_1hr (
    logtime text,
    loguser text,
    logdatabase text,
    logpid text,
    logthread text,
    loghost text,
    logport text,
    logsessiontime text,
    logtransaction text,
    logsession text,
    logcmdcount text,
    logsegment text,
    logslice text,
    logdistxact text,
    loglocalxact text,
    logsubxact text,
    logseverity text,
    logstate text,
    logmessage text,
    logdetail text,
    loghint text,
    logquery text,
    logquerypos text,
    logcontext text,
    logdebug text,
    logcursorpos text,
    logfunction text,
    logfile text,
    logline text,
    logstack text
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/log_reader -H 1',
    delimiter ',',
    encoding '6',
    escape '"',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'csv',
    format_type 'c',
    is_writable 'false',
    log_errors 'f',
    "null" '',
    quote '"'
);


ALTER FOREIGN TABLE cbmon.__coordinator_log_1hr OWNER TO gpadmin;

--
-- Name: __coordinator_log_1month; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__coordinator_log_1month (
    logtime text,
    loguser text,
    logdatabase text,
    logpid text,
    logthread text,
    loghost text,
    logport text,
    logsessiontime text,
    logtransaction text,
    logsession text,
    logcmdcount text,
    logsegment text,
    logslice text,
    logdistxact text,
    loglocalxact text,
    logsubxact text,
    logseverity text,
    logstate text,
    logmessage text,
    logdetail text,
    loghint text,
    logquery text,
    logquerypos text,
    logcontext text,
    logdebug text,
    logcursorpos text,
    logfunction text,
    logfile text,
    logline text,
    logstack text
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/log_reader -H 720',
    delimiter ',',
    encoding '6',
    escape '"',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'csv',
    format_type 'c',
    is_writable 'false',
    log_errors 'f',
    "null" '',
    quote '"'
);


ALTER FOREIGN TABLE cbmon.__coordinator_log_1month OWNER TO gpadmin;

--
-- Name: __coordinator_log_24hrs; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__coordinator_log_24hrs (
    logtime text,
    loguser text,
    logdatabase text,
    logpid text,
    logthread text,
    loghost text,
    logport text,
    logsessiontime text,
    logtransaction text,
    logsession text,
    logcmdcount text,
    logsegment text,
    logslice text,
    logdistxact text,
    loglocalxact text,
    logsubxact text,
    logseverity text,
    logstate text,
    logmessage text,
    logdetail text,
    loghint text,
    logquery text,
    logquerypos text,
    logcontext text,
    logdebug text,
    logcursorpos text,
    logfunction text,
    logfile text,
    logline text,
    logstack text
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/log_reader -H 24',
    delimiter ',',
    encoding '6',
    escape '"',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'csv',
    format_type 'c',
    is_writable 'false',
    log_errors 'f',
    "null" '',
    quote '"'
);


ALTER FOREIGN TABLE cbmon.__coordinator_log_24hrs OWNER TO gpadmin;

--
-- Name: __coordinator_log_7days; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__coordinator_log_7days (
    logtime text,
    loguser text,
    logdatabase text,
    logpid text,
    logthread text,
    loghost text,
    logport text,
    logsessiontime text,
    logtransaction text,
    logsession text,
    logcmdcount text,
    logsegment text,
    logslice text,
    logdistxact text,
    loglocalxact text,
    logsubxact text,
    logseverity text,
    logstate text,
    logmessage text,
    logdetail text,
    loghint text,
    logquery text,
    logquerypos text,
    logcontext text,
    logdebug text,
    logcursorpos text,
    logfunction text,
    logfile text,
    logline text,
    logstack text
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/log_reader -H 168',
    delimiter ',',
    encoding '6',
    escape '"',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'csv',
    format_type 'c',
    is_writable 'false',
    log_errors 'f',
    "null" '',
    quote '"'
);


ALTER FOREIGN TABLE cbmon.__coordinator_log_7days OWNER TO gpadmin;

--
-- Name: __coordinator_log_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__coordinator_log_all (
    logtime text,
    loguser text,
    logdatabase text,
    logpid text,
    logthread text,
    loghost text,
    logport text,
    logsessiontime text,
    logtransaction text,
    logsession text,
    logcmdcount text,
    logsegment text,
    logslice text,
    logdistxact text,
    loglocalxact text,
    logsubxact text,
    logseverity text,
    logstate text,
    logmessage text,
    logdetail text,
    loghint text,
    logquery text,
    logquerypos text,
    logcontext text,
    logdebug text,
    logcursorpos text,
    logfunction text,
    logfile text,
    logline text,
    logstack text
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/log_reader -H 0',
    delimiter ',',
    encoding '6',
    escape '"',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'csv',
    format_type 'c',
    is_writable 'false',
    log_errors 'f',
    "null" '',
    quote '"'
);


ALTER FOREIGN TABLE cbmon.__coordinator_log_all OWNER TO gpadmin;

--
-- Name: __cpu_master_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__cpu_master_all (
    hostname text,
    period timestamp with time zone,
    cpu character varying(4),
    usr double precision,
    nice double precision,
    sys double precision,
    iowait double precision,
    steal double precision,
    irq double precision,
    soft double precision,
    guest double precision,
    gnice double precision,
    idle double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-P ALL -u ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__cpu_master_all OWNER TO gpadmin;

--
-- Name: __cpu_master_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__cpu_master_today (
    hostname text,
    period timestamp with time zone,
    cpu character varying(4),
    usr double precision,
    nice double precision,
    sys double precision,
    iowait double precision,
    steal double precision,
    irq double precision,
    soft double precision,
    guest double precision,
    gnice double precision,
    idle double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-P ALL -u ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__cpu_master_today OWNER TO gpadmin;

--
-- Name: __cpu_master_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__cpu_master_yesterday (
    hostname text,
    period timestamp with time zone,
    cpu character varying(4),
    usr double precision,
    nice double precision,
    sys double precision,
    iowait double precision,
    steal double precision,
    irq double precision,
    soft double precision,
    guest double precision,
    gnice double precision,
    idle double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-P ALL -u ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__cpu_master_yesterday OWNER TO gpadmin;

--
-- Name: __cpu_segments_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__cpu_segments_all (
    hostname text,
    period timestamp with time zone,
    cpu character varying(4),
    usr double precision,
    nice double precision,
    sys double precision,
    iowait double precision,
    steal double precision,
    irq double precision,
    soft double precision,
    guest double precision,
    gnice double precision,
    idle double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-P ALL -u ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__cpu_segments_all OWNER TO gpadmin;

--
-- Name: __cpu_segments_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__cpu_segments_today (
    hostname text,
    period timestamp with time zone,
    cpu character varying(4),
    usr double precision,
    nice double precision,
    sys double precision,
    iowait double precision,
    steal double precision,
    irq double precision,
    soft double precision,
    guest double precision,
    gnice double precision,
    idle double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-P ALL -u ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__cpu_segments_today OWNER TO gpadmin;

--
-- Name: __cpu_segments_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__cpu_segments_yesterday (
    hostname text,
    period timestamp with time zone,
    cpu character varying(4),
    usr double precision,
    nice double precision,
    sys double precision,
    iowait double precision,
    steal double precision,
    irq double precision,
    soft double precision,
    guest double precision,
    gnice double precision,
    idle double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-P ALL -u ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__cpu_segments_yesterday OWNER TO gpadmin;

--
-- Name: __disk_master_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__disk_master_all (
    hostname text,
    period timestamp with time zone,
    device text,
    tps double precision,
    rkbs double precision,
    wkbs double precision,
    areq_sz double precision,
    aqu_sz double precision,
    await double precision,
    svctm double precision,
    util_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-d"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__disk_master_all OWNER TO gpadmin;

--
-- Name: __disk_master_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__disk_master_today (
    hostname text,
    period timestamp with time zone,
    device text,
    tps double precision,
    rkbs double precision,
    wkbs double precision,
    areq_sz double precision,
    aqu_sz double precision,
    await double precision,
    svctm double precision,
    util_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-d"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__disk_master_today OWNER TO gpadmin;

--
-- Name: __disk_master_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__disk_master_yesterday (
    hostname text,
    period timestamp with time zone,
    device text,
    tps double precision,
    rkbs double precision,
    wkbs double precision,
    areq_sz double precision,
    aqu_sz double precision,
    await double precision,
    svctm double precision,
    util_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-d"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__disk_master_yesterday OWNER TO gpadmin;

--
-- Name: __disk_segments_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__disk_segments_all (
    hostname text,
    period timestamp with time zone,
    device text,
    tps double precision,
    rkbs double precision,
    wkbs double precision,
    areq_sz double precision,
    aqu_sz double precision,
    await double precision,
    svctm double precision,
    util_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-d"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__disk_segments_all OWNER TO gpadmin;

--
-- Name: __disk_segments_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__disk_segments_today (
    hostname text,
    period timestamp with time zone,
    device text,
    tps double precision,
    rkbs double precision,
    wkbs double precision,
    areq_sz double precision,
    aqu_sz double precision,
    await double precision,
    svctm double precision,
    util_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-d"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__disk_segments_today OWNER TO gpadmin;

--
-- Name: __disk_segments_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__disk_segments_yesterday (
    hostname text,
    period timestamp with time zone,
    device text,
    tps double precision,
    rkbs double precision,
    wkbs double precision,
    areq_sz double precision,
    aqu_sz double precision,
    await double precision,
    svctm double precision,
    util_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-d"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__disk_segments_yesterday OWNER TO gpadmin;

--
-- Name: __disk_space_master; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__disk_space_master (
    hostname text,
    mntpt character varying(256),
    total_kbs bigint,
    used_kbs bigint,
    avail_kbs bigint
)
SERVER gp_exttable_server
OPTIONS (
    command E'df -k $GP_SEG_DATADIR | awk -v hn=$(hostname) ''/Filesystem/ {next} {printf("%s,%s,%s,%s,%s\\n",hn,$1,$2,$3,$4)}''',
    delimiter ',',
    encoding '6',
    escape '"',
    execute_on 'COORDINATOR_ONLY',
    format 'csv',
    format_type 'c',
    is_writable 'false',
    log_errors 'f',
    "null" '',
    quote '"'
);


ALTER FOREIGN TABLE cbmon.__disk_space_master OWNER TO gpadmin;

--
-- Name: __disk_space_segments; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__disk_space_segments (
    hostname text,
    mntpt character varying(256),
    total_kbs bigint,
    used_kbs bigint,
    avail_kbs bigint
)
SERVER gp_exttable_server
OPTIONS (
    command E'df -k $GP_SEG_DATADIR | awk -v hn=$(hostname) ''/Filesystem/ {next} {printf("%s,%s,%s,%s,%s\\n",hn,$1,$2,$3,$4)}''',
    delimiter ',',
    encoding '6',
    escape '"',
    execute_on 'ALL_SEGMENTS',
    format 'csv',
    format_type 'c',
    is_writable 'false',
    log_errors 'f',
    "null" '',
    quote '"'
);


ALTER FOREIGN TABLE cbmon.__disk_space_segments OWNER TO gpadmin;

--
-- Name: __ldavg_master_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__ldavg_master_all (
    hostname text,
    period timestamp with time zone,
    runq_sz double precision,
    plist_sz double precision,
    ldavg_1 double precision,
    ldavg_5 double precision,
    ldavg_15 double precision,
    blocked double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-q"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__ldavg_master_all OWNER TO gpadmin;

--
-- Name: __ldavg_master_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__ldavg_master_today (
    hostname text,
    period timestamp with time zone,
    runq_sz double precision,
    plist_sz double precision,
    ldavg_1 double precision,
    ldavg_5 double precision,
    ldavg_15 double precision,
    blocked double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-q"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__ldavg_master_today OWNER TO gpadmin;

--
-- Name: __ldavg_master_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__ldavg_master_yesterday (
    hostname text,
    period timestamp with time zone,
    runq_sz double precision,
    plist_sz double precision,
    ldavg_1 double precision,
    ldavg_5 double precision,
    ldavg_15 double precision,
    blocked double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-q"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__ldavg_master_yesterday OWNER TO gpadmin;

--
-- Name: __ldavg_segments_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__ldavg_segments_all (
    hostname text,
    period timestamp with time zone,
    runq_sz double precision,
    plist_sz double precision,
    ldavg_1 double precision,
    ldavg_5 double precision,
    ldavg_15 double precision,
    blocked double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-q"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__ldavg_segments_all OWNER TO gpadmin;

--
-- Name: __ldavg_segments_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__ldavg_segments_today (
    hostname text,
    period timestamp with time zone,
    runq_sz double precision,
    plist_sz double precision,
    ldavg_1 double precision,
    ldavg_5 double precision,
    ldavg_15 double precision,
    blocked double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-q"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__ldavg_segments_today OWNER TO gpadmin;

--
-- Name: __ldavg_segments_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__ldavg_segments_yesterday (
    hostname text,
    period timestamp with time zone,
    runq_sz double precision,
    plist_sz double precision,
    ldavg_1 double precision,
    ldavg_5 double precision,
    ldavg_15 double precision,
    blocked double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-q"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__ldavg_segments_yesterday OWNER TO gpadmin;

--
-- Name: __memory_master_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__memory_master_all (
    hostname text,
    period timestamp with time zone,
    kbmemfree integer,
    kbavail integer,
    kbmemused integer,
    memused_pct double precision,
    kbbuffers integer,
    kbcached integer,
    kbcommit integer,
    commit_pct double precision,
    kbactive integer,
    kbinact integer,
    kbdirty integer,
    kbanonpg integer,
    kbslab integer,
    kbkstack integer,
    kbpgtbl integer,
    kbvmused integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-r ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__memory_master_all OWNER TO gpadmin;

--
-- Name: __memory_master_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__memory_master_today (
    hostname text,
    period timestamp with time zone,
    kbmemfree integer,
    kbavail integer,
    kbmemused integer,
    memused_pct double precision,
    kbbuffers integer,
    kbcached integer,
    kbcommit integer,
    commit_pct double precision,
    kbactive integer,
    kbinact integer,
    kbdirty integer,
    kbanonpg integer,
    kbslab integer,
    kbkstack integer,
    kbpgtbl integer,
    kbvmused integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-r ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__memory_master_today OWNER TO gpadmin;

--
-- Name: __memory_master_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__memory_master_yesterday (
    hostname text,
    period timestamp with time zone,
    kbmemfree integer,
    kbavail integer,
    kbmemused integer,
    memused_pct double precision,
    kbbuffers integer,
    kbcached integer,
    kbcommit integer,
    commit_pct double precision,
    kbactive integer,
    kbinact integer,
    kbdirty integer,
    kbanonpg integer,
    kbslab integer,
    kbkstack integer,
    kbpgtbl integer,
    kbvmused integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-r ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__memory_master_yesterday OWNER TO gpadmin;

--
-- Name: __memory_segments_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__memory_segments_all (
    hostname text,
    period timestamp with time zone,
    kbmemfree integer,
    kbavail integer,
    kbmemused integer,
    memused_pct double precision,
    kbbuffers integer,
    kbcached integer,
    kbcommit integer,
    commit_pct double precision,
    kbactive integer,
    kbinact integer,
    kbdirty integer,
    kbanonpg integer,
    kbslab integer,
    kbkstack integer,
    kbpgtbl integer,
    kbvmused integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-r ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__memory_segments_all OWNER TO gpadmin;

--
-- Name: __memory_segments_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__memory_segments_today (
    hostname text,
    period timestamp with time zone,
    kbmemfree integer,
    kbavail integer,
    kbmemused integer,
    memused_pct double precision,
    kbbuffers integer,
    kbcached integer,
    kbcommit integer,
    commit_pct double precision,
    kbactive integer,
    kbinact integer,
    kbdirty integer,
    kbanonpg integer,
    kbslab integer,
    kbkstack integer,
    kbpgtbl integer,
    kbvmused integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-r ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__memory_segments_today OWNER TO gpadmin;

--
-- Name: __memory_segments_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__memory_segments_yesterday (
    hostname text,
    period timestamp with time zone,
    kbmemfree integer,
    kbavail integer,
    kbmemused integer,
    memused_pct double precision,
    kbbuffers integer,
    kbcached integer,
    kbcommit integer,
    commit_pct double precision,
    kbactive integer,
    kbinact integer,
    kbdirty integer,
    kbanonpg integer,
    kbslab integer,
    kbkstack integer,
    kbpgtbl integer,
    kbvmused integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-r ALL"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__memory_segments_yesterday OWNER TO gpadmin;

--
-- Name: __network_dev_master_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_dev_master_all (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxpck_psec double precision,
    txpck_psec double precision,
    rxkb_psec double precision,
    txkb_psec double precision,
    rxcmp_psec double precision,
    txcmp_psec double precision,
    rxmcst_psec double precision,
    ifutil_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-n DEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_dev_master_all OWNER TO gpadmin;

--
-- Name: __network_dev_master_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_dev_master_today (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxpck_psec double precision,
    txpck_psec double precision,
    rxkb_psec double precision,
    txkb_psec double precision,
    rxcmp_psec double precision,
    txcmp_psec double precision,
    rxmcst_psec double precision,
    ifutil_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-n DEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_dev_master_today OWNER TO gpadmin;

--
-- Name: __network_dev_master_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_dev_master_yesterday (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxpck_psec double precision,
    txpck_psec double precision,
    rxkb_psec double precision,
    txkb_psec double precision,
    rxcmp_psec double precision,
    txcmp_psec double precision,
    rxmcst_psec double precision,
    ifutil_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-n DEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_dev_master_yesterday OWNER TO gpadmin;

--
-- Name: __network_dev_segments_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_dev_segments_all (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxpck_psec double precision,
    txpck_psec double precision,
    rxkb_psec double precision,
    txkb_psec double precision,
    rxcmp_psec double precision,
    txcmp_psec double precision,
    rxmcst_psec double precision,
    ifutil_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-n DEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_dev_segments_all OWNER TO gpadmin;

--
-- Name: __network_dev_segments_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_dev_segments_today (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxpck_psec double precision,
    txpck_psec double precision,
    rxkb_psec double precision,
    txkb_psec double precision,
    rxcmp_psec double precision,
    txcmp_psec double precision,
    rxmcst_psec double precision,
    ifutil_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-n DEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_dev_segments_today OWNER TO gpadmin;

--
-- Name: __network_dev_segments_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_dev_segments_yesterday (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxpck_psec double precision,
    txpck_psec double precision,
    rxkb_psec double precision,
    txkb_psec double precision,
    rxcmp_psec double precision,
    txcmp_psec double precision,
    rxmcst_psec double precision,
    ifutil_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-n DEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_dev_segments_yesterday OWNER TO gpadmin;

--
-- Name: __network_errors_master_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_errors_master_all (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxerr_psec double precision,
    txerr_psec double precision,
    coll_psec double precision,
    rxdrop_psec double precision,
    txdrop_psec double precision,
    txcarr_psec double precision,
    rxfram_psec double precision,
    rxfifo_psec double precision,
    txfifo_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-n EDEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_errors_master_all OWNER TO gpadmin;

--
-- Name: __network_errors_master_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_errors_master_today (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxerr_psec double precision,
    txerr_psec double precision,
    coll_psec double precision,
    rxdrop_psec double precision,
    txdrop_psec double precision,
    txcarr_psec double precision,
    rxfram_psec double precision,
    rxfifo_psec double precision,
    txfifo_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-n EDEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_errors_master_today OWNER TO gpadmin;

--
-- Name: __network_errors_master_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_errors_master_yesterday (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxerr_psec double precision,
    txerr_psec double precision,
    coll_psec double precision,
    rxdrop_psec double precision,
    txdrop_psec double precision,
    txcarr_psec double precision,
    rxfram_psec double precision,
    rxfifo_psec double precision,
    txfifo_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-n EDEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_errors_master_yesterday OWNER TO gpadmin;

--
-- Name: __network_errors_segments_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_errors_segments_all (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxerr_psec double precision,
    txerr_psec double precision,
    coll_psec double precision,
    rxdrop_psec double precision,
    txdrop_psec double precision,
    txcarr_psec double precision,
    rxfram_psec double precision,
    rxfifo_psec double precision,
    txfifo_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-n EDEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_errors_segments_all OWNER TO gpadmin;

--
-- Name: __network_errors_segments_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_errors_segments_today (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxerr_psec double precision,
    txerr_psec double precision,
    coll_psec double precision,
    rxdrop_psec double precision,
    txdrop_psec double precision,
    txcarr_psec double precision,
    rxfram_psec double precision,
    rxfifo_psec double precision,
    txfifo_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-n EDEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_errors_segments_today OWNER TO gpadmin;

--
-- Name: __network_errors_segments_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_errors_segments_yesterday (
    hostname text,
    period timestamp with time zone,
    iface text,
    rxerr_psec double precision,
    txerr_psec double precision,
    coll_psec double precision,
    rxdrop_psec double precision,
    txdrop_psec double precision,
    txcarr_psec double precision,
    rxfram_psec double precision,
    rxfifo_psec double precision,
    txfifo_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-n EDEV"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_errors_segments_yesterday OWNER TO gpadmin;

--
-- Name: __network_sockets_master_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_sockets_master_all (
    hostname text,
    period timestamp with time zone,
    totsck integer,
    tcpsck integer,
    udpsck integer,
    rawsck integer,
    ip_frag integer,
    tcp_tw integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-n SOCK"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_sockets_master_all OWNER TO gpadmin;

--
-- Name: __network_sockets_master_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_sockets_master_today (
    hostname text,
    period timestamp with time zone,
    totsck integer,
    tcpsck integer,
    udpsck integer,
    rawsck integer,
    ip_frag integer,
    tcp_tw integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-n SOCK"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_sockets_master_today OWNER TO gpadmin;

--
-- Name: __network_sockets_master_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_sockets_master_yesterday (
    hostname text,
    period timestamp with time zone,
    totsck integer,
    tcpsck integer,
    udpsck integer,
    rawsck integer,
    ip_frag integer,
    tcp_tw integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-n SOCK"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_sockets_master_yesterday OWNER TO gpadmin;

--
-- Name: __network_sockets_segments_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_sockets_segments_all (
    hostname text,
    period timestamp with time zone,
    totsck integer,
    tcpsck integer,
    udpsck integer,
    rawsck integer,
    ip_frag integer,
    tcp_tw integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-n SOCK"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_sockets_segments_all OWNER TO gpadmin;

--
-- Name: __network_sockets_segments_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_sockets_segments_today (
    hostname text,
    period timestamp with time zone,
    totsck integer,
    tcpsck integer,
    udpsck integer,
    rawsck integer,
    ip_frag integer,
    tcp_tw integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-n SOCK"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_sockets_segments_today OWNER TO gpadmin;

--
-- Name: __network_sockets_segments_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_sockets_segments_yesterday (
    hostname text,
    period timestamp with time zone,
    totsck integer,
    tcpsck integer,
    udpsck integer,
    rawsck integer,
    ip_frag integer,
    tcp_tw integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-n SOCK"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_sockets_segments_yesterday OWNER TO gpadmin;

--
-- Name: __network_softproc_master_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_softproc_master_all (
    hostname text,
    period timestamp with time zone,
    cpu text,
    total_psec double precision,
    dropd_psec double precision,
    squeezd_psec double precision,
    rx_rps_psec double precision,
    flw_lim_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-n SOFT"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_softproc_master_all OWNER TO gpadmin;

--
-- Name: __network_softproc_master_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_softproc_master_today (
    hostname text,
    period timestamp with time zone,
    cpu text,
    total_psec double precision,
    dropd_psec double precision,
    squeezd_psec double precision,
    rx_rps_psec double precision,
    flw_lim_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-n SOFT"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_softproc_master_today OWNER TO gpadmin;

--
-- Name: __network_softproc_master_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_softproc_master_yesterday (
    hostname text,
    period timestamp with time zone,
    cpu text,
    total_psec double precision,
    dropd_psec double precision,
    squeezd_psec double precision,
    rx_rps_psec double precision,
    flw_lim_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-n SOFT"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_softproc_master_yesterday OWNER TO gpadmin;

--
-- Name: __network_softproc_segments_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_softproc_segments_all (
    hostname text,
    period timestamp with time zone,
    cpu text,
    total_psec double precision,
    dropd_psec double precision,
    squeezd_psec double precision,
    rx_rps_psec double precision,
    flw_lim_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-n SOFT"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_softproc_segments_all OWNER TO gpadmin;

--
-- Name: __network_softproc_segments_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_softproc_segments_today (
    hostname text,
    period timestamp with time zone,
    cpu text,
    total_psec double precision,
    dropd_psec double precision,
    squeezd_psec double precision,
    rx_rps_psec double precision,
    flw_lim_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-n SOFT"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_softproc_segments_today OWNER TO gpadmin;

--
-- Name: __network_softproc_segments_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__network_softproc_segments_yesterday (
    hostname text,
    period timestamp with time zone,
    cpu text,
    total_psec double precision,
    dropd_psec double precision,
    squeezd_psec double precision,
    rx_rps_psec double precision,
    flw_lim_psec double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-n SOFT"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__network_softproc_segments_yesterday OWNER TO gpadmin;

--
-- Name: __query_stats_1hr; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__query_stats_1hr (
    segment_id integer,
    logtime text,
    loguser text,
    logdatabase text,
    logpid text,
    logthread text,
    logport text,
    logtransaction text,
    logsession text,
    logcmdcount text,
    logsegment text,
    logslice text,
    logdistxact text,
    loglocalxact text,
    logsubxact text,
    logseverity text,
    logstate text,
    ru_utime double precision,
    ru_stime double precision,
    elapse_t double precision,
    tot_user_t double precision,
    tot_sys_t double precision,
    ru_maxrss_kb integer,
    ru_inblock integer,
    ru_outblock integer,
    raw_ru_inblock integer,
    raw_ru_outblock integer,
    ru_majflt integer,
    ru_minflt integer,
    raw_ru_majflt integer,
    raw_ru_minflt integer,
    ru_nswap integer,
    raw_ru_nswap integer,
    ru_nsignals integer,
    raw_ru_nsignals integer,
    ru_msgrvc integer,
    ru_msgsnd integer,
    raw_ru_msgrvc integer,
    raw_ru_msgsnd integer,
    ru_nvcsw integer,
    rn_nivcsw integer,
    raw_ru_nvcsw integer,
    raw_rn_nivcsw integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/segment_query_stats -H 1',
    delimiter ',',
    encoding '6',
    escape '"',
    execute_on 'ALL_SEGMENTS',
    fill_missing_fields 'true',
    format 'csv',
    format_type 'c',
    is_writable 'false',
    log_errors 'f',
    "null" '',
    quote '"'
);


ALTER FOREIGN TABLE cbmon.__query_stats_1hr OWNER TO gpadmin;

--
-- Name: __query_stats_24hrs; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__query_stats_24hrs (
    segment_id integer,
    logtime text,
    loguser text,
    logdatabase text,
    logpid text,
    logthread text,
    logport text,
    logtransaction text,
    logsession text,
    logcmdcount text,
    logsegment text,
    logslice text,
    logdistxact text,
    loglocalxact text,
    logsubxact text,
    logseverity text,
    logstate text,
    ru_utime double precision,
    ru_stime double precision,
    elapse_t double precision,
    tot_user_t double precision,
    tot_sys_t double precision,
    ru_maxrss_kb integer,
    ru_inblock integer,
    ru_outblock integer,
    raw_ru_inblock integer,
    raw_ru_outblock integer,
    ru_majflt integer,
    ru_minflt integer,
    raw_ru_majflt integer,
    raw_ru_minflt integer,
    ru_nswap integer,
    raw_ru_nswap integer,
    ru_nsignals integer,
    raw_ru_nsignals integer,
    ru_msgrvc integer,
    ru_msgsnd integer,
    raw_ru_msgrvc integer,
    raw_ru_msgsnd integer,
    ru_nvcsw integer,
    rn_nivcsw integer,
    raw_ru_nvcsw integer,
    raw_rn_nivcsw integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/segment_query_stats -H 24',
    delimiter ',',
    encoding '6',
    escape '"',
    execute_on 'ALL_SEGMENTS',
    fill_missing_fields 'true',
    format 'csv',
    format_type 'c',
    is_writable 'false',
    log_errors 'f',
    "null" '',
    quote '"'
);


ALTER FOREIGN TABLE cbmon.__query_stats_24hrs OWNER TO gpadmin;

--
-- Name: __query_stats_7days; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__query_stats_7days (
    segment_id integer,
    logtime text,
    loguser text,
    logdatabase text,
    logpid text,
    logthread text,
    logport text,
    logtransaction text,
    logsession text,
    logcmdcount text,
    logsegment text,
    logslice text,
    logdistxact text,
    loglocalxact text,
    logsubxact text,
    logseverity text,
    logstate text,
    ru_utime double precision,
    ru_stime double precision,
    elapse_t double precision,
    tot_user_t double precision,
    tot_sys_t double precision,
    ru_maxrss_kb integer,
    ru_inblock integer,
    ru_outblock integer,
    raw_ru_inblock integer,
    raw_ru_outblock integer,
    ru_majflt integer,
    ru_minflt integer,
    raw_ru_majflt integer,
    raw_ru_minflt integer,
    ru_nswap integer,
    raw_ru_nswap integer,
    ru_nsignals integer,
    raw_ru_nsignals integer,
    ru_msgrvc integer,
    ru_msgsnd integer,
    raw_ru_msgrvc integer,
    raw_ru_msgsnd integer,
    ru_nvcsw integer,
    rn_nivcsw integer,
    raw_ru_nvcsw integer,
    raw_rn_nivcsw integer
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/segment_query_stats -H 168',
    delimiter ',',
    encoding '6',
    escape '"',
    execute_on 'ALL_SEGMENTS',
    fill_missing_fields 'true',
    format 'csv',
    format_type 'c',
    is_writable 'false',
    log_errors 'f',
    "null" '',
    quote '"'
);


ALTER FOREIGN TABLE cbmon.__query_stats_7days OWNER TO gpadmin;

--
-- Name: __storage_master; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__storage_master (
    hostname text,
    device text,
    mntpt text,
    major integer,
    minor integer,
    volserial text
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/partitions.sh',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__storage_master OWNER TO gpadmin;

--
-- Name: __storage_segments; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__storage_segments (
    hostname text,
    device text,
    mntpt text,
    major integer,
    minor integer,
    volserial text
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/partitions.sh',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__storage_segments OWNER TO gpadmin;

--
-- Name: __swap_master_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__swap_master_all (
    hostname text,
    period timestamp with time zone,
    kbswpfree integer,
    kbswpused integer,
    swpused_pct double precision,
    kbswpcad integer,
    swpcad_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-S"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__swap_master_all OWNER TO gpadmin;

--
-- Name: __swap_master_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__swap_master_today (
    hostname text,
    period timestamp with time zone,
    kbswpfree integer,
    kbswpused integer,
    swpused_pct double precision,
    kbswpcad integer,
    swpcad_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-S"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__swap_master_today OWNER TO gpadmin;

--
-- Name: __swap_master_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__swap_master_yesterday (
    hostname text,
    period timestamp with time zone,
    kbswpfree integer,
    kbswpused integer,
    swpused_pct double precision,
    kbswpcad integer,
    swpcad_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-S"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__swap_master_yesterday OWNER TO gpadmin;

--
-- Name: __swap_segments_all; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__swap_segments_all (
    hostname text,
    period timestamp with time zone,
    kbswpfree integer,
    kbswpused integer,
    swpused_pct double precision,
    kbswpcad integer,
    swpcad_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -a -S "-S"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__swap_segments_all OWNER TO gpadmin;

--
-- Name: __swap_segments_today; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__swap_segments_today (
    hostname text,
    period timestamp with time zone,
    kbswpfree integer,
    kbswpused integer,
    swpused_pct double precision,
    kbswpcad integer,
    swpcad_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -S "-S"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__swap_segments_today OWNER TO gpadmin;

--
-- Name: __swap_segments_yesterday; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__swap_segments_yesterday (
    hostname text,
    period timestamp with time zone,
    kbswpfree integer,
    kbswpused integer,
    swpused_pct double precision,
    kbswpcad integer,
    swpcad_pct double precision
)
SERVER gp_exttable_server
OPTIONS (
    command '/usr/local/cbmon/bin/sar_reader -p -S "-S"',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__swap_segments_yesterday OWNER TO gpadmin;

--
-- Name: __uptime_master; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__uptime_master (
    hostname text,
    uptime double precision,
    ldavg_1 double precision,
    ldavg_5 double precision,
    ldavg_15 double precision,
    running_proc integer,
    total_proc integer,
    last_pid integer
)
SERVER gp_exttable_server
OPTIONS (
    command E'awk -v hn=$(hostname) -v upt=$(awk ''{print $1}'' /proc/uptime) ''{gsub(/\\//," ",$4);printf("%s %s %s\\n",hn,upt,$0)}'' /proc/loadavg',
    delimiter ' ',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__uptime_master OWNER TO gpadmin;

--
-- Name: __uptime_segments; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.__uptime_segments (
    hostname text,
    uptime double precision,
    ldavg_1 double precision,
    ldavg_5 double precision,
    ldavg_15 double precision,
    running_proc integer,
    total_proc integer,
    last_pid integer
)
SERVER gp_exttable_server
OPTIONS (
    command E'awk -v hn=$(hostname) -v upt=$(awk ''{print $1}'' /proc/uptime) ''{gsub(/\\//," ",$4);printf("%s %s %s\\n",hn,upt,$0)}'' /proc/loadavg',
    delimiter ' ',
    encoding '6',
    escape E'\\',
    execute_on 'PER_HOST',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.__uptime_segments OWNER TO gpadmin;

--
-- Name: _disk_space_all; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._disk_space_all AS
 SELECT now() AS period,
    __disk_space_master.hostname,
    __disk_space_master.mntpt,
    __disk_space_master.total_kbs,
    __disk_space_master.used_kbs,
    __disk_space_master.avail_kbs
   FROM cbmon.__disk_space_master
UNION
 SELECT now() AS period,
    __disk_space_segments.hostname,
    __disk_space_segments.mntpt,
    __disk_space_segments.total_kbs,
    __disk_space_segments.used_kbs,
    __disk_space_segments.avail_kbs
   FROM cbmon.__disk_space_segments;


ALTER TABLE cbmon._disk_space_all OWNER TO gpadmin;

--
-- Name: _live_uptime; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._live_uptime AS
 SELECT __uptime_segments.hostname,
    __uptime_segments.uptime,
    __uptime_segments.ldavg_1,
    __uptime_segments.ldavg_5,
    __uptime_segments.ldavg_15,
    __uptime_segments.running_proc,
    __uptime_segments.total_proc,
    __uptime_segments.last_pid
   FROM cbmon.__uptime_segments
UNION
 SELECT __uptime_master.hostname,
    __uptime_master.uptime,
    __uptime_master.ldavg_1,
    __uptime_master.ldavg_5,
    __uptime_master.ldavg_15,
    __uptime_master.running_proc,
    __uptime_master.total_proc,
    __uptime_master.last_pid
   FROM cbmon.__uptime_master;


ALTER TABLE cbmon._live_uptime OWNER TO gpadmin;

--
-- Name: _raw_cpu_all; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_cpu_all AS
 SELECT __cpu_segments_all.hostname,
    __cpu_segments_all.period,
    __cpu_segments_all.cpu,
    __cpu_segments_all.usr,
    __cpu_segments_all.nice,
    __cpu_segments_all.sys,
    __cpu_segments_all.iowait,
    __cpu_segments_all.steal,
    __cpu_segments_all.irq,
    __cpu_segments_all.soft,
    __cpu_segments_all.guest,
    __cpu_segments_all.gnice,
    __cpu_segments_all.idle
   FROM cbmon.__cpu_segments_all
UNION
 SELECT __cpu_master_all.hostname,
    __cpu_master_all.period,
    __cpu_master_all.cpu,
    __cpu_master_all.usr,
    __cpu_master_all.nice,
    __cpu_master_all.sys,
    __cpu_master_all.iowait,
    __cpu_master_all.steal,
    __cpu_master_all.irq,
    __cpu_master_all.soft,
    __cpu_master_all.guest,
    __cpu_master_all.gnice,
    __cpu_master_all.idle
   FROM cbmon.__cpu_master_all;


ALTER TABLE cbmon._raw_cpu_all OWNER TO gpadmin;

--
-- Name: _raw_cpu_today; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_cpu_today AS
 SELECT __cpu_segments_today.hostname,
    __cpu_segments_today.period,
    __cpu_segments_today.cpu,
    __cpu_segments_today.usr,
    __cpu_segments_today.nice,
    __cpu_segments_today.sys,
    __cpu_segments_today.iowait,
    __cpu_segments_today.steal,
    __cpu_segments_today.irq,
    __cpu_segments_today.soft,
    __cpu_segments_today.guest,
    __cpu_segments_today.gnice,
    __cpu_segments_today.idle
   FROM cbmon.__cpu_segments_today
UNION
 SELECT __cpu_master_today.hostname,
    __cpu_master_today.period,
    __cpu_master_today.cpu,
    __cpu_master_today.usr,
    __cpu_master_today.nice,
    __cpu_master_today.sys,
    __cpu_master_today.iowait,
    __cpu_master_today.steal,
    __cpu_master_today.irq,
    __cpu_master_today.soft,
    __cpu_master_today.guest,
    __cpu_master_today.gnice,
    __cpu_master_today.idle
   FROM cbmon.__cpu_master_today;


ALTER TABLE cbmon._raw_cpu_today OWNER TO gpadmin;

--
-- Name: _raw_cpu_yesterday; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_cpu_yesterday AS
 SELECT __cpu_segments_yesterday.hostname,
    __cpu_segments_yesterday.period,
    __cpu_segments_yesterday.cpu,
    __cpu_segments_yesterday.usr,
    __cpu_segments_yesterday.nice,
    __cpu_segments_yesterday.sys,
    __cpu_segments_yesterday.iowait,
    __cpu_segments_yesterday.steal,
    __cpu_segments_yesterday.irq,
    __cpu_segments_yesterday.soft,
    __cpu_segments_yesterday.guest,
    __cpu_segments_yesterday.gnice,
    __cpu_segments_yesterday.idle
   FROM cbmon.__cpu_segments_yesterday
UNION
 SELECT __cpu_master_yesterday.hostname,
    __cpu_master_yesterday.period,
    __cpu_master_yesterday.cpu,
    __cpu_master_yesterday.usr,
    __cpu_master_yesterday.nice,
    __cpu_master_yesterday.sys,
    __cpu_master_yesterday.iowait,
    __cpu_master_yesterday.steal,
    __cpu_master_yesterday.irq,
    __cpu_master_yesterday.soft,
    __cpu_master_yesterday.guest,
    __cpu_master_yesterday.gnice,
    __cpu_master_yesterday.idle
   FROM cbmon.__cpu_master_yesterday;


ALTER TABLE cbmon._raw_cpu_yesterday OWNER TO gpadmin;

--
-- Name: _raw_disk_all; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_disk_all AS
 SELECT __disk_segments_all.hostname,
    __disk_segments_all.period,
    __disk_segments_all.device,
    __disk_segments_all.tps,
    __disk_segments_all.rkbs,
    __disk_segments_all.wkbs,
    __disk_segments_all.areq_sz,
    __disk_segments_all.aqu_sz,
    __disk_segments_all.await,
    __disk_segments_all.svctm,
    __disk_segments_all.util_pct
   FROM cbmon.__disk_segments_all
UNION
 SELECT __disk_master_all.hostname,
    __disk_master_all.period,
    __disk_master_all.device,
    __disk_master_all.tps,
    __disk_master_all.rkbs,
    __disk_master_all.wkbs,
    __disk_master_all.areq_sz,
    __disk_master_all.aqu_sz,
    __disk_master_all.await,
    __disk_master_all.svctm,
    __disk_master_all.util_pct
   FROM cbmon.__disk_master_all;


ALTER TABLE cbmon._raw_disk_all OWNER TO gpadmin;

--
-- Name: _raw_disk_today; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_disk_today AS
 SELECT __disk_segments_today.hostname,
    __disk_segments_today.period,
    __disk_segments_today.device,
    __disk_segments_today.tps,
    __disk_segments_today.rkbs,
    __disk_segments_today.wkbs,
    __disk_segments_today.areq_sz,
    __disk_segments_today.aqu_sz,
    __disk_segments_today.await,
    __disk_segments_today.svctm,
    __disk_segments_today.util_pct
   FROM cbmon.__disk_segments_today
UNION
 SELECT __disk_master_today.hostname,
    __disk_master_today.period,
    __disk_master_today.device,
    __disk_master_today.tps,
    __disk_master_today.rkbs,
    __disk_master_today.wkbs,
    __disk_master_today.areq_sz,
    __disk_master_today.aqu_sz,
    __disk_master_today.await,
    __disk_master_today.svctm,
    __disk_master_today.util_pct
   FROM cbmon.__disk_master_today;


ALTER TABLE cbmon._raw_disk_today OWNER TO gpadmin;

--
-- Name: _raw_disk_yesterday; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_disk_yesterday AS
 SELECT __disk_segments_yesterday.hostname,
    __disk_segments_yesterday.period,
    __disk_segments_yesterday.device,
    __disk_segments_yesterday.tps,
    __disk_segments_yesterday.rkbs,
    __disk_segments_yesterday.wkbs,
    __disk_segments_yesterday.areq_sz,
    __disk_segments_yesterday.aqu_sz,
    __disk_segments_yesterday.await,
    __disk_segments_yesterday.svctm,
    __disk_segments_yesterday.util_pct
   FROM cbmon.__disk_segments_yesterday
UNION
 SELECT __disk_master_yesterday.hostname,
    __disk_master_yesterday.period,
    __disk_master_yesterday.device,
    __disk_master_yesterday.tps,
    __disk_master_yesterday.rkbs,
    __disk_master_yesterday.wkbs,
    __disk_master_yesterday.areq_sz,
    __disk_master_yesterday.aqu_sz,
    __disk_master_yesterday.await,
    __disk_master_yesterday.svctm,
    __disk_master_yesterday.util_pct
   FROM cbmon.__disk_master_yesterday;


ALTER TABLE cbmon._raw_disk_yesterday OWNER TO gpadmin;

--
-- Name: _raw_ldavg_all; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_ldavg_all AS
 SELECT __ldavg_segments_all.hostname,
    __ldavg_segments_all.period,
    __ldavg_segments_all.runq_sz,
    __ldavg_segments_all.plist_sz,
    __ldavg_segments_all.ldavg_1,
    __ldavg_segments_all.ldavg_5,
    __ldavg_segments_all.ldavg_15,
    __ldavg_segments_all.blocked
   FROM cbmon.__ldavg_segments_all
UNION
 SELECT __ldavg_master_all.hostname,
    __ldavg_master_all.period,
    __ldavg_master_all.runq_sz,
    __ldavg_master_all.plist_sz,
    __ldavg_master_all.ldavg_1,
    __ldavg_master_all.ldavg_5,
    __ldavg_master_all.ldavg_15,
    __ldavg_master_all.blocked
   FROM cbmon.__ldavg_master_all;


ALTER TABLE cbmon._raw_ldavg_all OWNER TO gpadmin;

--
-- Name: _raw_ldavg_today; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_ldavg_today AS
 SELECT __ldavg_segments_today.hostname,
    __ldavg_segments_today.period,
    __ldavg_segments_today.runq_sz,
    __ldavg_segments_today.plist_sz,
    __ldavg_segments_today.ldavg_1,
    __ldavg_segments_today.ldavg_5,
    __ldavg_segments_today.ldavg_15,
    __ldavg_segments_today.blocked
   FROM cbmon.__ldavg_segments_today
UNION
 SELECT __ldavg_master_today.hostname,
    __ldavg_master_today.period,
    __ldavg_master_today.runq_sz,
    __ldavg_master_today.plist_sz,
    __ldavg_master_today.ldavg_1,
    __ldavg_master_today.ldavg_5,
    __ldavg_master_today.ldavg_15,
    __ldavg_master_today.blocked
   FROM cbmon.__ldavg_master_today;


ALTER TABLE cbmon._raw_ldavg_today OWNER TO gpadmin;

--
-- Name: _raw_ldavg_yesterday; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_ldavg_yesterday AS
 SELECT __ldavg_segments_yesterday.hostname,
    __ldavg_segments_yesterday.period,
    __ldavg_segments_yesterday.runq_sz,
    __ldavg_segments_yesterday.plist_sz,
    __ldavg_segments_yesterday.ldavg_1,
    __ldavg_segments_yesterday.ldavg_5,
    __ldavg_segments_yesterday.ldavg_15,
    __ldavg_segments_yesterday.blocked
   FROM cbmon.__ldavg_segments_yesterday
UNION
 SELECT __ldavg_master_yesterday.hostname,
    __ldavg_master_yesterday.period,
    __ldavg_master_yesterday.runq_sz,
    __ldavg_master_yesterday.plist_sz,
    __ldavg_master_yesterday.ldavg_1,
    __ldavg_master_yesterday.ldavg_5,
    __ldavg_master_yesterday.ldavg_15,
    __ldavg_master_yesterday.blocked
   FROM cbmon.__ldavg_master_yesterday;


ALTER TABLE cbmon._raw_ldavg_yesterday OWNER TO gpadmin;

--
-- Name: _raw_memory_all; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_memory_all AS
 SELECT __memory_segments_all.hostname,
    __memory_segments_all.period,
    __memory_segments_all.kbmemfree,
    __memory_segments_all.kbavail,
    __memory_segments_all.kbmemused,
    __memory_segments_all.memused_pct,
    __memory_segments_all.kbbuffers,
    __memory_segments_all.kbcached,
    __memory_segments_all.kbcommit,
    __memory_segments_all.commit_pct,
    __memory_segments_all.kbactive,
    __memory_segments_all.kbinact,
    __memory_segments_all.kbdirty,
    __memory_segments_all.kbanonpg,
    __memory_segments_all.kbslab,
    __memory_segments_all.kbkstack,
    __memory_segments_all.kbpgtbl,
    __memory_segments_all.kbvmused
   FROM cbmon.__memory_segments_all
UNION
 SELECT __memory_master_all.hostname,
    __memory_master_all.period,
    __memory_master_all.kbmemfree,
    __memory_master_all.kbavail,
    __memory_master_all.kbmemused,
    __memory_master_all.memused_pct,
    __memory_master_all.kbbuffers,
    __memory_master_all.kbcached,
    __memory_master_all.kbcommit,
    __memory_master_all.commit_pct,
    __memory_master_all.kbactive,
    __memory_master_all.kbinact,
    __memory_master_all.kbdirty,
    __memory_master_all.kbanonpg,
    __memory_master_all.kbslab,
    __memory_master_all.kbkstack,
    __memory_master_all.kbpgtbl,
    __memory_master_all.kbvmused
   FROM cbmon.__memory_master_all;


ALTER TABLE cbmon._raw_memory_all OWNER TO gpadmin;

--
-- Name: _raw_memory_today; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_memory_today AS
 SELECT __memory_segments_today.hostname,
    __memory_segments_today.period,
    __memory_segments_today.kbmemfree,
    __memory_segments_today.kbavail,
    __memory_segments_today.kbmemused,
    __memory_segments_today.memused_pct,
    __memory_segments_today.kbbuffers,
    __memory_segments_today.kbcached,
    __memory_segments_today.kbcommit,
    __memory_segments_today.commit_pct,
    __memory_segments_today.kbactive,
    __memory_segments_today.kbinact,
    __memory_segments_today.kbdirty,
    __memory_segments_today.kbanonpg,
    __memory_segments_today.kbslab,
    __memory_segments_today.kbkstack,
    __memory_segments_today.kbpgtbl,
    __memory_segments_today.kbvmused
   FROM cbmon.__memory_segments_today
UNION
 SELECT __memory_master_today.hostname,
    __memory_master_today.period,
    __memory_master_today.kbmemfree,
    __memory_master_today.kbavail,
    __memory_master_today.kbmemused,
    __memory_master_today.memused_pct,
    __memory_master_today.kbbuffers,
    __memory_master_today.kbcached,
    __memory_master_today.kbcommit,
    __memory_master_today.commit_pct,
    __memory_master_today.kbactive,
    __memory_master_today.kbinact,
    __memory_master_today.kbdirty,
    __memory_master_today.kbanonpg,
    __memory_master_today.kbslab,
    __memory_master_today.kbkstack,
    __memory_master_today.kbpgtbl,
    __memory_master_today.kbvmused
   FROM cbmon.__memory_master_today;


ALTER TABLE cbmon._raw_memory_today OWNER TO gpadmin;

--
-- Name: _raw_memory_yesterday; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_memory_yesterday AS
 SELECT __memory_segments_yesterday.hostname,
    __memory_segments_yesterday.period,
    __memory_segments_yesterday.kbmemfree,
    __memory_segments_yesterday.kbavail,
    __memory_segments_yesterday.kbmemused,
    __memory_segments_yesterday.memused_pct,
    __memory_segments_yesterday.kbbuffers,
    __memory_segments_yesterday.kbcached,
    __memory_segments_yesterday.kbcommit,
    __memory_segments_yesterday.commit_pct,
    __memory_segments_yesterday.kbactive,
    __memory_segments_yesterday.kbinact,
    __memory_segments_yesterday.kbdirty,
    __memory_segments_yesterday.kbanonpg,
    __memory_segments_yesterday.kbslab,
    __memory_segments_yesterday.kbkstack,
    __memory_segments_yesterday.kbpgtbl,
    __memory_segments_yesterday.kbvmused
   FROM cbmon.__memory_segments_yesterday
UNION
 SELECT __memory_master_yesterday.hostname,
    __memory_master_yesterday.period,
    __memory_master_yesterday.kbmemfree,
    __memory_master_yesterday.kbavail,
    __memory_master_yesterday.kbmemused,
    __memory_master_yesterday.memused_pct,
    __memory_master_yesterday.kbbuffers,
    __memory_master_yesterday.kbcached,
    __memory_master_yesterday.kbcommit,
    __memory_master_yesterday.commit_pct,
    __memory_master_yesterday.kbactive,
    __memory_master_yesterday.kbinact,
    __memory_master_yesterday.kbdirty,
    __memory_master_yesterday.kbanonpg,
    __memory_master_yesterday.kbslab,
    __memory_master_yesterday.kbkstack,
    __memory_master_yesterday.kbpgtbl,
    __memory_master_yesterday.kbvmused
   FROM cbmon.__memory_master_yesterday;


ALTER TABLE cbmon._raw_memory_yesterday OWNER TO gpadmin;

--
-- Name: _raw_network_dev_all; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_dev_all AS
 SELECT __network_dev_segments_all.hostname,
    __network_dev_segments_all.period,
    __network_dev_segments_all.iface,
    __network_dev_segments_all.rxpck_psec,
    __network_dev_segments_all.txpck_psec,
    __network_dev_segments_all.rxkb_psec,
    __network_dev_segments_all.txkb_psec,
    __network_dev_segments_all.rxcmp_psec,
    __network_dev_segments_all.txcmp_psec,
    __network_dev_segments_all.rxmcst_psec,
    __network_dev_segments_all.ifutil_pct
   FROM cbmon.__network_dev_segments_all
UNION
 SELECT __network_dev_master_all.hostname,
    __network_dev_master_all.period,
    __network_dev_master_all.iface,
    __network_dev_master_all.rxpck_psec,
    __network_dev_master_all.txpck_psec,
    __network_dev_master_all.rxkb_psec,
    __network_dev_master_all.txkb_psec,
    __network_dev_master_all.rxcmp_psec,
    __network_dev_master_all.txcmp_psec,
    __network_dev_master_all.rxmcst_psec,
    __network_dev_master_all.ifutil_pct
   FROM cbmon.__network_dev_master_all;


ALTER TABLE cbmon._raw_network_dev_all OWNER TO gpadmin;

--
-- Name: _raw_network_dev_today; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_dev_today AS
 SELECT __network_dev_segments_today.hostname,
    __network_dev_segments_today.period,
    __network_dev_segments_today.iface,
    __network_dev_segments_today.rxpck_psec,
    __network_dev_segments_today.txpck_psec,
    __network_dev_segments_today.rxkb_psec,
    __network_dev_segments_today.txkb_psec,
    __network_dev_segments_today.rxcmp_psec,
    __network_dev_segments_today.txcmp_psec,
    __network_dev_segments_today.rxmcst_psec,
    __network_dev_segments_today.ifutil_pct
   FROM cbmon.__network_dev_segments_today
UNION
 SELECT __network_dev_master_today.hostname,
    __network_dev_master_today.period,
    __network_dev_master_today.iface,
    __network_dev_master_today.rxpck_psec,
    __network_dev_master_today.txpck_psec,
    __network_dev_master_today.rxkb_psec,
    __network_dev_master_today.txkb_psec,
    __network_dev_master_today.rxcmp_psec,
    __network_dev_master_today.txcmp_psec,
    __network_dev_master_today.rxmcst_psec,
    __network_dev_master_today.ifutil_pct
   FROM cbmon.__network_dev_master_today;


ALTER TABLE cbmon._raw_network_dev_today OWNER TO gpadmin;

--
-- Name: _raw_network_dev_yesterday; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_dev_yesterday AS
 SELECT __network_dev_segments_yesterday.hostname,
    __network_dev_segments_yesterday.period,
    __network_dev_segments_yesterday.iface,
    __network_dev_segments_yesterday.rxpck_psec,
    __network_dev_segments_yesterday.txpck_psec,
    __network_dev_segments_yesterday.rxkb_psec,
    __network_dev_segments_yesterday.txkb_psec,
    __network_dev_segments_yesterday.rxcmp_psec,
    __network_dev_segments_yesterday.txcmp_psec,
    __network_dev_segments_yesterday.rxmcst_psec,
    __network_dev_segments_yesterday.ifutil_pct
   FROM cbmon.__network_dev_segments_yesterday
UNION
 SELECT __network_dev_master_yesterday.hostname,
    __network_dev_master_yesterday.period,
    __network_dev_master_yesterday.iface,
    __network_dev_master_yesterday.rxpck_psec,
    __network_dev_master_yesterday.txpck_psec,
    __network_dev_master_yesterday.rxkb_psec,
    __network_dev_master_yesterday.txkb_psec,
    __network_dev_master_yesterday.rxcmp_psec,
    __network_dev_master_yesterday.txcmp_psec,
    __network_dev_master_yesterday.rxmcst_psec,
    __network_dev_master_yesterday.ifutil_pct
   FROM cbmon.__network_dev_master_yesterday;


ALTER TABLE cbmon._raw_network_dev_yesterday OWNER TO gpadmin;

--
-- Name: _raw_network_errors_all; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_errors_all AS
 SELECT __network_errors_segments_all.hostname,
    __network_errors_segments_all.period,
    __network_errors_segments_all.iface,
    __network_errors_segments_all.rxerr_psec,
    __network_errors_segments_all.txerr_psec,
    __network_errors_segments_all.coll_psec,
    __network_errors_segments_all.rxdrop_psec,
    __network_errors_segments_all.txdrop_psec,
    __network_errors_segments_all.txcarr_psec,
    __network_errors_segments_all.rxfram_psec,
    __network_errors_segments_all.rxfifo_psec,
    __network_errors_segments_all.txfifo_psec
   FROM cbmon.__network_errors_segments_all
UNION
 SELECT __network_errors_master_all.hostname,
    __network_errors_master_all.period,
    __network_errors_master_all.iface,
    __network_errors_master_all.rxerr_psec,
    __network_errors_master_all.txerr_psec,
    __network_errors_master_all.coll_psec,
    __network_errors_master_all.rxdrop_psec,
    __network_errors_master_all.txdrop_psec,
    __network_errors_master_all.txcarr_psec,
    __network_errors_master_all.rxfram_psec,
    __network_errors_master_all.rxfifo_psec,
    __network_errors_master_all.txfifo_psec
   FROM cbmon.__network_errors_master_all;


ALTER TABLE cbmon._raw_network_errors_all OWNER TO gpadmin;

--
-- Name: _raw_network_errors_today; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_errors_today AS
 SELECT __network_errors_segments_today.hostname,
    __network_errors_segments_today.period,
    __network_errors_segments_today.iface,
    __network_errors_segments_today.rxerr_psec,
    __network_errors_segments_today.txerr_psec,
    __network_errors_segments_today.coll_psec,
    __network_errors_segments_today.rxdrop_psec,
    __network_errors_segments_today.txdrop_psec,
    __network_errors_segments_today.txcarr_psec,
    __network_errors_segments_today.rxfram_psec,
    __network_errors_segments_today.rxfifo_psec,
    __network_errors_segments_today.txfifo_psec
   FROM cbmon.__network_errors_segments_today
UNION
 SELECT __network_errors_master_today.hostname,
    __network_errors_master_today.period,
    __network_errors_master_today.iface,
    __network_errors_master_today.rxerr_psec,
    __network_errors_master_today.txerr_psec,
    __network_errors_master_today.coll_psec,
    __network_errors_master_today.rxdrop_psec,
    __network_errors_master_today.txdrop_psec,
    __network_errors_master_today.txcarr_psec,
    __network_errors_master_today.rxfram_psec,
    __network_errors_master_today.rxfifo_psec,
    __network_errors_master_today.txfifo_psec
   FROM cbmon.__network_errors_master_today;


ALTER TABLE cbmon._raw_network_errors_today OWNER TO gpadmin;

--
-- Name: _raw_network_errors_yesterday; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_errors_yesterday AS
 SELECT __network_errors_segments_yesterday.hostname,
    __network_errors_segments_yesterday.period,
    __network_errors_segments_yesterday.iface,
    __network_errors_segments_yesterday.rxerr_psec,
    __network_errors_segments_yesterday.txerr_psec,
    __network_errors_segments_yesterday.coll_psec,
    __network_errors_segments_yesterday.rxdrop_psec,
    __network_errors_segments_yesterday.txdrop_psec,
    __network_errors_segments_yesterday.txcarr_psec,
    __network_errors_segments_yesterday.rxfram_psec,
    __network_errors_segments_yesterday.rxfifo_psec,
    __network_errors_segments_yesterday.txfifo_psec
   FROM cbmon.__network_errors_segments_yesterday
UNION
 SELECT __network_errors_master_yesterday.hostname,
    __network_errors_master_yesterday.period,
    __network_errors_master_yesterday.iface,
    __network_errors_master_yesterday.rxerr_psec,
    __network_errors_master_yesterday.txerr_psec,
    __network_errors_master_yesterday.coll_psec,
    __network_errors_master_yesterday.rxdrop_psec,
    __network_errors_master_yesterday.txdrop_psec,
    __network_errors_master_yesterday.txcarr_psec,
    __network_errors_master_yesterday.rxfram_psec,
    __network_errors_master_yesterday.rxfifo_psec,
    __network_errors_master_yesterday.txfifo_psec
   FROM cbmon.__network_errors_master_yesterday;


ALTER TABLE cbmon._raw_network_errors_yesterday OWNER TO gpadmin;

--
-- Name: _raw_network_sockets_all; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_sockets_all AS
 SELECT __network_sockets_segments_all.hostname,
    __network_sockets_segments_all.period,
    __network_sockets_segments_all.totsck,
    __network_sockets_segments_all.tcpsck,
    __network_sockets_segments_all.udpsck,
    __network_sockets_segments_all.rawsck,
    __network_sockets_segments_all.ip_frag,
    __network_sockets_segments_all.tcp_tw
   FROM cbmon.__network_sockets_segments_all
UNION
 SELECT __network_sockets_master_all.hostname,
    __network_sockets_master_all.period,
    __network_sockets_master_all.totsck,
    __network_sockets_master_all.tcpsck,
    __network_sockets_master_all.udpsck,
    __network_sockets_master_all.rawsck,
    __network_sockets_master_all.ip_frag,
    __network_sockets_master_all.tcp_tw
   FROM cbmon.__network_sockets_master_all;


ALTER TABLE cbmon._raw_network_sockets_all OWNER TO gpadmin;

--
-- Name: _raw_network_sockets_today; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_sockets_today AS
 SELECT __network_sockets_segments_today.hostname,
    __network_sockets_segments_today.period,
    __network_sockets_segments_today.totsck,
    __network_sockets_segments_today.tcpsck,
    __network_sockets_segments_today.udpsck,
    __network_sockets_segments_today.rawsck,
    __network_sockets_segments_today.ip_frag,
    __network_sockets_segments_today.tcp_tw
   FROM cbmon.__network_sockets_segments_today
UNION
 SELECT __network_sockets_master_today.hostname,
    __network_sockets_master_today.period,
    __network_sockets_master_today.totsck,
    __network_sockets_master_today.tcpsck,
    __network_sockets_master_today.udpsck,
    __network_sockets_master_today.rawsck,
    __network_sockets_master_today.ip_frag,
    __network_sockets_master_today.tcp_tw
   FROM cbmon.__network_sockets_master_today;


ALTER TABLE cbmon._raw_network_sockets_today OWNER TO gpadmin;

--
-- Name: _raw_network_sockets_yesterday; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_sockets_yesterday AS
 SELECT __network_sockets_segments_yesterday.hostname,
    __network_sockets_segments_yesterday.period,
    __network_sockets_segments_yesterday.totsck,
    __network_sockets_segments_yesterday.tcpsck,
    __network_sockets_segments_yesterday.udpsck,
    __network_sockets_segments_yesterday.rawsck,
    __network_sockets_segments_yesterday.ip_frag,
    __network_sockets_segments_yesterday.tcp_tw
   FROM cbmon.__network_sockets_segments_yesterday
UNION
 SELECT __network_sockets_master_yesterday.hostname,
    __network_sockets_master_yesterday.period,
    __network_sockets_master_yesterday.totsck,
    __network_sockets_master_yesterday.tcpsck,
    __network_sockets_master_yesterday.udpsck,
    __network_sockets_master_yesterday.rawsck,
    __network_sockets_master_yesterday.ip_frag,
    __network_sockets_master_yesterday.tcp_tw
   FROM cbmon.__network_sockets_master_yesterday;


ALTER TABLE cbmon._raw_network_sockets_yesterday OWNER TO gpadmin;

--
-- Name: _raw_network_softproc_all; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_softproc_all AS
 SELECT __network_softproc_segments_all.hostname,
    __network_softproc_segments_all.period,
    __network_softproc_segments_all.cpu,
    __network_softproc_segments_all.total_psec,
    __network_softproc_segments_all.dropd_psec,
    __network_softproc_segments_all.squeezd_psec,
    __network_softproc_segments_all.rx_rps_psec,
    __network_softproc_segments_all.flw_lim_psec
   FROM cbmon.__network_softproc_segments_all
UNION
 SELECT __network_softproc_master_all.hostname,
    __network_softproc_master_all.period,
    __network_softproc_master_all.cpu,
    __network_softproc_master_all.total_psec,
    __network_softproc_master_all.dropd_psec,
    __network_softproc_master_all.squeezd_psec,
    __network_softproc_master_all.rx_rps_psec,
    __network_softproc_master_all.flw_lim_psec
   FROM cbmon.__network_softproc_master_all;


ALTER TABLE cbmon._raw_network_softproc_all OWNER TO gpadmin;

--
-- Name: _raw_network_softproc_today; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_softproc_today AS
 SELECT __network_softproc_segments_today.hostname,
    __network_softproc_segments_today.period,
    __network_softproc_segments_today.cpu,
    __network_softproc_segments_today.total_psec,
    __network_softproc_segments_today.dropd_psec,
    __network_softproc_segments_today.squeezd_psec,
    __network_softproc_segments_today.rx_rps_psec,
    __network_softproc_segments_today.flw_lim_psec
   FROM cbmon.__network_softproc_segments_today
UNION
 SELECT __network_softproc_master_today.hostname,
    __network_softproc_master_today.period,
    __network_softproc_master_today.cpu,
    __network_softproc_master_today.total_psec,
    __network_softproc_master_today.dropd_psec,
    __network_softproc_master_today.squeezd_psec,
    __network_softproc_master_today.rx_rps_psec,
    __network_softproc_master_today.flw_lim_psec
   FROM cbmon.__network_softproc_master_today;


ALTER TABLE cbmon._raw_network_softproc_today OWNER TO gpadmin;

--
-- Name: _raw_network_softproc_yesterday; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_network_softproc_yesterday AS
 SELECT __network_softproc_segments_yesterday.hostname,
    __network_softproc_segments_yesterday.period,
    __network_softproc_segments_yesterday.cpu,
    __network_softproc_segments_yesterday.total_psec,
    __network_softproc_segments_yesterday.dropd_psec,
    __network_softproc_segments_yesterday.squeezd_psec,
    __network_softproc_segments_yesterday.rx_rps_psec,
    __network_softproc_segments_yesterday.flw_lim_psec
   FROM cbmon.__network_softproc_segments_yesterday
UNION
 SELECT __network_softproc_master_yesterday.hostname,
    __network_softproc_master_yesterday.period,
    __network_softproc_master_yesterday.cpu,
    __network_softproc_master_yesterday.total_psec,
    __network_softproc_master_yesterday.dropd_psec,
    __network_softproc_master_yesterday.squeezd_psec,
    __network_softproc_master_yesterday.rx_rps_psec,
    __network_softproc_master_yesterday.flw_lim_psec
   FROM cbmon.__network_softproc_master_yesterday;


ALTER TABLE cbmon._raw_network_softproc_yesterday OWNER TO gpadmin;

--
-- Name: _raw_swap_all; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_swap_all AS
 SELECT __swap_segments_all.hostname,
    __swap_segments_all.period,
    __swap_segments_all.kbswpfree,
    __swap_segments_all.kbswpused,
    __swap_segments_all.swpused_pct,
    __swap_segments_all.kbswpcad,
    __swap_segments_all.swpcad_pct
   FROM cbmon.__swap_segments_all
UNION
 SELECT __swap_master_all.hostname,
    __swap_master_all.period,
    __swap_master_all.kbswpfree,
    __swap_master_all.kbswpused,
    __swap_master_all.swpused_pct,
    __swap_master_all.kbswpcad,
    __swap_master_all.swpcad_pct
   FROM cbmon.__swap_master_all;


ALTER TABLE cbmon._raw_swap_all OWNER TO gpadmin;

--
-- Name: _raw_swap_today; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_swap_today AS
 SELECT __swap_segments_today.hostname,
    __swap_segments_today.period,
    __swap_segments_today.kbswpfree,
    __swap_segments_today.kbswpused,
    __swap_segments_today.swpused_pct,
    __swap_segments_today.kbswpcad,
    __swap_segments_today.swpcad_pct
   FROM cbmon.__swap_segments_today
UNION
 SELECT __swap_master_today.hostname,
    __swap_master_today.period,
    __swap_master_today.kbswpfree,
    __swap_master_today.kbswpused,
    __swap_master_today.swpused_pct,
    __swap_master_today.kbswpcad,
    __swap_master_today.swpcad_pct
   FROM cbmon.__swap_master_today;


ALTER TABLE cbmon._raw_swap_today OWNER TO gpadmin;

--
-- Name: _raw_swap_yesterday; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon._raw_swap_yesterday AS
 SELECT __swap_segments_yesterday.hostname,
    __swap_segments_yesterday.period,
    __swap_segments_yesterday.kbswpfree,
    __swap_segments_yesterday.kbswpused,
    __swap_segments_yesterday.swpused_pct,
    __swap_segments_yesterday.kbswpcad,
    __swap_segments_yesterday.swpcad_pct
   FROM cbmon.__swap_segments_yesterday
UNION
 SELECT __swap_master_yesterday.hostname,
    __swap_master_yesterday.period,
    __swap_master_yesterday.kbswpfree,
    __swap_master_yesterday.kbswpused,
    __swap_master_yesterday.swpused_pct,
    __swap_master_yesterday.kbswpcad,
    __swap_master_yesterday.swpcad_pct
   FROM cbmon.__swap_master_yesterday;


ALTER TABLE cbmon._raw_swap_yesterday OWNER TO gpadmin;

SET default_table_access_method = heap;

--
-- Name: _storage; Type: MATERIALIZED VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE MATERIALIZED VIEW cbmon._storage AS
 SELECT now() AS period,
    s.hostname,
    s.device,
    s.mntpt,
    s.major,
    s.minor,
    format('dev%s-%s'::text, s.major, s.minor) AS diskdevice,
    s.volserial
   FROM cbmon.__storage_segments s
UNION
 SELECT now() AS period,
    s.hostname,
    s.device,
    s.mntpt,
    s.major,
    s.minor,
    format('dev%s-%s'::text, s.major, s.minor) AS diskdevice,
    s.volserial
   FROM cbmon.__storage_master s
  WITH NO DATA DISTRIBUTED BY (period);


ALTER TABLE cbmon._storage OWNER TO gpadmin;

--
-- Name: alters; Type: TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE TABLE cbmon.alters (
    id integer NOT NULL,
    summary text NOT NULL
) DISTRIBUTED BY (id);


ALTER TABLE cbmon.alters OWNER TO gpadmin;

--
-- Name: cat_gp_configuration_history; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_configuration_history AS
 SELECT gp_configuration_history."time",
    gp_configuration_history.dbid,
    gp_configuration_history."desc"
   FROM gp_configuration_history;


ALTER TABLE cbmon.cat_gp_configuration_history OWNER TO gpadmin;

--
-- Name: cat_gp_locks_on_relation; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_locks_on_relation AS
 SELECT gp_locks_on_relation.lorlocktype,
    gp_locks_on_relation.lordatabase,
    gp_locks_on_relation.lorrelname,
    gp_locks_on_relation.lorrelation,
    gp_locks_on_relation.lortransaction,
    gp_locks_on_relation.lorpid,
    gp_locks_on_relation.lormode,
    gp_locks_on_relation.lorgranted,
    gp_locks_on_relation.lorcurrentquery
   FROM gp_toolkit.gp_locks_on_relation;


ALTER TABLE cbmon.cat_gp_locks_on_relation OWNER TO gpadmin;

--
-- Name: cat_gp_locks_on_resqueue; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_locks_on_resqueue AS
 SELECT gp_locks_on_resqueue.lorusename,
    gp_locks_on_resqueue.lorrsqname,
    gp_locks_on_resqueue.lorlocktype,
    gp_locks_on_resqueue.lorobjid,
    gp_locks_on_resqueue.lortransaction,
    gp_locks_on_resqueue.lorpid,
    gp_locks_on_resqueue.lormode,
    gp_locks_on_resqueue.lorgranted,
    gp_locks_on_resqueue.lorwaitevent,
    gp_locks_on_resqueue.lorwaiteventtype
   FROM gp_toolkit.gp_locks_on_resqueue;


ALTER TABLE cbmon.cat_gp_locks_on_resqueue OWNER TO gpadmin;

--
-- Name: cat_gp_param_settings_seg_value_diffs; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_param_settings_seg_value_diffs AS
 SELECT gp_param_settings_seg_value_diffs.psdname,
    gp_param_settings_seg_value_diffs.psdvalue,
    gp_param_settings_seg_value_diffs.psdcount
   FROM gp_toolkit.gp_param_settings_seg_value_diffs;


ALTER TABLE cbmon.cat_gp_param_settings_seg_value_diffs OWNER TO gpadmin;

--
-- Name: cat_gp_partitions; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_partitions AS
 SELECT gp_partitions.schemaname,
    gp_partitions.tablename,
    gp_partitions.partitionschemaname,
    gp_partitions.partitiontablename,
    gp_partitions.parentpartitiontablename,
    gp_partitions.partitiontype,
    gp_partitions.partitionlevel,
    gp_partitions.partitionrank,
    gp_partitions.partitionlistvalues,
    gp_partitions.partitionrangestart,
    gp_partitions.partitionrangeend,
    gp_partitions.partitionisdefault,
    gp_partitions.partitionboundary,
    gp_partitions.parenttablespace,
    gp_partitions.partitiontablespace
   FROM gp_toolkit.gp_partitions;


ALTER TABLE cbmon.cat_gp_partitions OWNER TO gpadmin;

--
-- Name: cat_gp_segment_configuration; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_segment_configuration AS
 SELECT gp_segment_configuration.dbid,
    gp_segment_configuration.content,
    gp_segment_configuration.role,
    gp_segment_configuration.preferred_role,
    gp_segment_configuration.mode,
    gp_segment_configuration.status,
    gp_segment_configuration.port,
    gp_segment_configuration.hostname,
    gp_segment_configuration.address,
    gp_segment_configuration.datadir,
    gp_segment_configuration.warehouseid
   FROM gp_segment_configuration;


ALTER TABLE cbmon.cat_gp_segment_configuration OWNER TO gpadmin;

--
-- Name: cat_gp_stat_activity; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_stat_activity AS
 SELECT gp_stat_activity.gp_segment_id,
    gp_stat_activity.datid,
    gp_stat_activity.datname,
    gp_stat_activity.pid,
    gp_stat_activity.sess_id,
    gp_stat_activity.leader_pid,
    gp_stat_activity.usesysid,
    gp_stat_activity.usename,
    gp_stat_activity.application_name,
    gp_stat_activity.client_addr,
    gp_stat_activity.client_hostname,
    gp_stat_activity.client_port,
    gp_stat_activity.backend_start,
    gp_stat_activity.xact_start,
    gp_stat_activity.query_start,
    gp_stat_activity.state_change,
    gp_stat_activity.wait_event_type,
    gp_stat_activity.wait_event,
    gp_stat_activity.state,
    gp_stat_activity.backend_xid,
    gp_stat_activity.backend_xmin,
    gp_stat_activity.query_id,
    gp_stat_activity.query,
    gp_stat_activity.backend_type,
    gp_stat_activity.rsgid,
    gp_stat_activity.rsgname
   FROM gp_stat_activity;


ALTER TABLE cbmon.cat_gp_stat_activity OWNER TO gpadmin;

--
-- Name: cat_gp_stat_archiver; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_stat_archiver AS
 SELECT gp_stat_archiver.gp_segment_id,
    gp_stat_archiver.archived_count,
    gp_stat_archiver.last_archived_wal,
    gp_stat_archiver.last_archived_time,
    gp_stat_archiver.failed_count,
    gp_stat_archiver.last_failed_wal,
    gp_stat_archiver.last_failed_time,
    gp_stat_archiver.stats_reset
   FROM gp_stat_archiver;


ALTER TABLE cbmon.cat_gp_stat_archiver OWNER TO gpadmin;

--
-- Name: cat_gp_stat_replication; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_stat_replication AS
 SELECT gp_stat_replication.gp_segment_id,
    gp_stat_replication.pid,
    gp_stat_replication.usesysid,
    gp_stat_replication.usename,
    gp_stat_replication.application_name,
    gp_stat_replication.client_addr,
    gp_stat_replication.client_hostname,
    gp_stat_replication.client_port,
    gp_stat_replication.backend_start,
    gp_stat_replication.backend_xmin,
    gp_stat_replication.state,
    gp_stat_replication.sent_lsn,
    gp_stat_replication.write_lsn,
    gp_stat_replication.flush_lsn,
    gp_stat_replication.replay_lsn,
    gp_stat_replication.write_lag,
    gp_stat_replication.flush_lag,
    gp_stat_replication.replay_lag,
    gp_stat_replication.sync_priority,
    gp_stat_replication.sync_state,
    gp_stat_replication.reply_time,
    gp_stat_replication.spill_txns,
    gp_stat_replication.spill_count,
    gp_stat_replication.spill_bytes,
    gp_stat_replication.sync_error
   FROM gp_stat_replication;


ALTER TABLE cbmon.cat_gp_stat_replication OWNER TO gpadmin;

--
-- Name: cat_gp_workfile_entries; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_workfile_entries AS
 SELECT gp_workfile_entries.datname,
    gp_workfile_entries.pid,
    gp_workfile_entries.sess_id,
    gp_workfile_entries.command_cnt,
    gp_workfile_entries.usename,
    gp_workfile_entries.query,
    gp_workfile_entries.segid,
    gp_workfile_entries.slice,
    gp_workfile_entries.optype,
    gp_workfile_entries.size,
    gp_workfile_entries.numfiles,
    gp_workfile_entries.prefix
   FROM gp_toolkit.gp_workfile_entries;


ALTER TABLE cbmon.cat_gp_workfile_entries OWNER TO gpadmin;

--
-- Name: cat_gp_workfile_mgr_used_diskspace; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_workfile_mgr_used_diskspace AS
 SELECT gp_workfile_mgr_used_diskspace.segid,
    gp_workfile_mgr_used_diskspace.bytes
   FROM gp_toolkit.gp_workfile_mgr_used_diskspace;


ALTER TABLE cbmon.cat_gp_workfile_mgr_used_diskspace OWNER TO gpadmin;

--
-- Name: cat_gp_workfile_usage_per_query; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_workfile_usage_per_query AS
 SELECT gp_workfile_usage_per_query.datname,
    gp_workfile_usage_per_query.pid,
    gp_workfile_usage_per_query.sess_id,
    gp_workfile_usage_per_query.command_cnt,
    gp_workfile_usage_per_query.usename,
    gp_workfile_usage_per_query.query,
    gp_workfile_usage_per_query.segid,
    gp_workfile_usage_per_query.size,
    gp_workfile_usage_per_query.numfiles
   FROM gp_toolkit.gp_workfile_usage_per_query;


ALTER TABLE cbmon.cat_gp_workfile_usage_per_query OWNER TO gpadmin;

--
-- Name: cat_gp_workfile_usage_per_segment; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_gp_workfile_usage_per_segment AS
 SELECT gp_workfile_usage_per_segment.segid,
    gp_workfile_usage_per_segment.size,
    gp_workfile_usage_per_segment.numfiles
   FROM gp_toolkit.gp_workfile_usage_per_segment;


ALTER TABLE cbmon.cat_gp_workfile_usage_per_segment OWNER TO gpadmin;

--
-- Name: cat_pg_class; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_pg_class AS
 SELECT pg_class.oid AS cat_oid,
    pg_class.oid,
    pg_class.relname,
    pg_class.relnamespace,
    pg_class.reltype,
    pg_class.reloftype,
    pg_class.relowner,
    pg_class.relam,
    pg_class.relfilenode,
    pg_class.reltablespace,
    pg_class.relpages,
    pg_class.reltuples,
    pg_class.relallvisible,
    pg_class.reltoastrelid,
    pg_class.relhasindex,
    pg_class.relisshared,
    pg_class.relpersistence,
    pg_class.relkind,
    pg_class.relnatts,
    pg_class.relchecks,
    pg_class.relhasrules,
    pg_class.relhastriggers,
    pg_class.relhassubclass,
    pg_class.relrowsecurity,
    pg_class.relforcerowsecurity,
    pg_class.relispopulated,
    pg_class.relreplident,
    pg_class.relispartition,
    pg_class.relisivm,
    pg_class.relrewrite,
    pg_class.relfrozenxid,
    pg_class.relminmxid,
    pg_class.relacl,
    pg_class.reloptions,
    pg_class.relpartbound
   FROM pg_class;


ALTER TABLE cbmon.cat_pg_class OWNER TO gpadmin;

--
-- Name: cat_pg_database; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_pg_database AS
 SELECT pg_database.oid AS cat_oid,
    pg_database.oid,
    pg_database.datname,
    pg_database.datdba,
    pg_database.encoding,
    pg_database.datcollate,
    pg_database.datctype,
    pg_database.datistemplate,
    pg_database.datallowconn,
    pg_database.datconnlimit,
    pg_database.datlastsysoid,
    pg_database.datfrozenxid,
    pg_database.datminmxid,
    pg_database.dattablespace,
    pg_database.datacl
   FROM pg_database;


ALTER TABLE cbmon.cat_pg_database OWNER TO gpadmin;

--
-- Name: cat_pg_locks; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_pg_locks AS
 SELECT pg_locks.locktype,
    pg_locks.database,
    pg_locks.relation,
    pg_locks.page,
    pg_locks.tuple,
    pg_locks.virtualxid,
    pg_locks.transactionid,
    pg_locks.classid,
    pg_locks.objid,
    pg_locks.objsubid,
    pg_locks.virtualtransaction,
    pg_locks.pid,
    pg_locks.mode,
    pg_locks.granted,
    pg_locks.fastpath,
    pg_locks.waitstart,
    pg_locks.mppsessionid,
    pg_locks.mppiswriter,
    pg_locks.gp_segment_id
   FROM pg_locks;


ALTER TABLE cbmon.cat_pg_locks OWNER TO gpadmin;

--
-- Name: cat_pg_namespace; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_pg_namespace AS
 SELECT pg_namespace.oid AS cat_oid,
    pg_namespace.oid,
    pg_namespace.nspname,
    pg_namespace.nspowner,
    pg_namespace.nspacl
   FROM pg_namespace;


ALTER TABLE cbmon.cat_pg_namespace OWNER TO gpadmin;

--
-- Name: cat_pg_resqueue; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_pg_resqueue AS
 SELECT pg_resqueue.oid AS cat_oid,
    pg_resqueue.oid,
    pg_resqueue.rsqname,
    pg_resqueue.rsqcountlimit,
    pg_resqueue.rsqcostlimit,
    pg_resqueue.rsqovercommit,
    pg_resqueue.rsqignorecostlimit
   FROM pg_resqueue;


ALTER TABLE cbmon.cat_pg_resqueue OWNER TO gpadmin;

--
-- Name: cat_pg_roles; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_pg_roles AS
 SELECT pg_roles.oid AS cat_oid,
    pg_roles.rolname,
    pg_roles.rolsuper,
    pg_roles.rolinherit,
    pg_roles.rolcreaterole,
    pg_roles.rolcreatedb,
    pg_roles.rolcanlogin,
    pg_roles.rolreplication,
    pg_roles.rolconnlimit,
    pg_roles.rolenableprofile,
    pg_roles.rolprofile,
    pg_roles.rolaccountstatus,
    pg_roles.rolfailedlogins,
    pg_roles.rolpassword,
    pg_roles.rolvaliduntil,
    pg_roles.rollockdate,
    pg_roles.rolpasswordexpire,
    pg_roles.rolbypassrls,
    pg_roles.rolconfig,
    pg_roles.rolresqueue,
    pg_roles.oid,
    pg_roles.rolcreaterextgpfd,
    pg_roles.rolcreaterexthttp,
    pg_roles.rolcreatewextgpfd,
    pg_roles.rolresgroup
   FROM pg_roles;


ALTER TABLE cbmon.cat_pg_roles OWNER TO gpadmin;

--
-- Name: cat_pg_settings; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_pg_settings AS
 SELECT pg_settings.name,
    pg_settings.setting,
    pg_settings.unit,
    pg_settings.category,
    pg_settings.short_desc,
    pg_settings.extra_desc,
    pg_settings.context,
    pg_settings.vartype,
    pg_settings.source,
    pg_settings.min_val,
    pg_settings.max_val,
    pg_settings.enumvals,
    pg_settings.boot_val,
    pg_settings.reset_val,
    pg_settings.sourcefile,
    pg_settings.sourceline,
    pg_settings.pending_restart
   FROM pg_settings;


ALTER TABLE cbmon.cat_pg_settings OWNER TO gpadmin;

--
-- Name: cat_pg_stat_activity; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_pg_stat_activity AS
 SELECT pg_stat_activity.datid,
    pg_stat_activity.datname,
    pg_stat_activity.pid,
    pg_stat_activity.sess_id,
    pg_stat_activity.leader_pid,
    pg_stat_activity.usesysid,
    pg_stat_activity.usename,
    pg_stat_activity.application_name,
    pg_stat_activity.client_addr,
    pg_stat_activity.client_hostname,
    pg_stat_activity.client_port,
    pg_stat_activity.backend_start,
    pg_stat_activity.xact_start,
    pg_stat_activity.query_start,
    pg_stat_activity.state_change,
    pg_stat_activity.wait_event_type,
    pg_stat_activity.wait_event,
    pg_stat_activity.state,
    pg_stat_activity.backend_xid,
    pg_stat_activity.backend_xmin,
    pg_stat_activity.query_id,
    pg_stat_activity.query,
    pg_stat_activity.backend_type,
    pg_stat_activity.rsgid,
    pg_stat_activity.rsgname
   FROM pg_stat_activity;


ALTER TABLE cbmon.cat_pg_stat_activity OWNER TO gpadmin;

--
-- Name: cat_resgroup_session_level_memory_consumption; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.cat_resgroup_session_level_memory_consumption AS
 SELECT resgroup_session_level_memory_consumption.datname,
    resgroup_session_level_memory_consumption.sess_id,
    resgroup_session_level_memory_consumption.rsgid,
    resgroup_session_level_memory_consumption.rsgname,
    resgroup_session_level_memory_consumption.usename,
    resgroup_session_level_memory_consumption.query,
    resgroup_session_level_memory_consumption.segid,
    resgroup_session_level_memory_consumption.vmem_mb,
    resgroup_session_level_memory_consumption.is_runaway,
    resgroup_session_level_memory_consumption.qe_count,
    resgroup_session_level_memory_consumption.active_qe_count,
    resgroup_session_level_memory_consumption.dirty_qe_count,
    resgroup_session_level_memory_consumption.runaway_vmem_mb,
    resgroup_session_level_memory_consumption.runaway_command_cnt,
    resgroup_session_level_memory_consumption.idle_start
   FROM gp_toolkit.resgroup_session_level_memory_consumption;


ALTER TABLE cbmon.cat_resgroup_session_level_memory_consumption OWNER TO gpadmin;

--
-- Name: catalog_views; Type: TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE TABLE cbmon.catalog_views (
    schemaname text,
    tablename text,
    include_oid boolean
) DISTRIBUTED BY (schemaname, tablename);


ALTER TABLE cbmon.catalog_views OWNER TO gpadmin;

--
-- Name: dbuptime; Type: FOREIGN TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE FOREIGN TABLE cbmon.dbuptime (
    uptime timestamp without time zone
)
SERVER gp_exttable_server
OPTIONS (
    command 'stat -c %y $MASTER_DATA_DIRECTORY/postmaster.pid | awk ''{printf("%s %s",$1,$2)}''',
    delimiter ',',
    encoding '6',
    escape E'\\',
    execute_on 'COORDINATOR_ONLY',
    fill_missing_fields 'true',
    format 'text',
    format_type 't',
    is_writable 'false',
    log_errors 'f',
    "null" E'\\N'
);


ALTER FOREIGN TABLE cbmon.dbuptime OWNER TO gpadmin;

--
-- Name: execute_create_catalog_views; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.execute_create_catalog_views AS
 SELECT c.c AS created
   FROM cbmon.create_catalog_views(false) c(c);


ALTER TABLE cbmon.execute_create_catalog_views OWNER TO gpadmin;

--
-- Name: execute_create_catalog_views_replace; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.execute_create_catalog_views_replace AS
 SELECT c.c AS created
   FROM cbmon.create_catalog_views(true) c(c);


ALTER TABLE cbmon.execute_create_catalog_views_replace OWNER TO gpadmin;

--
-- Name: matview_refresh; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.matview_refresh AS
 SELECT matview_maintenance.matview_maintenance
   FROM cbmon.matview_maintenance() matview_maintenance(matview_maintenance);


ALTER TABLE cbmon.matview_refresh OWNER TO gpadmin;

--
-- Name: matviews; Type: TABLE; Schema: cbmon; Owner: gpadmin
--

CREATE TABLE cbmon.matviews (
    ts timestamp with time zone DEFAULT now() NOT NULL,
    mvname character varying(256) NOT NULL,
    frequency integer NOT NULL
) DISTRIBUTED RANDOMLY;


ALTER TABLE cbmon.matviews OWNER TO gpadmin;

--
-- Name: version; Type: VIEW; Schema: cbmon; Owner: gpadmin
--

CREATE VIEW cbmon.version AS
 SELECT version() AS version;


ALTER TABLE cbmon.version OWNER TO gpadmin;

--
-- Data for Name: alters; Type: TABLE DATA; Schema: cbmon; Owner: gpadmin
--

COPY cbmon.alters (id, summary) FROM stdin;
1014	query stats from segment logs
1012	added for quicker response
1002	sar_reader tables to access todays data
1007	create views providing remote view into catalogs
1016	report database uptime
1013	permit live uptime / load feedback
1000	Initial base schema plus delivering disk performance
1011	add better accessibility to coordinator log
1004	sar_reader -a tables to access all data
1006	able to restore MAT VIEWs periodically
1009	create view providing gp_stat_activity
1010	create view providing version
1008	disk space with total, used, & free
1001	ts_round(timestamp, int) added
1015	add disk device serial
1005	sar_reader -p tables to access yesterdays data
\.


--
-- Data for Name: catalog_views; Type: TABLE DATA; Schema: cbmon; Owner: gpadmin
--

COPY cbmon.catalog_views (schemaname, tablename, include_oid) FROM stdin;
pg_catalog	pg_namespace	t
gp_toolkit	resgroup_session_level_memory_consumption	f
gp_toolkit	gp_workfile_usage_per_segment	f
pg_catalog	pg_settings	f
gp_toolkit	gp_locks_on_resqueue	f
pg_catalog	pg_stat_activity	f
gp_toolkit	gp_workfile_mgr_used_diskspace	f
pg_catalog	pg_resqueue	t
pg_catalog	gp_configuration_history	f
pg_catalog	pg_database	t
gp_toolkit	gp_workfile_usage_per_query	f
pg_catalog	pg_roles	t
gp_toolkit	gp_workfile_entries	f
pg_catalog	gp_stat_activity	f
gp_toolkit	gp_partitions	f
gp_toolkit	gp_locks_on_relation	f
pg_catalog	gp_segment_configuration	f
pg_catalog	pg_class	t
pg_catalog	gp_stat_archiver	f
pg_catalog	gp_stat_replication	f
gp_toolkit	gp_param_settings_seg_value_diffs	f
pg_catalog	pg_locks	f
\.


--
-- Data for Name: matviews; Type: TABLE DATA; Schema: cbmon; Owner: gpadmin
--

COPY cbmon.matviews (ts, mvname, frequency) FROM stdin;
2025-04-25 22:42:04.643786+00	_storage	10080
\.


--
-- Name: alters alters_pkey; Type: CONSTRAINT; Schema: cbmon; Owner: gpadmin
--

ALTER TABLE ONLY cbmon.alters
    ADD CONSTRAINT alters_pkey PRIMARY KEY (id);


--
-- Name: catalog_views catalog_views_schemaname_tablename_key; Type: CONSTRAINT; Schema: cbmon; Owner: gpadmin
--

ALTER TABLE ONLY cbmon.catalog_views
    ADD CONSTRAINT catalog_views_schemaname_tablename_key UNIQUE (schemaname, tablename);


--
-- Name: _storage; Type: MATERIALIZED VIEW DATA; Schema: cbmon; Owner: gpadmin
--

REFRESH MATERIALIZED VIEW cbmon._storage;


--
-- Cloudberry Schema
--

