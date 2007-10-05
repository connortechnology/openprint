DROP SEQUENCE Paper_Allocation_id_seq;
CREATE SEQUENCE Paper_Allocation_id_seq;

DROP TABLE Paper_Allocations;
CREATE TABLE Paper_Allocations (
	id			INTEGER NOT NULL default nextval('Paper_Allocation_id_seq'),
	paper_id	INTEGER, FOREIGN KEY (paper_id) REFERENCES Papers (id),
	skid_id		INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES Skids (id),
	quantity	INTEGER NOT NULL,
	project_id	INTEGER NOT NULL, FOREIGN KEY (project_id) REFERENCES tbl_Projects (Index),
	operator_id	INTEGER NOT NULL, FOREIGN KEY (operator_id) REFERENCES Users (Index),
	created_on	timestamp with time zone default NOW()
);

CREATE INDEX Paper_Allocations_paper_id_Index ON Paper_Allocations (paper_id);
CREATE INDEX Paper_Allocations_project_id_Index ON Paper_Allocations (paper_id);
