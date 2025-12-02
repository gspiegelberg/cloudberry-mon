# Development Guide

## Conventions

- **alters** are sql files used to add features and capabilities (or fix either)
- **cluster** refers to configured MPP clusters in table ```public.clusters```
- **load function** refers to records in ```public.load_functions``` detailing when functions are to be called
- **metrics** refers to a metrics table found in metrics schema ```metrics_X``` schema where X is the unique id in ```public.clusters.id```
- **metrics schema** is a schema specific to a cluster containing all foreign tables and metrics tables
- **template** are tables found in schema ```templates```


## About template tables

Template tables are used to automatically create metrics tables for a cluster.
Since pg_partman manages metric table partitions and partitions are range based on time, all MUST have ```hostname text, period timestamp with time zone NOT NULL``` columns.
Ideally, an index is also on metric template tables.
Additional indexes may be created though I've seen little benefit.
Template tables **should NOT** contain data.
 
## Adding new metrics

There are 8 steps to adding addition metrics.

- Create MPP-side alter that:
  - Adds a record to ```cbmon.alters``` with id value next in sequence
  - Adds all views, tables, external tables necessary to gather the metrics desired
- Create PostgreSQL-side alter with the following:
  - Unique alter id that is next in sequence for ```public.alters```
  - Create a template table
  - Create an index on the template table
  - Create the load function which will pull data using a foreign table specific to the cluster (more later)
  - Create the record in ```public.load_functions``` for the new load function
  - Execute an anonymous code block adding those foreign tables to existing cluster metrics schemas

Easy, right?

### Example

#### MPP Alter

We want to expose the catalog ```pg_catalog.pg_namespace``` (already done but bear with me).

First in ```src/alters/cloudberry/``` we create a file alter-X.sql where X is the 1 + the maximum value of alters in that directory. 
If alter-1199.sql is the highest then this alter will be 1200 or alter-1200.sql.
The file will then begin as follows:
```
BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1200, 'adding pg_catalog.pg_namespace' );
```

Exposing catalogs will require a view for a variety of reasons so let's give it a different name: ```cat_pg_namespace```.
Why?
When querying you may accidentally specify ```pg_namespace``` without the schema and get the wrong results.
There were other issues with identically named relations though each were in a different schame.
Also, it is beneficial and sometimes required to rename columns including ```oid``` and ```gp_segment_id```.
So here is the view for the alter:
```
CREATE VIEW cbmon.cat_pg_namespace AS
 SELECT 'mdw' AS hostname
      , clock_timestamp() AS period
      , pg_namespace.oid AS cat_oid
      , pg_namespace.nspname
      , pg_namespace.nspowner
      , pg_namespace.nspacl
   FROM pg_catalog.pg_namespace;
```

Don't forget in our alter to COMMIT.
```
COMMIT;
```

That's really it.

#### PostgreSQL Alter

This one is a little more involved but not terrible.
Like MPP-side alter, determine the next alter id to use but look to directory ```src/alters/postgresql/``` instead.
The next available here will be 3210 therefore the file will be called ```alter-3210.sql```.

Like before though different schema, create a record for the alters table in ```public.alters```.
```
BEGIN;

INSERT INTO public.alters (id, summary) VALUES
( 3210, 'postgresql-side addition of pg_namespace');
```

Next is template table. It can have the same column definition as MPP-side alter, fewer columns or more depending on what is going on.
We'll stick to having the same definition but rename.
```
CREATE TABLE templates.schemas(
  hostname text,
  period   timestamp with time zone NOT NULL,
  nsp_oid  oid,
  nspname  name,
  nspowner oid,
  nspacl   aclitem[]
);
```
Fortunately, types are the same in PostgreSQL as they are in Greenplum & co.

A bit overkill for this example but we'll create an index anyways.
```
CREATE INDEX ON templates.schemas (hostname, period);
```

