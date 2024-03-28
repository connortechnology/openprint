
create table log_actions (
	id	SERIAL,
	name	TEXT,
	description TEXT,
	PRIMARY KEY (id)
);
alter table log_actions add constraint log_actions_name_key UNIQUE (name);

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
