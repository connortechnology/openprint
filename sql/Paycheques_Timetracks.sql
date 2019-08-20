
CREATE TABLE paycheques_timetracks (
    paycheque_id integer NOT NULL,
    timetrack_id integer NOT NULL
);

ALTER TABLE ONLY paycheques_timetracks
    ADD CONSTRAINT paycheques_timetracks_pkey PRIMARY KEY (paycheque_id, timetrack_id);


ALTER TABLE ONLY paycheques_timetracks
    ADD CONSTRAINT paycheques_timetracks_paycheque_id_fkey FOREIGN KEY (paycheque_id) REFERENCES paycheques(id);

ALTER TABLE ONLY paycheques_timetracks
    ADD CONSTRAINT paycheques_timetracks_timetrack_id_fkey FOREIGN KEY (timetrack_id) REFERENCES timetracks(id);

