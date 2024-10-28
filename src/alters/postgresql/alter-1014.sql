BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 1014, 'exposes compatibility issues between remote cluster and reporting db');

CREATE TABLE public.alter_requires(
	alter_id     int REFERENCES public.alters(id) ON UPDATE CASCADE ON DELETE CASCADE,
	required     int[] NOT NULL
);

COMMENT ON COLUMN public.alter_requires.alter_id IS 'Reporting database alter id';
COMMENT ON COLUMN public.alter_requires.required IS 'Array of remote alter ids required for this reporting db alter';

INSERT INTO public.alter_requires (alter_id, required) VALUES
( 1014, '{1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010}' );


CREATE OR REPLACE FUNCTION public.cluster_alter_check(
	v_cluster_id  int
) RETURNS TABLE(
	alter_id int,
	cluster_alter_id int,
	status text
) AS $$
DECLARE
	sql   text;
BEGIN
	sql := format(
		'SELECT pg.alter_id, pg.required AS cluster_alter_id
     , (CASE WHEN a.id IS NULL THEN ''Remote cluster missing an alter'' ELSE ''OK'' END)::text AS status
  FROM (SELECT alter_id, unnest(required) AS required FROM public.alter_requires) pg
       LEFT JOIN %s.alters a ON (pg.required = a.id)
  ORDER BY 1, 2',
		public.cluster_metrics_schema(v_cluster_id)
	);

	RETURN QUERY EXECUTE sql;
END;
$$ LANGUAGE 'plpgsql';


COMMIT;
