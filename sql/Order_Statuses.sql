create table order_statuses ( 
	id	SERIAL,
	name text, 
	primary key (id)
);
insert into order_statuses (name) values ('Incomplete');
insert into order_statuses (name) values ('Complete');
insert into order_statuses (name) values ('Cancelled');
insert into order_statuses (name) values ('In Production');
insert into order_statuses (name) values ('Order Submitted');
insert into order_statuses (name) values ('Paid');
insert into order_statuses (name) values ('Pending Deposit');
insert into order_statuses (name) values ('Picked Up');
insert into order_statuses (name) values ('Re-Opened');
insert into order_statuses (name) values ('Shipped');
insert into order_statuses (name) values ('Waiting For Customer Approval');
insert into order_statuses (name) values ('Waiting For Pickup');

