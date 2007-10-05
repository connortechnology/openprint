
/*
drop table log;
*/
CREATE TABLE Log (
	id SERIAL,
	action_type	INTEGER NOT NULL,
	user_id		INTEGER NOT NULL,
	date_time	timestamp with time zone NOT NULL,
	ip_address	TEXT,
	hostname	TEXT,
	url			TEXT,
	note		TEXT,
	PRIMARY KEY (id)
);

drop table log_actions;
create table log_actions (
	id	SERIAL,
	name	TEXT,
	DESCRIPTION TEXT,
	PRIMARY KEY (id)
);

insert into log_actions (name,description) values ('Other','Other');
insert into log_actions (name,description) values ('Login','Login');
insert into log_actions (name,description) values ('Logout','Logout');
insert into log_actions (name,description) values ('Delete Order','Delete Order');
insert into log_actions (name,description) values ('Delete Company Profile','Delete Company Profile');
insert into log_actions (name,description) values ('Delete Equipment','Delete Equipment');
insert into log_actions (name,description) values ('Delete Campaign','Delete Campaign');
insert into log_actions (name,description) values ('Delete Material','Delete Material');
insert into log_actions (name,description) values ('Delete Price List','Delete Price List');
insert into log_actions (name,description) values ('Delete Service','Delete Service');
insert into log_actions (name,description) values ('Delete Quote','Delete Quote');
insert into log_actions (name,description) values ('Delete Service Price','Delete Service Price');
insert into log_actions (name,description) values ('Delete Material Price','Delete Material Price');
insert into log_actions (name,description) values ('Delete User','Delete User');
insert into log_actions (name,description) values ('Delete Paper','Delete Paper');
insert into log_actions (name,description) values ('Delete Product Category','Delete Product Category');
insert into log_actions (name,description) values ('Delete Product','Delete Product');
insert into log_actions (name,description) values ('Delete Product Price','Delete Product Price');
insert into log_actions (name,description) values ('Delete Project Type','Delete Project Type');
insert into log_actions (name,description) values ('Delete Project','Delete Project');
insert into log_actions (name,description) values ('New Service Type','New Service Type');
insert into log_actions (name,description) values ('Update Service Type','Update Service Type');
insert into log_actions (name,description) values ('Delete Service Type','Delete Service Type');
insert into log_actions (name,description) values ('Export Service Type(s)','Export Service Type(s)');
insert into log_actions (name,description) values ('New Service','New Service');
insert into log_actions (name,description) values ('Update Service','Update Service');
insert into log_actions (name,description) values ('Copy Service','Copy Service');
insert into log_actions (name,description) values ('Export Services','Export Services');
insert into log_actions (name,description) values ('New/Update Service Price','New/Update Service Price');
insert into log_actions (name,description) values ('New Price List','New Price List');
insert into log_actions (name,description) values ('Update Price List','Update Price List');
insert into log_actions (name,description) values ('Copy Price List','Copy Price List');
insert into log_actions (name,description) values ('Update Service Defaults','Update Service Defaults');
insert into log_actions (name,description) values ('New Equipment','New Equipment');
insert into log_actions (name,description) values ('Update Equipment','Update Equipment');
insert into log_actions (name,description) values ('Copy Equipment','Copy Equipment');
insert into log_actions (name,description) values ('Import Equipment Specifications','Import Equipment Specifications');
insert into log_actions (name,description) values ('Export Equipment Specifications','Export Equipment Specifications');
insert into log_actions (name,description) values ('Import Equipment','Import Equipment');
insert into log_actions (name,description) values ('Export Equipment','Export Equipment');
insert into log_actions (name,description) values ('New Material','New Material');
insert into log_actions (name,description) values ('Update Material','Update Material');
insert into log_actions (name,description) values ('Copy Material','Copy Material');
insert into log_actions (name,description) values ('Update Material Price','Update Material Price');
insert into log_actions (name,description) values ('Import Materials','Import Materials');
insert into log_actions (name,description) values ('Export Materials','Export Materials');
insert into log_actions (name,description) values ('New Project Type','New Project Type');
insert into log_actions (name,description) values ('Update Project Type','Update Project Type');
insert into log_actions (name,description) values ('Import Project Type','Import Project Type');
insert into log_actions (name,description) values ('Export Project Type','Export Project Type');
insert into log_actions (name,description) values ('Update Project Defaults','Update Project Defaults');
insert into log_actions (name,description) values ('Update Project Template','Update Project Template');
insert into log_actions (name,description) values ('Import Project Templates','Import Project Templates');
insert into log_actions (name,description) values ('Export Project Templates','Export Project Templates');
insert into log_actions (name,description) values ('New Project Template','New Project Template');
insert into log_actions (name,description) values ('Import Colour Definitions','Import Colour Definitions');
insert into log_actions (name,description) values ('Export Colour Definitions','Export Colour Definitions');
insert into log_actions (name,description) values ('New Product','New Product');
insert into log_actions (name,description) values ('Update Product','Update Product');
insert into log_actions (name,description) values ('Copy Product','Copy Product');
insert into log_actions (name,description) values ('New Product Category','New Product Category');
insert into log_actions (name,description) values ('Update Product Category','Update Product Category');
insert into log_actions (name,description) values ('New Paper','New Paper');
insert into log_actions (name,description) values ('Update Paper','Update Paper');
insert into log_actions (name,description) values ('Copy Paper','Copy Paper');
insert into log_actions (name,description) values ('Import Paper','Import Paper');
insert into log_actions (name,description) values ('Export Paper','Export Paper');
insert into log_actions (name,description) values ('New Company Profile','New Company Profile');
insert into log_actions (name,description) values ('Update Company Profile','Update Company Profile');
insert into log_actions (name,description) values ('New User Profile','New User Profile');
insert into log_actions (name,description) values ('Update User Profile','Update User Profile');
insert into log_actions (name,description) values ('New Taxes','New Taxes');
insert into log_actions (name,description) values ('Update Taxes','Update Taxes');
insert into log_actions (name,description) values ('Delete Taxes','Delete Taxes');
insert into log_actions (name,description) values ('New Currency','New Currency');
insert into log_actions (name,description) values ('Update Currency','Update Currency');
insert into log_actions (name,description) values ('Update Configuration','Update Configuration');
insert into log_actions (name,description) values ('Login Failed','Unsuccessful Login Attempt');
insert into log_actions (name,description) values ('Switch Company','Switch Company');
