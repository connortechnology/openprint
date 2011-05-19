DROP TABLE IF EXISTS Privacy_Groups;

CREATE TABLE Privacy_Groups (
	id	SERIAL,
	name	TEXT,

	public	boolean NOT NULL default false,
	shared	boolean NOT NULL default false,
	private boolean NOT NULL default false,
	PRIMARY KEY (id)
);

INSERT  INTO Privacy_Groups ( name, public, shared, private ) values ( 'Public', true, true, true );
INSERT  INTO Privacy_Groups ( name, public, shared, private ) values ( 'Shared', false, true, true );
INSERT  INTO Privacy_Groups ( name, public, shared, private ) values ( 'Private', false, false, true );
