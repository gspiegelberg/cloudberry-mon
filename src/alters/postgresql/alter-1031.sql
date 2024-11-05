BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1031, 'added indexes to query_log_counts' );


CREATE INDEX on templates.query_log_counts (period, period_interval);
CREATE INDEX on templates.query_log_counts (period, period_interval, username);
CREATE INDEX on templates.query_log_counts (period, period_interval, loghost);

COMMIT;
