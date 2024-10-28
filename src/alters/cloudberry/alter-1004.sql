BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1004, 'sar_reader -a tables to access all data');


CREATE EXTERNAL WEB TABLE cbmon.__ldavg_segments_all(
	hostname text,
	period   timestamptz,
	runq_sz  float,
	plist_sz float,
	ldavg_1  float,
	ldavg_5  float,
	ldavg_15 float,
	blocked  float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-q"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__ldavg_master_all(
        hostname text,
        period   timestamptz,
	runq_sz  float,
	plist_sz float,
	ldavg_1  float,
	ldavg_5  float,
	ldavg_15 float,
	blocked  float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-q"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_ldavg_all AS
SELECT * FROM cbmon.__ldavg_segments_all
UNION
SELECT * FROM cbmon.__ldavg_master_all;


CREATE EXTERNAL WEB TABLE cbmon.__disk_segments_all(
	hostname text,
	period   timestamptz,
	device   text,
	tps      float,
	rkbs     float,
	wkbs     float,
	areq_sz  float,
	aqu_sz   float,
	await    float,
	svctm    float,
	util_pct float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-d"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

-- Because ON HOST = on all segment hosts, ie. does not include master
CREATE EXTERNAL WEB TABLE cbmon.__disk_master_all(
        hostname text,
        period   timestamptz,
        device   text,
        tps      float,
        rkbs     float,
        wkbs     float,
        areq_sz  float,
        aqu_sz   float,
        await    float,
        svctm    float,
        util_pct float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-d"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_disk_all AS
SELECT * FROM cbmon.__disk_segments_all
UNION
SELECT * FROM cbmon.__disk_master_all;


CREATE EXTERNAL WEB TABLE cbmon.__cpu_segments_all(
	hostname text,
	period   timestamptz,
	CPU      varchar(4),
	usr      float,
	nice     float,
	sys      float,
	iowait   float,
	steal    float,
	irq      float,
	soft     float,
	guest    float,
	gnice    float,
	idle     float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-P ALL -u ALL"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__cpu_master_all(
        hostname text,
        period   timestamptz,
	CPU      varchar(4),
	usr      float,
	nice     float,
	sys      float,
	iowait   float,
	steal    float,
	irq      float,
	soft     float,
	guest    float,
	gnice    float,
	idle     float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-P ALL -u ALL"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_cpu_all AS
SELECT * FROM cbmon.__cpu_segments_all
UNION
SELECT * FROM cbmon.__cpu_master_all;


CREATE EXTERNAL WEB TABLE cbmon.__memory_segments_all(
	hostname      text,
	period        timestamptz,
	kbmemfree     int,
	kbavail       int,
	kbmemused     int,
	memused_pct   float,
	kbbuffers     int,
	kbcached      int,
	kbcommit      int,
	commit_pct    float,
	kbactive      int,
	kbinact       int,
	kbdirty       int,
	kbanonpg      int,
	kbslab        int,
	kbkstack      int,
	kbpgtbl       int,
	kbvmused      int
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-r ALL"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__memory_master_all(
        hostname      text,
        period        timestamptz,
	kbmemfree     int,
	kbavail       int,
	kbmemused     int,
	memused_pct   float,
	kbbuffers     int,
	kbcached      int,
	kbcommit      int,
	commit_pct    float,
	kbactive      int,
	kbinact       int,
	kbdirty       int,
	kbanonpg      int,
	kbslab        int,
	kbkstack      int,
	kbpgtbl       int,
	kbvmused      int
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-r ALL"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_memory_all AS
SELECT * FROM cbmon.__memory_segments_all
UNION
SELECT * FROM cbmon.__memory_master_all;


CREATE EXTERNAL WEB TABLE cbmon.__swap_segments_all(
	hostname      text,
	period        timestamptz,
	kbswpfree     int,
	kbswpused     int,
	swpused_pct   float,
	kbswpcad      int,
	swpcad_pct    float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-S"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__swap_master_all(
        hostname      text,
        period        timestamptz,
	kbswpfree     int,
	kbswpused     int,
	swpused_pct   float,
	kbswpcad      int,
	swpcad_pct    float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-S"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_swap_all AS
SELECT * FROM cbmon.__swap_segments_all
UNION
SELECT * FROM cbmon.__swap_master_all;


CREATE EXTERNAL WEB TABLE cbmon.__network_dev_segments_all(
        hostname      text,
        period        timestamptz,
        iface         text,
        rxpck_psec    float,
        txpck_psec    float,
        rxkb_psec     float,
        txkb_psec     float,
        rxcmp_psec    float,
        txcmp_psec    float,
        rxmcst_psec   float,
        ifutil_pct    float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-n DEV"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__network_dev_master_all(
        hostname      text,
        period        timestamptz,
	iface         text,
	rxpck_psec    float,
	txpck_psec    float,
	rxkb_psec     float,
	txkb_psec     float,
	rxcmp_psec    float,
	txcmp_psec    float,
	rxmcst_psec   float,
	ifutil_pct    float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-n DEV"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_network_dev_all AS
SELECT * FROM cbmon.__network_dev_segments_all
UNION
SELECT * FROM cbmon.__network_dev_master_all;


CREATE EXTERNAL WEB TABLE cbmon.__network_errors_segments_all(
	hostname    text,
	period      timestamptz,
	iface       text,
	rxerr_psec  float,
	txerr_psec  float,
	coll_psec   float,
	rxdrop_psec float,
	txdrop_psec float,
	txcarr_psec float,
	rxfram_psec float,
	rxfifo_psec float,
	txfifo_psec float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-n EDEV"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__network_errors_master_all(
        hostname text,
        period   timestamptz,
	iface       text,
	rxerr_psec  float,
	txerr_psec  float,
	coll_psec   float,
	rxdrop_psec float,
	txdrop_psec float,
	txcarr_psec float,
	rxfram_psec float,
	rxfifo_psec float,
	txfifo_psec float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-n EDEV"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_network_errors_all AS
SELECT * FROM cbmon.__network_errors_segments_all
UNION
SELECT * FROM cbmon.__network_errors_master_all;


CREATE EXTERNAL WEB TABLE cbmon.__network_sockets_segments_all(
	hostname text,
	period   timestamptz,
	totsck   int,
	tcpsck   int,
	udpsck   int,
	rawsck   int,
	ip_frag  int,
	tcp_tw   int
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-n SOCK"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__network_sockets_master_all(
        hostname text,
        period   timestamptz,
	totsck   int,
	tcpsck   int,
	udpsck   int,
	rawsck   int,
	ip_frag  int,
	tcp_tw   int
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-n SOCK"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_network_sockets_all AS
SELECT * FROM cbmon.__network_sockets_segments_all
UNION
SELECT * FROM cbmon.__network_sockets_master_all;


CREATE EXTERNAL WEB TABLE cbmon.__network_softproc_segments_all(
	hostname     text,
	period       timestamptz,
	cpu          text,
	total_psec   float,
	dropd_psec   float,
	squeezd_psec float,
	rx_rps_psec  float,
	flw_lim_psec float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-n SOFT"' ON HOST
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE EXTERNAL WEB TABLE cbmon.__network_softproc_master_all(
        hostname     text,
        period       timestamptz,
	cpu          text,
	total_psec   float,
	dropd_psec   float,
	squeezd_psec float,
	rx_rps_psec  float,
	flw_lim_psec float
) EXECUTE '/usr/local/cbmon/bin/sar_reader -a -S "-n SOFT"' ON MASTER
  FORMAT 'TEXT' (DELIMITER ',' FILL MISSING FIELDS);

CREATE VIEW cbmon._raw_network_softproc_all AS
SELECT * FROM cbmon.__network_softproc_segments_all
UNION
SELECT * FROM cbmon.__network_softproc_master_all;


COMMIT;

/*
-bBdFHqSuvwWy -I SUM -I ALL -m ALL  -n ALL -r ALL -u ALL -P ALL

network per device packet & bytes in/out -n DEV
12:00:37 AM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil

network per device errors in/out -n EDEV
12:00:37 AM     IFACE   rxerr/s   txerr/s    coll/s  rxdrop/s  txdrop/s  txcarr/s  rxfram/s  rxfifo/s  txfifo/s

-n SOCK ipv4 sockets
12:00:37 AM    totsck    tcpsck    udpsck    rawsck   ip-frag    tcp-tw

-n SOFT software-based net processes
12:00:37 AM     CPU   total/s   dropd/s squeezd/s  rx_rps/s flw_lim/s


 */

