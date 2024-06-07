--
-- PostgreSQL database dump
--

-- Dumped from database version 14.11 (Ubuntu 14.11-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.11 (Ubuntu 14.11-0ubuntu0.22.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: service_type_equipment; Type: TABLE; Schema: public; Owner: sherwood
--

CREATE TABLE public.service_type_equipment (
    service_type integer NOT NULL,
    equipment integer NOT NULL
);


ALTER TABLE public.service_type_equipment OWNER TO sherwood;

--
-- Name: TABLE service_type_equipment; Type: COMMENT; Schema: public; Owner: sherwood
--

COMMENT ON TABLE public.service_type_equipment IS 'Defines what services can run on what pieces of equipment. Eg. "Printing" can run ON a "Heidelberg 40" Press"';


--
-- Name: service_type_equipment service_type_equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: sherwood
--

ALTER TABLE ONLY public.service_type_equipment
    ADD CONSTRAINT service_type_equipment_pkey PRIMARY KEY (service_type, equipment);


--
-- Name: service_type_equipment $1; Type: FK CONSTRAINT; Schema: public; Owner: sherwood
--

ALTER TABLE ONLY public.service_type_equipment
    ADD CONSTRAINT "$1" FOREIGN KEY (service_type) REFERENCES public.service_types(id) ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE;


--
-- Name: service_type_equipment $2; Type: FK CONSTRAINT; Schema: public; Owner: sherwood
--

ALTER TABLE ONLY public.service_type_equipment
    ADD CONSTRAINT "$2" FOREIGN KEY (equipment) REFERENCES public.tbl_equipment(id) ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE;


--
-- PostgreSQL database dump complete
--

