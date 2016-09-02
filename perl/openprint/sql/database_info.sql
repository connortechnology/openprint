/*
DROP TABLE IF EXISTS database_info;
*/

CREATE TABLE database_info (
    version integer NOT NULL,
    updated_on TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    backup BOOLEAN NOT NULL default false
);


