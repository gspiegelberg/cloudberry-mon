BEGIN;

DO $$
BEGIN
	RAISE NOTICE 'Be sure to ''sudo systemctl stop cbmon_summaries'' and disable';
END $$;

INSERT INTO public.alters (id, summary) VALUES
( 1064, 'move public.gen_query_log_counts1 to load_functions' );

INSERT INTO public.load_functions
 ( funcname, tablename, fdwtable, priority, frequency, enabled )
SELECT funcname, tablename, fdwtable, priority, frequency, enabled
  FROM public.gen_functions
 WHERE funcname = 'public.gen_query_log_counts1';

DELETE FROM public.gen_functions
 WHERE funcname = 'public.gen_query_log_counts1';

COMMIT;
