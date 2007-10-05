DROP SEQUENCE tbl_epages_lngid_seq;
DROP TABLE tbl_epages;

CREATE SEQUENCE tbl_epages_lngid_seq;
CREATE TABLE "tbl_epages" (
    "lngid" integer NOT NULL default nextval('tbl_epages_lngid_seq'),
    "stripaddress" character(15) NOT NULL,
    "strpagetitle" text,
    "strmetadescription" text,
    "strmetakeywords" text,
    "strbodytext" text,
    CONSTRAINT "tbl_epages_pkey" PRIMARY KEY ("lngid")
);
