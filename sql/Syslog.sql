--
-- PostgreSQL database dump
--

-- Name: hosts; Type: TABLE; Schema: public; Owner: rsyslog
--

CREATE TABLE public.hosts (
    id integer NOT NULL,
    name text,
	primary key (id)
);

CREATE UNIQUE INDEX hosts_name_idx  on public.hosts (name);

CREATE TABLE public.syslogtags (
	id serial,
  name text, 
  PRIMARY KEY (id)
);
CREATE UNIQUE INDEX syslogtags_name_idx ON syslogtags (name);


ALTER TABLE public.hosts OWNER TO rsyslog;

--
-- Name: hosts_id_seq; Type: SEQUENCE; Schema: public; Owner: rsyslog
--

CREATE SEQUENCE public.hosts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE public.hosts_id_seq OWNER TO rsyslog;

--
-- Name: hosts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rsyslog
--

ALTER SEQUENCE public.hosts_id_seq OWNED BY public.hosts.id;

--
-- Name: systemevents; Type: TABLE; Schema: public; Owner: rsyslog
--

CREATE TABLE public.systemevents (
    id integer NOT NULL,
    customerid bigint,
    receivedat timestamp without time zone,
    devicereportedtime timestamp without time zone,
    facility smallint,
    priority smallint,
    fromhost character varying(60),
    message text,
    ntseverity integer,
    importance integer,
    eventsource character varying(60),
    eventuser character varying(60),
    eventcategory integer,
    eventid integer,
    eventbinarydata text,
    maxavailable integer,
    currusage integer,
    minusage integer,
    maxusage integer,
    infounitid integer,
    syslogtag character varying(60),
    eventlogtype character varying(60),
    genericfilename character varying(60),
    systemid integer
);

CREATE INDEX systemevents_receivedat_idx ON public.systemevents(receivedat);

ALTER TABLE public.systemevents OWNER TO rsyslog;

--
-- Name: systemevents_id_seq; Type: SEQUENCE; Schema: public; Owner: rsyslog
--

CREATE SEQUENCE public.systemevents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.systemevents_id_seq OWNER TO rsyslog;

--
-- Name: systemevents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rsyslog
--

ALTER SEQUENCE public.systemevents_id_seq OWNED BY public.systemevents.id;


--
-- Name: systemeventsproperties; Type: TABLE; Schema: public; Owner: rsyslog
--

CREATE TABLE public.systemeventsproperties (
    id integer NOT NULL,
    systemeventid integer,
    paramname character varying(255),
    paramvalue text
);


ALTER TABLE public.systemeventsproperties OWNER TO rsyslog;

--
-- Name: systemeventsproperties_id_seq; Type: SEQUENCE; Schema: public; Owner: rsyslog
--

CREATE SEQUENCE public.systemeventsproperties_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.systemeventsproperties_id_seq OWNER TO rsyslog;

--
-- Name: systemeventsproperties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rsyslog
--

ALTER SEQUENCE public.systemeventsproperties_id_seq OWNED BY public.systemeventsproperties.id;


--
-- Name: hosts id; Type: DEFAULT; Schema: public; Owner: rsyslog
--

ALTER TABLE ONLY public.hosts ALTER COLUMN id SET DEFAULT nextval('public.hosts_id_seq'::regclass);


--
-- Name: systemevents id; Type: DEFAULT; Schema: public; Owner: rsyslog
--

ALTER TABLE ONLY public.systemevents ALTER COLUMN id SET DEFAULT nextval('public.systemevents_id_seq'::regclass);


--
-- Name: systemeventsproperties id; Type: DEFAULT; Schema: public; Owner: rsyslog
--

ALTER TABLE ONLY public.systemeventsproperties ALTER COLUMN id SET DEFAULT nextval('public.systemeventsproperties_id_seq'::regclass);


--
-- Name: systemevents systemevents_pkey; Type: CONSTRAINT; Schema: public; Owner: rsyslog
--

ALTER TABLE ONLY public.systemevents
    ADD CONSTRAINT systemevents_pkey PRIMARY KEY (id);


--
-- Name: systemeventsproperties systemeventsproperties_pkey; Type: CONSTRAINT; Schema: public; Owner: rsyslog
--

ALTER TABLE ONLY public.systemeventsproperties
    ADD CONSTRAINT systemeventsproperties_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--


CREATE OR REPLACE FUNCTION update_summaries() RETURNS TRIGGER  AS $update_summaries$
DECLARE
  syslogtag varchar(60) := REGEXP_REPLACE(NEW.syslogtag, '(\[\d+\])?:?$', '');
BEGIN
	IF (SELECT id FROM hosts WHERE name=NEW.fromhost) IS NULL THEN 
		INSERT INTO hosts (name) VALUES (NEW.fromhost);
	END IF;
	
	IF (SELECT id FROM syslogtags WHERE name=syslogtag) IS NULL THEN 
		INSERT INTO syslogtags (name) VALUES (syslogtag);
	END IF;
	RETURN NULL;
END;
$update_summaries$ LANGUAGE plpgsql;


CREATE TRIGGER systemevents_insert AFTER INSERT ON systemevents
FOR EACH ROW
EXECUTE PROCEDURE update_summaries();
