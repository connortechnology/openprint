
drop table if exists logs;
drop table if exists log_actions;
create table log_actions (
	id	SERIAL,
	name	TEXT,
	description TEXT,
	PRIMARY KEY (id)
);
CREATE TABLE Logs (
	id SERIAL,
	action_id	INTEGER NOT NULL, FOREIGN KEY (action_id) REFERENCES log_actions (id),
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES Users (id),
	company_id	INTEGER, FOREIGN KEY (company_id) REFERENCES Companies (id),
	date_time	timestamp with time zone NOT NULL,
	ip_address	TEXT,
	url			TEXT,
	note		TEXT,
	host_id		INTEGER NOT NULL, FOREIGN KEY (host_id) REFERENCES Hosts (id),
	object_id	INTEGER,
	object_type_id	INTEGER, FOREIGN KEY (object_Type_id) REFERENCES Object_Types (id),
	PRIMARY KEY (id)
);


insert into log_actions (name,description) values ('Other','Other');
insert into log_actions (name,description) values ('Login','Login');
insert into log_actions (name,description) values ('Logout','Logout');
insert into log_actions (name,description) values ('Delete Company Profile','Delete Company Profile');
insert into log_actions (name,description) values ('Delete Campaign','Delete Campaign');
insert into log_actions (name,description) values ('Delete User','Delete User');
insert into log_actions (name,description) values ('New Company Profile','New Company Profile');
insert into log_actions (name,description) values ('Update Company Profile','Update Company Profile');
insert into log_actions (name,description) values ('New User Profile','New User Profile');
insert into log_actions (name,description) values ('Update User Profile','Update User Profile');
insert into log_actions (name,description) values ('Update Configuration','Update Configuration');
insert into log_actions (name,description) values ('Login Failed','Unsuccessful Login Attempt');
insert into log_actions (name,description) values ('Switch Company','Switch Company');

create index logs_company_action_idx on logs (company_id,action_id);
