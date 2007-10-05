
DROP TABLE Shifts;
CREATE TABLE Shifts (
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (lngIndex),
	starttime	time	NOT NULL,
	duration	interval	NOT NULL,
	name		TEXT	NOT NULL,
	PRIMARY KEY (equipment_id, starttime)
);

/* Old Heidi */
INSERT INTO Shifts VALUES ( 2, '07:00:00', '12 hours', 'AM' );
INSERT INTO Shifts VALUES ( 2, '19:00:00', '12 hours', 'PM' );

/* GTO */
INSERT INTO Shifts VALUES ( 1, '07:00:00', '8 hours', 'AM' );
INSERT INTO Shifts VALUES ( 1, '15:00:00', '8 hours', 'PM' );
INSERT INTO Shifts VALUES ( 1, '23:00:00', '8 hours', '3M' );

/* Heidi 8 */
INSERT INTO Shifts VALUES ( 4, '07:00:00', '8 hours', 'AM' );
INSERT INTO Shifts VALUES ( 4, '15:00:00', '8 hours', 'PM' );
INSERT INTO Shifts VALUES ( 4, '23:00:00', '8 hours', '3M' );
/* New Heidi 6 */
INSERT INTO Shifts VALUES ( 25, '07:00:00', '8 hours', 'AM' );
INSERT INTO Shifts VALUES ( 25, '15:00:00', '8 hours', 'PM' );
INSERT INTO Shifts VALUES ( 25, '23:00:00', '8 hours', '3M' );
