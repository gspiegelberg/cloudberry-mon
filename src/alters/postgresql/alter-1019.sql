BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1019, 'more room for error messages');

ALTER TABLE public.load_status
ALTER COLUMN summary TYPE text;


COMMIT;
