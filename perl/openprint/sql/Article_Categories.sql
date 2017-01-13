CREATE TABLE Article_Categories (
	id SERIAL,
	name	TEXT,
	position	INTEGER,
	permalink	text,
	description		TEXT,
	deleted			BOOLEAN NOT NULL default false,
	album_id		INTEGER,
	PRIMARY KEY (id)
);

ALTER TABLE ONLY articles
    ADD CONSTRAINT articles_category_id_fkey FOREIGN KEY (category_id) REFERENCES article_categories(id);
