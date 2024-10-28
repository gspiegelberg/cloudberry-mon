BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1009, 'pivot function' );

CREATE EXTENSION IF NOT EXISTS tablefunc;

COMMIT;
