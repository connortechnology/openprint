
CREATE TABLE materials (
	id				SERIAL,
	category_id		INTEGER, FOREIGN KEY (category_id) REFERENCES Material_Categories (id),
	name			TEXT,
	description		TEXT,
    supplier_id		INTEGER, FOREIGN KEY (supplier_id) REFERENCES Companies (id),
	taxexempt1		char(1) NOT NULL DEFAULT 'N',
	taxexempt2		char(1) NOT NULL DEFAULT 'N',
	activity_code	TEXT,
	servicetype_id	INTEGER, FOREIGN KEY (servicetype_id) REFERENCES service_types (id),
	PRIMARY KEY (id)
);
 
CREATE INDEX materials_name_idx ON materials (name);
create index materials_servicetype_id_idx on Materials(servicetype_id);
