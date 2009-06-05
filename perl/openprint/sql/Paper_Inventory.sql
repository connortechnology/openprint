
DROP TABLE Paper_Inventory;

CREATE TABLE Paper_Inventory (
	id			SERIAL NOT NULL,
	Skid_id		INTEGER, FOREIGN KEY (skid_id) REFERENCES Skids (id),
	Paper_id	INTEGER, FOREIGN KEY (paper_id) REFERENCES Papers (id),
	User_id		INTEGER, FOREIGN KEY (User_id) REFERENCES Users (index),
	PO_Id		INTEGER NOT NULL, FOREIGN KEY (PO_Id) REFERENCES Paper_Purchase_Orders (Id),
	InStock		INTEGER,
	Updated_on	TIMESTAMP WITH TIME ZONE default NOW(),
	delta		INTEGER,
	Comment		TEXT,
	docket		INTEGER,
	PRIMARY KEY (id)
);

CREATE INDEX Paper_Inventory_skid_id_id ON Paper_Inventory (skid_id);
CREATE INDEX Paper_Inventory_paper_id_id ON Paper_Inventory (paper_id);
