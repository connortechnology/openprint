CREATE TABLE invoice_interests (
    id SERIAL,
    invoice_id integer NOT NULL,
    description text,
    amount numeric(10,2),
    created_on timestamp with time zone DEFAULT now() NOT NULL,
    updated_on timestamp with time zone DEFAULT now() NOT NULL,
    compounded_on date
);
ALTER TABLE ONLY invoice_interests
    ADD CONSTRAINT invoice_interests_pkey PRIMARY KEY (id);

ALTER TABLE ONLY invoice_interests
    ADD CONSTRAINT invoice_interest_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoices(id);
