--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--
DELETE FROM departments;

INSERT INTO public.departments (id, name, description, created_at, created_by) VALUES (2, 'Support', 'Support Call', '2021-05-27 13:31:48.15575-07', NULL);
INSERT INTO public.departments (id, name, description, created_at, created_by) VALUES (3, 'INF', 'Infrastructure', '2021-05-27 14:30:11.135914-07', NULL);
INSERT INTO public.departments (id, name, description, created_at, created_by) VALUES (4, 'SysOpts', 'System Operations  :   servers,  switches and routers oh my!', '2021-07-16 02:54:09.499439-07', NULL);
INSERT INTO public.departments (id, name, description, created_at, created_by) VALUES (5, 'Special Projects ', 'Camer,   WiFI build-out ', '2021-07-16 03:45:52.363848-07', NULL);
INSERT INTO public.departments (id, name, description, created_at, created_by) VALUES (6, 'Site Acquisition ', 'Finding Relay sites ', '2021-07-16 04:09:50.54254-07', NULL);
INSERT INTO public.departments (id, name, description, created_at, created_by) VALUES (7, 'Installations', 'Moved from Sales and on to installations', '2021-07-16 04:13:13.477581-07', NULL);
INSERT INTO public.departments (id, name, description, created_at, created_by) VALUES (1, 'Sales', 'Sales Department: All Sales inquiries ', '2021-05-27 13:29:49.857966-07', NULL);
INSERT INTO public.departments (id, name, description, created_at, created_by) VALUES (8, 'Billing', 'Account Management (AP / AR) ', '2021-08-03 14:30:22.921493-07', NULL);


--
-- Name: departments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.departments_id_seq', 8, true);


--
-- PostgreSQL database dump complete
--

