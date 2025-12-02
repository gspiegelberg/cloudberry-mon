# Troubleshooting Guide

## Cluster hostnames

Execution of ```public.create_cluster()``` populates ```public.cluster_hosts``` with what is found in ```pg_catalog.gp_segment_configuration.hostname```.
That value may not be the same as what the command ```hostname``` on the host itself returns.
End result is many load functions may not work as expected or may not work at all.
To resolve this ```public.cluster_hosts.hostname``` MUST be set to the actual hostname of segment hosts.

2025-12-02 - Work in progress to address in ```public.create_cluster()```.

## Cluster attribute adjustments

Some provided dashboards require knowledge of segment host and segment host core counts.
After executing ```public.create_cluster()```, add this information to ```public.cluster_attribs```.

Replace X with appropriate cluster id.
```
psql cbmon
DELETE FROM public.cluster_attribs WHERE cluster_id = X;

INSERT INTO public.cluster_attribs (cluster_id, domain, value) VALUES
( X, 'segment.host.cores', 60 ), 
( X, 'segment.hosts',      48 );
```

## Load function not producing results

All work is done via procedure ```public.load()```.
If data is not present in a metrics table or metrics table does not exist, check ```public.load_status```.

```
SELECT * FROM public.load_status WHERE summary <> 'success' ORDER BY created DESC;
```
