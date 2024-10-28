BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1020, 'Reordering load function priority');

/**
 * SAR metrics
 */
UPDATE public.load_functions
   SET priority = 80
 WHERE tablename IN ('ldavg', 'cpu', 'disk', 'network_dev', 'network_errors', 'network_sockets', 'network_softproc', 'swap');

COMMIT;
