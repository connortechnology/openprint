CREATE TABLE Users_In_UserGroups (
	user_id	INTEGER NOT NULL,	FOREIGN KEY (user_id) REFERENCES Users (Index),
	usergroup_id	INTEGER NOT NULL,	FOREIGN KEY (usergroup_id) REFERENCES UserGroup (id)
);
