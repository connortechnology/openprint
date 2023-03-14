DROP TABLE IF EXISTS Hosts_Sites;

CREATE Hosts_Sites (
  id  SERIAL,
  host_id integer, FOREIGN KEY (host_id) REFERENCES Hosts (id),
  site_id integer, FORIEGN KEY (site_id) REFERENCES Sites (id),
  PRIMARY KEY (id)
);