As mentioned, load function's must take ```int, boolean``` as parameters. Convention is to name them ```v_cluster_id, v_prime``` respectivitely but it's more of a guideline than a rule.
Purpose of ```v_cluster_id``` is to tell the load function which cluster it is working on.
If the metric is an in-database log and say metrics collection just been added then you may want the entire history, right?
That is the purpose of ```v_prime```.
Normal pulling of data should be light & minimal but in special cases such as the first run the load function may
test if ```v_prime``` is true and pull data going back days or even weeks.
Load functions MUST also return VOID.

For this example, it will be kept simple with some extra to illustrate.
```
CREATE OR REPLACE FUNCTION public.load_pg_namespace(
  v_cluster_id int,
  v_prime boolean
) RETURNS VOID AS $$
DECLARE
  cmetrics text;
  sql      text;
BEGIN
  cmetrics := public.cluster_metrics_schema( v_cluster_id );
  sql := format(
    'INSERT INTO %s.schemas SELECT * FROM %s.cat_pg_namespace'
    , cmetrics, cmetrics
  );
  EXECUTE sql;
  RETURN;
END;
$$ LANGUAGE 'plpgsql';
```

There are a few handy functions available to determine metrics schemas and derive cluster id's from schema names.
- ```public.cluster_metrics_schema( int )``` returns the cluster metrics schema name
- ```public.cluster_id_from_schema( text )``` returns cluster id from a cluster metrics schema name
The latter is handy when putting together dashboards.

My preferences are obvious so function could be more brief but wanted to be explicit.

Next is creation of a record in ```public.load_functions``` for our new load function.
```
INSERT INTO public.load_functions (funcname, tablename, priority, enabled, fdwtable, frequency)
VALUES ( 'public.load_pg_namespace', 'schemas', 100, true, 'cat_pg_namespace', 60 );
```
Some explaination:
- ```funcname``` is obviously the load function name
- ```tablename``` is the template and metrics table names (which should be identical)
- ```priority``` is 0 to 100 where 100 is a higher priority
- ```enabled``` ought to be obvious
- ```fdwtable``` is name of the foreign table required
- ```frequency``` is how often function should execute
  - It is actually modulo of minute of the week (see ```public.minute_of_week()```
  - If you wanted it to run every day once per day, set to 1440 (1440 minutes in a day)
  - Above example is once / hour
  - It is imperfect and will document this discrepancy probably in an Issue

That fun step is writing the anonymous code block.
Why?
Adding an alter adds functionality / features to future clusters but what about existing clusters?
This step addresses exactly that adding foreign tables to tables / views that were not present when cluster was first created.

For this example, it is as follows:
```
DO $$
DECLARE
	cserver  text;
	cmetrics text;
	logtbl   text;
	alter_applied boolean;
BEGIN
	FOR cserver, cmetrics, logtbl IN
		SELECT public.cluster_server(c.id), public.cluster_metrics_schema(c.id), v.logtbl
		FROM public.clusters c, (VALUES ('cbmon.cat_pg_namespace') ) AS v(logtbl)
		 WHERE c.enabled
	LOOP
		EXECUTE format('SELECT id = 1200 FROM %s.alters WHERE id = 1200', cmetrics) INTO alter_applied;
		IF NOT alter_applied THEN
			RAISE EXCEPTION 'Cluster % does not have alters/cloudberry/alter-1018.sql applied', public.
cluster_id_from_schema(cmetrics);
		END IF;

		EXECUTE format(
		'IMPORT FOREIGN SCHEMA cbmon LIMIT TO ( %s ) FROM SERVER %s INTO %s'
		, logtbl, cserver, cmetrics
		);
	END LOOP;
END $$;
```

Explanation:
- We're looping through all enabled clusters
- Checking each clusters foreign alters table to ensure our MPP-side alter is loaded
- Finally importing those tables / views provided as listed in VALUES

And then...
```
COMMIT;
```

Check your code to a branch, test, and create a pull request!

Thanks!
