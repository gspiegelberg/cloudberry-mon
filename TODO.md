Known issues:
========================================================================

 * Certain jobs take longer than others to load. Specifically, "cpu" load function
   can easily make the once/minute data gathering skew to once/10 minutes. Intention
   is to replace loader->CALL load() with loader->AMQP->RabbitMQ->consumer->load
   single metric type.

 * Test RHEL 9 variants 
   * Adjust install instructions where needed
   * Modify sar_reader to handle sysstat 12 output
   * Test other src/bin scripts adjusting where needed

To Do's
========================================================================

 * Build RPM or easier delivery

 * Implement rules to effect change on remote cluster such as "terminate
   idle in transaction" sessions over X minutes

 * Implement ability to view query EXPLAIN

 * Create a cbmon extension running in segment bgworker to capture live query execution
   statistics and dashboard viz to show live per slice resource consumption, relations
   used and historical query information

 * cbmon/etc/config overloaded & used by both Cloudberry & PostgreSQL side
   Separate into different files

Parallel Loader specific to do's:
========================================================================
* Pull duplicate portions of code out of parallel_loader, send_loader_request and stop_loader
  placing in common classes for ease of maintenance
* Permit configuration file environment variable for easier cli execution
* Move public.load_functions.enabled into a cluster-load_function relationship table
  permitting per cluster enabling/disabling of load_functions
* Move gen_functions into load_functions. Shouldn't be a problem and will rid the need
  for public.gen_functions
* Smoother exit from parallel_loader with option to wait for any executing workers to finish
