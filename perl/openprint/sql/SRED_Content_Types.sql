DROP TABLE IF EXISTS SRED_COntent_Types;
CREATE TABLE SRED_Content_Types (
	id	SERIAL,
	name	TEXT,
	PRIMARY KEY (id)
);
insert into sred_content_types (name) values ('Other');
insert into sred_content_types (name) values ('Stock');
insert into sred_content_types (name) values ('Time');

