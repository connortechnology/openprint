
CREATE TABLE public.actions (
    id integer NOT NULL,
    name character varying(355),
    description character varying(500),
    created_at timestamp(6) with time zone DEFAULT now() NOT NULL,
    created_by character varying(355)
);


ALTER TABLE public.actions OWNER TO postgres;

--
-- Name: actions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE public.actions_id_seq OWNER TO postgres;

--
-- Name: actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.actions_id_seq OWNED BY public.actions.id;


--
-- Name: actions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actions ALTER COLUMN id SET DEFAULT nextval('public.actions_id_seq'::regclass);


--
-- Data for Name: actions; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (1, 'New', 'New task', '2021-05-27 14:20:02.010768-07', 'Alissa');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (2, 'Completed', 'Completed task', '2021-05-27 14:25:05.866256-07', 'Alissa');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (5, 'Log ', 'Log notes ', '2021-05-27 14:45:27.444565-07', 'Alissa');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (3, 'Hold', 'Hold', '2021-05-27 14:37:32.296293-07', 'Alissa');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (6, 'Bill', 'Send to billing department', '2021-05-27 15:05:15.102932-07', 'Alissa');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (7, 'NVO', 'Non-Viable Option, save for search', '2021-07-13 13:16:35.322703-07', 'Alissa');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (8, 'Follow UP', 'Follow up on a sales or support request that has yet to be solved.   Or to figure out if the call actually solved their issue and can a.) be closed and billed etc....   or b.)  Work on solving their issue.', '2021-07-16 02:59:20.478613-07', 'Kevin');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (9, 'Audit', ' audit:  after the ticket is done.....For sale / support:  did we  a.)  list all equipment used?    b.)  list all labor involved     |    Sales,  did we close the deal and schedule the install as well as  get the signed paperwork ?       ', '2021-07-16 03:04:52.101445-07', 'Kevin');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (4, 'Schedule', 'Schedule task', '2021-05-27 14:44:54.136087-07', 'Alissa');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (11, 'Scheduled', 'Scheduled Item   ', '2021-07-16 03:23:40.682223-07', 'Kevin');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (10, 'Monitoring Audit', 'Make sure all devices are in our monitoring systems:   nagios,  mrtg, smokeping, zabbix', '2021-07-16 03:22:32.679441-07', 'Kevin');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (12, 'PM-Relay Build', 'Project Manage Relay Builds  ', '2021-07-16 03:31:03.234854-07', 'Kevin');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (13, 'Confirm Appointment', 'Confirm scheduled Appointment with Customer --- Via Phone First.  Then follow up with a confirmation email.  ', '2021-07-16 03:35:01.662051-07', 'Kevin');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (14, 'Service Request', 'New customer Service request.', '2021-07-16 13:27:23.407251-07', 'Andre');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (15, 'RMA', 'A task to RMA faulty hardware', '2021-08-06 17:52:52.949823-07', 'James');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (16, 'Account Transfer', 'When a client is moving out/selling their home and have referred our service to the new tenants', '2021-08-21 16:58:13.971488-07', 'Andre');
INSERT INTO public.actions (id, name, description, created_at, created_by) VALUES (17, 'Equipment Removal', 'Remove cpe or infrastructure gear.  Which gear needs to be listed in the ticket. ', '2021-09-06 17:58:20.229114-07', 'Kevin');


--
-- Name: actions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actions_id_seq', 17, true);


--
-- Name: actions tags_copy1_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actions
    ADD CONSTRAINT tags_copy1_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

