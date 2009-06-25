DROP TABLE IF EXISTS database_info;

CREATE TABLE database_info (
    version integer NOT NULL,
    updated_on timestamp with time zone DEFAULT now() NOT NULL,
    backup boolean
);


