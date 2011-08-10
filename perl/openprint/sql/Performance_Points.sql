DROP TABLE IF EXISTS Performance_Points;
CREATE TABLE Performance_Points (
	type_id		INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES Performance_Point_Types (id),
	units		TEXT,
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (lngindex),
	value		INTEGER,
	max_value	INTEGER,
	PRIMARY KEY (equipment_id,type_id)
);

COPY performance_points (type_id, units, equipment_id, value, max_value) FROM stdin;
6	Each	1	-15	\N
3	Each	1	2	\N
3	Each	30	2	\N
3	Each	27	2	\N
3	Each	28	2	\N
3	Each	31	2	\N
3	Each	4	2	\N
6	Each	30	-15	\N
6	Each	27	-15	\N
6	Each	28	-15	\N
6	Each	31	-15	\N
6	Each	4	-15	\N
1	Each	1	10	\N
1	Each	30	10	\N
1	Each	27	10	\N
1	Each	28	10	\N
1	Each	31	10	\N
1	Each	4	10	\N
2	Each	1	10	\N
2	Each	30	10	\N
2	Each	27	10	\N
2	Each	28	10	\N
2	Each	31	10	\N
2	Each	4	10	\N
4	Each	1	2	\N
4	Each	30	2	\N
4	Each	27	2	\N
4	Each	28	2	\N
4	Each	31	2	\N
4	Each	4	2	\N
5	Each	1	1	\N
5	Each	30	1	\N
5	Each	27	1	\N
5	Each	28	1	\N
5	Each	31	1	\N
5	Each	4	1	\N
7	Each	1	-3	\N
7	Each	30	-3	\N
7	Each	27	-3	\N
7	Each	28	-3	\N
7	Each	31	-3	\N
7	Each	4	-3	\N
8	Each	1	-30	\N
8	Each	30	-30	\N
8	Each	27	-30	\N
8	Each	28	-30	\N
8	Each	31	-30	\N
8	Each	4	-30	\N
9	Each	1	10	\N
9	Each	30	10	\N
9	Each	27	10	\N
9	Each	28	10	\N
9	Each	31	10	\N
9	Each	4	10	\N
10	Each	1	15	25
10	Each	30	15	25
10	Each	27	15	25
10	Each	28	15	25
10	Each	31	15	25
10	Each	4	15	25
\.

