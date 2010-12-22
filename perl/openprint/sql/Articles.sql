DROP TABLE IF EXISTS Articles;
CREATE TABLE Articles (
	id	SERIAL NOT NULL,
    created_by	INTEGER NOT NULL, FOREIGN KEY (created_by) REFERENCES Users (id),
    created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
    updated_on		TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
    company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
    deleted		BOOLEAN NOT NULL default false,
    published_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
    published	BOOLEAN NOT NULL default false,
    title		TEXT,
    body		TEXT,
	category_id	INTEGER,/* FOREIGN KEY is added in article_categories.sql */
	PRIMARY KEY (id)
);

