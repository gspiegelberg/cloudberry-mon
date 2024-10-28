BEGIN;

INSERT INTO cbmon.alters (id, summary) VALUES
( 1001, 'ts_round(timestamp, int) added');


CREATE OR REPLACE FUNCTION ts_round( timestamp without time zone, INT ) RETURNS TIMESTAMP WITHOUT TIME ZONE AS $$
  SELECT 'epoch'::timestamp + '1 second'::INTERVAL * ( $2 * ( EXTRACT( epoch FROM $1 )::INT / $2 ) );
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION ts_round( timestamp with time zone, INT ) RETURNS TIMESTAMP WITH TIME ZONE AS $$
  SELECT ('epoch'::timestamp + '1 second'::INTERVAL * ( $2 * ( EXTRACT( epoch FROM $1 )::INT / $2 ) ))::timestamptz;
$$ LANGUAGE SQL STABLE;

COMMIT;

