
CREATE TABLE paycheques (
    id SERIAL,
    employee_id integer NOT NULL,
    employer_id integer NOT NULL,
    currency_id integer NOT NULL,
    paid_on timestamp with time zone,
    external_notes text,
    internal_notes text,
    created_on timestamp with time zone DEFAULT now() NOT NULL,
    updated_on timestamp with time zone DEFAULT now() NOT NULL,
    total numeric(10,2),
    deleted boolean DEFAULT false
);


ALTER TABLE ONLY paycheques
    ADD CONSTRAINT paycheques_pkey PRIMARY KEY (id);


--
-- Name: paycheques_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: penultima
--

ALTER TABLE ONLY paycheques
    ADD CONSTRAINT paycheques_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currencies(id);


--
-- Name: paycheques_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: penultima
--

ALTER TABLE ONLY paycheques
    ADD CONSTRAINT paycheques_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES users(id);


--
-- Name: paycheques_employer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: penultima
--

ALTER TABLE ONLY paycheques
    ADD CONSTRAINT paycheques_employer_id_fkey FOREIGN KEY (employer_id) REFERENCES companies(id);


--
-- PostgreSQL database dump complete
--

