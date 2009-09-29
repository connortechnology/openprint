DROP TABLE IF EXISTS Invoices;

CREATE TABLE Invoices (
    id integer DEFAULT nextval(('Invoices_id_seq'::text)::regclass) NOT NULL,
    invoicer_id integer NOT NULL,
    invoicee_id integer NOT NULL,
    posted_on date,
    due_on date NOT NULL,
    external_notes text,
    internal_notes text,
    monthly_interest numeric(10,2),
    created_on timestamp with time zone NOT NULL,
    updated_on timestamp with time zone NOT NULL,
    posted boolean DEFAULT false NOT NULL,
    statetax numeric(10,2),
    federaltax numeric(10,2),
    currency_id integer NOT NULL,
    subtotal numeric(10,2),
    total numeric(10,2),
    federaltaxrate double precision,
    statetaxrate double precision,
    deleted boolean DEFAULT false,
    paid double precision,
    interest double precision,
    bad_debt boolean DEFAULT false
);

ALTER TABLE ONLY invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);

ALTER TABLE ONLY invoices
    ADD CONSTRAINT "$1" FOREIGN KEY (invoicer_id) REFERENCES companies(id);

ALTER TABLE ONLY invoices
    ADD CONSTRAINT "$2" FOREIGN KEY (invoicee_id) REFERENCES companies(id);

ALTER TABLE ONLY invoices
    ADD CONSTRAINT "$3" FOREIGN KEY (currency_id) REFERENCES currencies(id);
