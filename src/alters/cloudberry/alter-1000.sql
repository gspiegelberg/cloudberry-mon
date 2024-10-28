BEGIN;

CREATE SCHEMA IF NOT EXISTS cbmon;

CREATE TABLE cbmon.alters(
	id	int PRIMARY KEY,
	summary text NOT NULL
);

INSERT INTO cbmon.alters (id, summary) VALUES
( 1000, 'Initial base schema plus delivering disk performance');

COMMIT;
