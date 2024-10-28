BEGIN;


INSERT INTO public.alters(id,summary) VALUES
( 1026, 'add display name to cluster_hosts' );


ALTER TABLE public.cluster_hosts
  ADD COLUMN display_name text;

ALTER TABLE public.cluster_hosts
  ADD CONSTRAINT display_name_unq UNIQUE(cluster_id,display_name);

COMMIT;
