DROP TABLE IF EXISTS materials;
DROP SEQUENCE IF EXISTS materials_id_seq;

CREATE TABLE Materials (
	id				SERIAL,
	category_id		INTEGER, FOREIGN KEY (category_id) REFERENCES Material_Categories (id),
	name			TEXT,
	description		TEXT,
    supplier_id		INTEGER, FOREIGN KEY (supplier_id) REFERENCES Companies (id),
	taxexempt1		char(1) NOT NULL DEFAULT 'N',
	taxexempt2		char(1) NOT NULL DEFAULT 'N',
	PRIMARY KEY (id)
);
 
CREATE INDEX materialis_name_idx ON materials (name);
