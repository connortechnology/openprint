
CREATE TABLE public.departments (
    id serial,
    name character varying(355),
    description text,
    created_at timestamp(6) with time zone DEFAULT now() NOT NULL,
    created_by integer,
    primary key (id)
);



COPY public.departments (id, name, description, created_at, created_by) FROM stdin;
2	Support	Support Call	2021-05-27 13:31:48.15575-07 \N	
3	INF	Infrastructure	2021-05-27 14:30:11.135914-07	\N
4	SysOpts	System Operations  :   servers,  switches and routers oh my!	2021-07-16 02:54:09.499439-07	\N
5	Special Projects 	Camer,   WiFI build-out 	2021-07-16 03:45:52.363848-07	\N
6	Site Acquisition 	Finding Relay sites 	2021-07-16 04:09:50.54254-07	\N
7	Installations	Moved from Sales and on to installations	2021-07-16 04:13:13.477581-07	\N
1	Sales	Sales Department: All Sales inquiries 	2021-05-27 13:29:49.857966-07	
8	Billing	Account Management (AP / AR) 	2021-08-03 14:30:22.921493-07	\N
\.


