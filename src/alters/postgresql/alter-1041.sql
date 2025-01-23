BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1041, 'adding more catalog views' );


-- For future clusters
INSERT INTO public.extra_tables(remote_schema, remote_table) VALUES
('cbmon', 'cat_gp_stat_replication'),
('cbmon', 'cat_gp_stat_archiver');


-- Add catalog views to existing clusters
DO $$
DECLARE
	cid int;
	cattbl text;
BEGIN
	FOR cid IN SELECT id FROM public.clusters WHERE enabled
	LOOP
		FOR cattbl IN SELECT tbl FROM (VALUES
		('gp_stat_replication'),
		('gp_stat_archiver')) v(tbl)
		LOOP
			PERFORM * FROM public.create_fdw_table(
				cid, 'pg_catalog', cattbl, false, true, false
			);
		END LOOP;
	END LOOP;
END $$;


CREATE OR REPLACE FUNCTION public.get_walfile_diff(v_curr_wal text, v_old_wal text)
RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE
        wal_diff numeric;
        x numeric;
        y numeric;
        z numeric;
        y1 numeric;
        y2 numeric;
        z1 numeric;
        z2 numeric;
BEGIN
        /** Returns number of wals between current and old not counting current */
        IF length(v_curr_wal) != 24 OR length(v_old_wal) != 24 THEN
                RAISE EXCEPTION 'Invalid wal file length';
        END IF;

        x := ABS(('x' || SUBSTRING(v_curr_wal, 1, 8))::bit(32)::int - ('x' || SUBSTRING(v_old_wal, 1, 8))::bit(32)::int);

        y1 := ('x' || SUBSTRING(v_curr_wal, 9, 8))::bit(32)::int;
        y2 := ('x' || SUBSTRING(v_old_wal, 9, 8))::bit(32)::int;

        z1 := ('x' || SUBSTRING(v_curr_wal, 17))::bit(32)::int;
        z2 := ('x' || SUBSTRING(v_old_wal, 17))::bit(32)::int;

        y := ABS( y1 - y2 );
        IF y1 > y2 AND z1 > z2 THEN
            wal_diff := ( x + y * 64 + z1 - z2 );
        ELSIF y1 > y2 AND z1 <= z2 THEN
            wal_diff := ( x + y * 64 + z1 - z2 );
        ELSE
            wal_diff := ( x + y + z1 - z2 );
        END IF;

        RETURN wal_diff;
END;
$$ IMMUTABLE;


CREATE OR REPLACE FUNCTION public.get_walfile_diff(v_curr_lsn pg_lsn, v_old_lsn pg_lsn)
RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE
	curr_wal text;
	old_wal text;
BEGIN
	curr_wal = pg_walfile_name(v_curr_lsn);
	old_wal = pg_walfile_name(v_old_lsn);

	RETURN public.get_walfile_diff(curr_wal, old_wal);
END;
$$ IMMUTABLE;

/**
 * Example how to use:
SELECT * FROM (
SELECT gp_segment_id
     , client_addr
     , state
     , public.get_walfile_diff(sent_lsn, write_lsn) AS write_lag
     , public.get_walfile_diff(sent_lsn, flush_lsn) AS flush_lag
     , public.get_walfile_diff(sent_lsn, replay_lsn) AS replay_lag
  FROM gp_stat_replication
) x
 WHERE write_lag + flush_lag + replay_lag > 0
 ORDER BY 6 DESC;
 */


COMMIT;
