DROP TABLE IF EXISTS Performance_Point_Types;
CREATE TABLE Performance_Point_Types (
	id SERIAL,
	name	TEXT NOT NULL,
	category	TEXT,
	PRIMARY KEY (id)
);

INSERT INTO Performance_Point_Types (name,category) Values ('Press Approval','Printing');
INSERT INTO Performance_Point_Types (name,category) Values ('Make Ready','Printing');
INSERT INTO Performance_Point_Types (name,category) Values ('AQ Setup','Printing');
INSERT INTO Performance_Point_Types (name,category) Values ('Sheet Quantity','Printing');
INSERT INTO Performance_Point_Types (name,category) Values ('Washup','Printing');
INSERT INTO Performance_Point_Types (name,category) Values ('Blanket Smash','Printing');
INSERT INTO Performance_Point_Types (name,category) Values ('Replacement Plate','Printing');
INSERT INTO Performance_Point_Types (name,category) Values ('Reprint','Printing');
INSERT INTO Performance_Point_Types (name,category) Values ('Errors Caught Before Finish','Printing');
INSERT INTO Performance_Point_Types (name,category) Values ('Errors Caught At Start','Printing');
