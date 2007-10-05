
DROP TABLE Paper_Inventory;

CREATE TABLE Paper_Inventory (
	Skid_id		INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES Skids (id),
	Paper_id	INTEGER NOT NULL, FOREIGN KEY (paper_id) REFERENCES Papers (id),
	User_id		INTEGER NOT NULL, FOREIGN KEY (User_id) REFERENCES Users (index),
	PO_Id		INTEGER NOT NULL, FOREIGN KEY (PO_Id) REFERENCES Paper_Purchase_Orders (Id),
	InStock		INTEGER,
	UpdateTime	TIMESTAMP,
	delta		INTEGER,
	Comment		TEXT
);

CREATE INDEX Paper_Inventory_skid_id_index ON Paper_Inventory (skid_id);
CREATE INDEX Paper_Inventory_paper_id_index ON Paper_Inventory (paper_id);
