
/* DROP TABLE RMA_Priorities; */

CREATE TABLE RMA_Priorities (
	id		SERIAL,
	name	TEXT,
	sort	INTEGER,
	PRIMARY KEY (id)
);

INSERT INTO RMA_Priorities (id,name,sort) values (0,'Normal',2);
INSERT INTO RMA_Priorities (id,name,sort) values (1,'Low',1);
INSERT INTO RMA_Priorities (id,name,sort) values (2,'High',3);

SELECT setval( 'rma_priorities_id_seq', (SELECT Max(id) FROM rma_priorities) );
