CREATE TABLE Users_in_Usergroups (
	usergroup_id	INTEGER NOT NULL,
	user_id	INTEGER NOT NULL,
	PRIMARY KEY (usergroup_id,user_id)
);
