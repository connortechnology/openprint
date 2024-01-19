--
-- PostgreSQL database dump
--


--

CREATE TABLE public.task_types (
    id integer NOT NULL,
    name character varying(355),
    description character varying(500),
    created_at timestamp(6) with time zone DEFAULT now() NOT NULL,
    created_by character varying(355),
    abbr character varying(255)
);



CREATE SEQUENCE public.task_types_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


-- Name: task_types id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_types ALTER COLUMN id SET DEFAULT nextval('public.task_types_seq'::regclass);


--
-- Data for Name: task_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (1, 'Service Request', NULL, '2021-07-22 13:30:26.545124-07', NULL, 'SR');
INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (2, 'Trouble Ticket', NULL, '2021-07-22 13:31:20.923541-07', NULL, 'TT');
INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (3, 'INF', 'Infrastructure', '2021-07-22 14:35:53.487157-07', 'Alissa', 'INF');
INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (4, 'SysOpts', 'System Operations', '2021-07-22 14:36:16.897077-07', 'Alissa', 'SO');
INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (5, 'Special Project', 'Special Project', '2021-07-22 14:37:17.642511-07', 'Alissa', ' SP');
INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (6, 'VoIP/Phones', 'Sales projects regarding VoIP Phone systems', '2021-07-26 11:35:45.236529-07', 'Andre', 'VoIP');
INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (7, 'Nagios Down List', 'Host in Nagios shows offline: 1.) add them to the Nagios Down List  &amp;  2.)  acknowledge the host in Nagios, stopping email-notifications ', '2021-07-28 16:43:06.703073-07', 'Kevin', 'NDL');
INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (9, 'Account Management', 'Management of Rhinobee Customer''s accounts', '2021-08-20 11:00:19.423476-07', 'Andre', 'AM');
INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (10, 'Account Transfer', 'Account Transfer to new property owner', '2021-09-27 13:54:07.95368-07', 'Andre', 'Acc.Trans.');
INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (11, 'WiFi Jobs', 'Jobs that require us to configure, install and maintain Wireless Access Points in customer''s Local Area Networks', '2021-11-30 22:29:23.598561-08', 'Andre', 'WiFi');
INSERT INTO public.task_types (id, name, description, created_at, created_by, abbr) VALUES (12, 'Web Contact', 'Contacts made from the website''s forms.', '2022-10-27 09:53:29.054242-07', 'Alissa', 'WC');


--
-- Name: task_types_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.task_types_seq', 12, true);


--
-- Name: task_types tags_copy1_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_types
    ADD CONSTRAINT tags_copy1_pkey1 PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

