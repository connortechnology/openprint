CREATE TABLE PressActivities (
	operator_id	integer not null, foreign key (operator_id) references Users (id),
	project_id	integer not null, foreign key (project_id) references Projects (id),
	service_id	integer not null,
	starttime	timestamp with time zone NOT NULL,
	action		text not null,
	endtime		timestamp with time zone,
	primary key (project_id, service_id)
);
