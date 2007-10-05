
CREATE SEQUENCE UserGroup_id_seq;

CREATE TABLE UserGroup (
	id	INTEGER NOT NULL default nextval('User_Group_id_seq'),
	name	TEXT,
	PRIMARY KEY (id)
);
