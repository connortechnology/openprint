CREATE TABLE timetracks (
    id SERIAL,
    starting timestamp with time zone NOT NULL,
    ending timestamp with time zone NOT NULL,
    company_id integer, FOREIGN KEY (company_id) REFERENCES Companies (id),
    project_id integer, FOREIGN KEY (project_id) REFERENCES projects (id),
    description text,
    updated_on timestamp with time zone NOT NULL default NOW(),
    created_on timestamp with time zone NOT NULL default NOW(),
    invoice_id integer, FOREIGN KEY (invoice_id) REFERENCES Invoices (id),
    service_id integer, FOREIGN KEY (service_id) REFERENCES Services(id),
    owner_id integer NOT NULL, FOREIGN KEY (owner_id) REFERENCES COmpanies(id),
    time_associated boolean,
    user_id integer, FOREIGN KEY (user_id) REFERENCES Users(id),
    paycheque_id integer,
    rate numeric(10,2),
    deleted boolean DEFAULT false,
    currency_id integer, FOREIGN KEY (currency_id) REFERENCES Currencies (id),
    travel_associated boolean DEFAULT false NOT NULL,
    distance double precision,
	billable	boolean not null default true,
	PRIMARY KEY (id)
);

ALTER TABLE ONLY timetracks
    ADD CONSTRAINT timetracks_paycheque_id_fkey FOREIGN KEY (paycheque_id) REFERENCES paycheques(id);

