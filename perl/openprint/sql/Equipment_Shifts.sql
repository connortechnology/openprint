CREATE TABLE equipment_shifts (
	id			SERIAL NOT NULL,
    equipment_id integer NOT NULL,
    starttime time without time zone NOT NULL,
    duration interval NOT NULL,
    name text NOT NULL,
	PRIMARY KEY (id)
);
