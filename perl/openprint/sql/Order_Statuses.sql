DROP TABLE IF EXISTS Order_Statuses;

create table order_statuses ( 
	name text, 
	primary key (name)
);
insert into order_statuses values ('Incomplete');
insert into order_statuses values ('Complete');
insert into order_statuses values ('Cancelled');
insert into order_statuses values ('In Production');
insert into order_statuses values ('Order Submitted');
insert into order_statuses values ('Paid');
insert into order_statuses values ('Pending Deposit');
insert into order_statuses values ('Picked Up');
insert into order_statuses values ('Re-Opened');
insert into order_statuses values ('Shipped');
insert into order_statuses values ('Waiting For Customer Approval');
insert into order_statuses values ('Waiting For Pickup');

