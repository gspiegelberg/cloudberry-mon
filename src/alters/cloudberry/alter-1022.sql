BEGIN;

INSERT INTO cbmon.alters (id,summary) VALUES
( 1021, 'monitoring of pxf' );

CREATE FOREIGN TABLE cbmon.pxf_cluster_status (
	status text
) SERVER gp_exttable_server
  OPTIONS (
	command 'source /home/gpadmin/.bashrc; pxf cluster status',
	escape E'\\',
	execute_on 'COORDINATOR_ONLY',
	format 'text',
	format_type 't',
	is_writable 'false',
	log_errors 'f',
	"null" E'\\N'
);


CREATE EXTERNAL WEB TABLE cbmon.__pxf_status_segments(
	hostname text,
	period timestamptz,
	path text
) EXECUTE 'printf "%s,%s," "$(hostname)" "$(date)"; source /home/gpadmin/.bashrc; pxf status | grep -v Checking | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g"' ON HOST
  FORMAT 'CSV' ( DELIMITER ',' );

CREATE EXTERNAL WEB TABLE cbmon.__pxf_status_master(
	hostname text,
	period timestamptz,
	path text
) EXECUTE 'printf "%s,%s," "$(hostname)" "$(date)"; source /home/gpadmin/.bashrc; pxf status | grep -v Checking | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g"' ON COORDINATOR
  FORMAT 'CSV' ( DELIMITER ',' );

CREATE VIEW cbmon.pxf_status AS
SELECT * FROM cbmon.__pxf_status_segments
UNION ALL
SELECT * FROM cbmon.__pxf_status_master;


CREATE EXTERNAL WEB TABLE cbmon.__pxf_version_segments(
	hostname text,
	period timestamptz,
	path text
) EXECUTE 'printf "%s,%s," "$(hostname)" "$(date)"; source /home/gpadmin/.bashrc; pxf version' ON HOST
  FORMAT 'CSV' ( DELIMITER ',' );

CREATE EXTERNAL WEB TABLE cbmon.__pxf_version_master(
	hostname text,
	period timestamptz,
	path text
) EXECUTE 'printf "%s,%s," "$(hostname)" "$(date)"; source /home/gpadmin/.bashrc; pxf version' ON COORDINATOR
  FORMAT 'CSV' ( DELIMITER ',' );

CREATE VIEW cbmon.pxf_version AS
SELECT * FROM cbmon.__pxf_version_segments
UNION ALL
SELECT * FROM cbmon.__pxf_version_master;


CREATE EXTERNAL WEB TABLE cbmon.__pxf_which_segments(
	hostname text,
	period timestamptz,
	path text
) EXECUTE 'printf "%s,%s," "$(hostname)" "$(date)"; source /home/gpadmin/.bashrc; which pxf' ON HOST
  FORMAT 'CSV' ( DELIMITER ',' );

CREATE EXTERNAL WEB TABLE cbmon.__pxf_which_master(
	hostname text,
	period timestamptz,
	path text
) EXECUTE 'printf "%s,%s," "$(hostname)" "$(date)"; source /home/gpadmin/.bashrc; which pxf' ON COORDINATOR
  FORMAT 'CSV' ( DELIMITER ',' );

CREATE VIEW cbmon.pxf_which AS
SELECT * FROM cbmon.__pxf_which_segments
UNION ALL
SELECT * FROM cbmon.__pxf_which_master;


CREATE EXTERNAL WEB TABLE cbmon.__pxf_procs_segments(
	hostname text,
	period timestamptz,
	proc_count int
) EXECUTE 'printf "%s,%s," "$(hostname)" "$(date)"; ps -ef | grep "[j]ava.*pxf" | wc -l' ON HOST
  FORMAT 'CSV' ( DELIMITER ',' );

CREATE EXTERNAL WEB TABLE cbmon.__pxf_procs_master(
	hostname text,
	period timestamptz,
	proc_count int
) EXECUTE 'printf "%s,%s," "$(hostname)" "$(date)"; ps -ef | grep "[j]ava.*pxf" | wc -l' ON COORDINATOR
  FORMAT 'CSV' ( DELIMITER ',' );

CREATE VIEW cbmon.pxf_procs AS
SELECT * FROM cbmon.__pxf_procs_segments
UNION ALL
SELECT * FROM cbmon.__pxf_procs_master;

COMMIT;
