CREATE TABLE invoice_logs (
    id SERIAL,
    invoice_id integer NOT NULL,
    user_id integer,
    created_on timestamp with time zone DEFAULT now() NOT NULL,
    description text,
	PRIMARY KEY (id)
);

ALTER TABLE ONLY invoice_logs
    ADD CONSTRAINT "$1" FOREIGN KEY (invoice_id) REFERENCES invoices(id);


ALTER TABLE ONLY invoice_logs
    ADD CONSTRAINT "$2" FOREIGN KEY (user_id) REFERENCES users(id);

