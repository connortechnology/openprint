CREATE TABLE Backups (
  id SERIAL,
  name        TEXT,
  path        TEXT,
  username    TEXT,
  keep        INTEGER,
  enabled     BOOLEAN NOT NULL DEFAULT true,
  description TEXT,
  created_on  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_on  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted     BOOLEAN NOT NULL DEFAULT false,
  type_id     INTEGER,
  host_id     INTEGER, FOREIGN KEY (host_id) REFERENCES Hosts (id),
  lastran_on  TIMESTAMP WITH TIME ZONE,
  owner_id    INTEGER, FOREIGN KEY (owner_id) REFERENCES Companies (id),
  PRIMARY KEY (id)
);
