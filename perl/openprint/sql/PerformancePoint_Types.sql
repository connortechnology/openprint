DROP TABLE IF EXISTS PerformancePoint_Types;
CREATE TABLE PerformancePoint_Types (
	id SERIAL,
	name	TEXT NOT NULL,
	category	TEXT,
	units		TEXT[],
	PRIMARY KEY (id)
);

INSERT INTO PerformancePoint_Types (name,category) Values ('Press Approval','Printing',{'Each'});
INSERT INTO PerformancePoint_Types (name,category) Values ('Make Ready','Printing', {'/Colour'});
INSERT INTO PerformancePoint_Types (name,category) Values ('AQ Setup','Printing',);
INSERT INTO PerformancePoint_Types (name,category) Values ('Sheet Quantity','Printing');
INSERT INTO PerformancePoint_Types (name,category) Values ('Washup','Printing');
INSERT INTO PerformancePoint_Types (name,category) Values ('Blanket Smash','Printing');
INSERT INTO PerformancePoint_Types (name,category) Values ('Replacement Plate','Printing');
INSERT INTO PerformancePoint_Types (name,category) Values ('Reprint','Printing');
INSERT INTO PerformancePoint_Types (name,category) Values ('Errors Caught Before Finish','Printing');
INSERT INTO PerformancePoint_Types (name,category) Values ('Errors Caught At Start','Printing');
INSERT INTO PerformancePoint_Types (name,category) Values ('Errors Caught At Start','Printing');
