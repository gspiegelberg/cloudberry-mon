BEGIN; 

INSERT INTO cbmon.alters (id, summary) VALUES
( 1008, 'disk space with total, used, & free' );


CREATE EXTERNAL WEB TABLE cbmon.__disk_space_master(
	hostname    text,
	mntpt       varchar(256),
	total_kbs   bigint,
	used_kbs    bigint,
	avail_kbs   bigint
) EXECUTE 'df -k $GP_SEG_DATADIR | awk -v hn=$(hostname) ''/Filesystem/ {next} {printf("%s,%s,%s,%s,%s\n",hn,$1,$2,$3,$4)}'''
  ON MASTER
  FORMAT 'CSV' (DELIMITER ',');

CREATE EXTERNAL WEB TABLE cbmon.__disk_space_segments(
	hostname    text,
	mntpt       varchar(256),
	total_kbs   bigint,
	used_kbs    bigint,
	avail_kbs   bigint
) EXECUTE 'df -k $GP_SEG_DATADIR | awk -v hn=$(hostname) ''/Filesystem/ {next} {printf("%s,%s,%s,%s,%s\n",hn,$1,$2,$3,$4)}''' ON ALL
  FORMAT 'CSV' (DELIMITER ',');

CREATE VIEW cbmon._disk_space_all AS
SELECT now()::timestamptz AS period, * FROM cbmon.__disk_space_master
UNION
SELECT now()::timestamptz AS period, * FROM cbmon.__disk_space_segments;


COMMIT;

