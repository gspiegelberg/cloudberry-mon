BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1034, 'better sorting' );


CREATE COLLATION num_ignore_punct (
 provider = icu, 
 deterministic = false, 
 locale = 'und-u-ka-shifted-kn'
);


COMMIT;
