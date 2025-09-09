CREATE TABLE Project_Comments (
  id SERIAL,
  project_id  integer, FOREIGN KEY project_id REFERENCES tbl_Projects(id),
  userid     integer, FOREIGN KEY user_id REFERENCES users (id),
  assignedto integer, FOREIGN KEY assignedto REFERENCES users (id),
  created_on timestamp without time zone,
  comment    text,
  PRIMARY KEY (id),
);

CREATE INDEX Project_Comments_project_id_idx on Project_Comments (project_id);
