#!/bin/sh
CLUSTER=main
DBNAME1=point-one
DBNAME2=point-one_node2
HOST1=fileserver
HOST2=www2
SLONY_USER=postgres
SLONY_PASS=

slonik <<_EOF_
	# ----
	# This defines which namespace the replication system uses
	# ----
	cluster name = $CLUSTER;

	# ----
	# Admin conninfo's are used by the slonik program to connect
	# to the node databases. So these are the PQconnectdb arguments
	# that connect from the administrators workstation (where
	# slonik is executed).
	# ----
	node 1 admin conninfo = 'dbname=$DBNAME1 host=$HOST1 user=$SLONY_USER password=$SLONY_PASS';
	node 2 admin conninfo = 'dbname=$DBNAME2 host=$HOST2 user=$SLONY_USER password=$SLONY_PASS';
	#node 1 admin conninfo = 'dbname=point-one host=fileserver user=postgres password=';
	#node 2 admin conninfo = 'dbname=point-one_node2 host=www2 user=postgres password=';

	# ----
	# Initialize the first node. The id must be 1.
	# This creates the schema "_test1" containing all replication
	# system specific database objects.
	# ----
	#init cluster ( id = 1, comment = 'Node 1' );

	# ----
	# ----
	# The Slony replication system organizes tables in sets. The
	# smallest unit another node can subscribe is a set. Usually the
	# tables contained in one set would be all tables that have
	# relationships to each other. The following commands create
	# one set containing all 4 pgbench tables. The "master" or origin
	# of the set is node 1.
	# ----
	#create set ( id = 1, origin = 1, comment = 'All Tables' );
	#set add table ( set id = 1, origin = 1, id = 1, full qualified name = 'public.annualsales', comment = 'Annual Sales' );
	#set add table ( set id = 1, origin = 1, id = 2, full qualified name = 'public.assistants', comment = 'Assistants' );
 #set add table ( set id = 1, origin = 1, id = 3, full qualified name = 'public.car', comment = 'CARs' );
 #set add table ( set id = 1, origin = 1, id = 4, full qualified name = 'public.blacklist', comment = 'blacklist' );
 #set add table ( set id = 1, origin = 1, id = 5, full qualified name = 'public.cip3_ppf', comment = 'CIP3_PPF' );
 #set add table ( set id = 1, origin = 1, id = 6, full qualified name = 'public.companies_in_marketing_categories', comment = 'Companies in Marketing Categories' );
 #set add table ( set id = 1, origin = 1, id = 7, full qualified name = 'public.bindery_schedule', comment = 'Bindery Schedule' );
 #set add table ( set id = 1, origin = 1, id = 8, full qualified name = 'public.currency_conversions', comment = 'Currency Conversions' );
 #set add table ( set id = 1, origin = 1, id = 9, full qualified name = 'public.configuration', comment = 'Configuration' );
 #set add table ( set id = 1, origin = 1, id = 10, full qualified name = 'public.creditapplications', comment = 'Credit Applications' );
 #set add table ( set id = 1, origin = 1, id = 11, full qualified name = 'public.complaints', comment = 'Complaints' );
 #set add table ( set id = 1, origin = 1, id = 12, full qualified name = 'public.emailtemplates', comment = 'Email Templates' );
 #set add table ( set id = 1, origin = 1, id = 13, full qualified name = 'public.database_info', comment = 'Database Info' );
 #set add table ( set id = 1, origin = 1, id = 14, full qualified name = 'public.detail_levels', comment = 'Detail Levels' );
 #set add table ( set id = 1, origin = 1, id = 15, full qualified name = 'public.company_credit', comment = 'Company Credit' );
 #set add table ( set id = 1, origin = 1, id = 16, full qualified name = 'public.currencies', comment = 'Currencies' );
 #set add table ( set id = 1, origin = 1, id = 17, full qualified name = 'public.emailcampaign_log', comment = 'Email Campaign Log' );
 #set add table ( set id = 1, origin = 1, id = 18, full qualified name = 'public.equipment_shifts', comment = 'Equipment Shifts' );
 #set add table ( set id = 1, origin = 1, id = 19, full qualified name = 'public.employeenumbers', comment = 'Employee Numbers' );
 #set add table ( set id = 1, origin = 1, id = 20, full qualified name = 'public.helpdesk', comment = 'Help Desk' );
#set add table ( set id = 1, origin = 1, id = 21, full qualified name = 'public.inventorycheck', comment = 'Inventory Check' );
 #set add table ( set id = 1, origin = 1, id = 22, full qualified name = 'public.log', comment = 'Log' );
 #set add table ( set id = 1, origin = 1, id = 23, full qualified name = 'public.inks', comment = 'Inks' );
 #set add table ( set id = 1, origin = 1, id = 24, full qualified name = 'public.inventorycheckentries', comment = 'Inventory Check Entries' );
 #set add table ( set id = 1, origin = 1, id = 25, full qualified name = 'public.labels', comment = 'Labels' );
 #set add table ( set id = 1, origin = 1, id = 26, full qualified name = 'public.manifest_content_types', comment = 'Manifest Content Types' );
 #set add table ( set id = 1, origin = 1, id = 27, full qualified name = 'public.label_data', comment = 'Label Data' );
 #set add table ( set id = 1, origin = 1, id = 28, full qualified name = 'public.log_actions', comment = 'Log Actions' );
 #set add table ( set id = 1, origin = 1, id = 29, full qualified name = 'public.labeltypes', comment = 'Label Types' );
 #set add table ( set id = 1, origin = 1, id = 30, full qualified name = 'public.material_specifications', comment = 'Material Specifications' );
 #set add table ( set id = 1, origin = 1, id = 31, full qualified name = 'public.manifestcontents', comment = 'Manifest Contents' );
 #set add table ( set id = 1, origin = 1, id = 32, full qualified name = 'public.marketing_categories', comment = 'Marketing Categories' );
 #set add table ( set id = 1, origin = 1, id = 33, full qualified name = 'public.ordered_products', comment = 'Ordered Products' );
 #set add table ( set id = 1, origin = 1, id = 34, full qualified name = 'public.materials', comment = 'Materials' );
 #set add table ( set id = 1, origin = 1, id = 35, full qualified name = 'public.material_categories', comment = 'Material Categories' );
 #set add table ( set id = 1, origin = 1, id = 36, full qualified name = 'public.manufacturers', comment = 'Manufacturers' );
 #set add table ( set id = 1, origin = 1, id = 37, full qualified name = 'public.order_statuses', comment = 'Order Statuses' );
 #set add table ( set id = 1, origin = 1, id = 38, full qualified name = 'public.order_contents', comment = 'Order Contents' );
 #set add table ( set id = 1, origin = 1, id = 39, full qualified name = 'public.order_log', comment = 'Order Log' );
 #set add table ( set id = 1, origin = 1, id = 40, full qualified name = 'public.paper_recommendations', comment = 'Paper Recommendations' );
 #set add table ( set id = 1, origin = 1, id = 41, full qualified name = 'public.paper_inventory', comment = 'Paper Inventory' );
 #set add table ( set id = 1, origin = 1, id = 42, full qualified name = 'public.paper_allocations', comment = 'Paper Allocations' );
#set add table ( set id = 1, origin = 1, id = 43, full qualified name = 'public.paper_prices', comment = 'Paper Prices' );
 #set add table ( set id = 1, origin = 1, id = 44, full qualified name = 'public.papers', comment = 'Papers' );
 #set add table ( set id = 1, origin = 1, id = 45, full qualified name = 'public.paperweights', comment = 'Paper Weights' );
 #set add table ( set id = 1, origin = 1, id = 46, full qualified name = 'public.par', comment = 'PARs' );
 #set add table ( set id = 1, origin = 1, id = 47, full qualified name = 'public.papercolours', comment = 'Paper Colours' );
 #set add table ( set id = 1, origin = 1, id = 48, full qualified name = 'public.paperqualities', comment = 'Paper Qualities' );
 #set add table ( set id = 1, origin = 1, id = 49, full qualified name = 'public.paperfinishes', comment = 'Paper Finishes' );
 #set add table ( set id = 1, origin = 1, id = 50, full qualified name = 'public.papernames', comment = 'Paper Names' );
 #set add table ( set id = 1, origin = 1, id = 51, full qualified name = 'public.product_prices', comment = 'Product Prices' );
 #set add table ( set id = 1, origin = 1, id = 52, full qualified name = 'public.par_reasons', comment = 'PAR Reasons' );
 #set add table ( set id = 1, origin = 1, id = 53, full qualified name = 'public.par_areas', comment = 'PAR Areas' );
 #set add table ( set id = 1, origin = 1, id = 54, full qualified name = 'public.project_log', comment = 'Project Log' );
 #set add table ( set id = 1, origin = 1, id = 55, full qualified name = 'public.products', comment = 'Products' );
 #set add table ( set id = 1, origin = 1, id = 56, full qualified name = 'public.productionfeedback', comment = 'Production Feedback' );
 #set add table ( set id = 1, origin = 1, id = 57, full qualified name = 'public.project_files', comment = 'Project Files' );
 #set add table ( set id = 1, origin = 1, id = 58, full qualified name = 'public.product_categories', comment = 'Product Categories' );
 #set add table ( set id = 1, origin = 1, id = 59, full qualified name = 'public.payments', comment = 'Payments' );
 #set add table ( set id = 1, origin = 1, id = 60, full qualified name = 'public.pressactivities', comment = 'Press Activities' );
 #set add table ( set id = 1, origin = 1, id = 61, full qualified name = 'public.project_statuses', comment = 'Project Statuses' );
 #set add table ( set id = 1, origin = 1, id = 62, full qualified name = 'public.purchaseorder_contents', comment = 'PO Contents' );
 #set add table ( set id = 1, origin = 1, id = 63, full qualified name = 'public.projecttemplate', comment = 'Project Templates' );
 #set add table ( set id = 1, origin = 1, id = 64, full qualified name = 'public.purchaseorders', comment = 'Purchase Orders' );
 #set add table ( set id = 1, origin = 1, id = 65, full qualified name = 'public.projecttype_requiredservices', comment = 'ProjectType Required Services' );
#set add table ( set id = 1, origin = 1, id = 66, full qualified name = 'public.purchaseorder_logs', comment = 'PO Logs' );
 #set add table ( set id = 1, origin = 1, id = 67, full qualified name = 'public.purchaseorder_notifications', comment = 'PO Notifications' );
 #set add table ( set id = 1, origin = 1, id = 68, full qualified name = 'public.quote_log', comment = 'Quote Log' );
 #set add table ( set id = 1, origin = 1, id = 69, full qualified name = 'public.project_types', comment = 'Project Types' );
 #set add table ( set id = 1, origin = 1, id = 70, full qualified name = 'public.purchaseorder_contenttypes', comment = 'Purchase Order Content Types' );
 #set add table ( set id = 1, origin = 1, id = 71, full qualified name = 'public.rfidscannerhistory', comment = 'RFID Scanner History' );
 #set add table ( set id = 1, origin = 1, id = 72, full qualified name = 'public.rfidtagtypes', comment = 'RFIDTagTypes' );
 #set add table ( set id = 1, origin = 1, id = 73, full qualified name = 'public.rfidtagactions', comment = 'RFIDTag Actions' );
 #set add table ( set id = 1, origin = 1, id = 74, full qualified name = 'public.rfidtaghistory', comment = 'RFIDTagHistory' );
 #set add table ( set id = 1, origin = 1, id = 75, full qualified name = 'public.rma', comment = 'RMA' );
 #set add table ( set id = 1, origin = 1, id = 76, full qualified name = 'public.shifts', comment = 'Shifts' );
 #set add table ( set id = 1, origin = 1, id = 77, full qualified name = 'public.service_categories', comment = 'Service Categories' );
 #set add table ( set id = 1, origin = 1, id = 78, full qualified name = 'public.services', comment = 'Services' );
 #set add table ( set id = 1, origin = 1, id = 79, full qualified name = 'public.service_types', comment = 'Service Types' );
 #set add table ( set id = 1, origin = 1, id = 80, full qualified name = 'public.sessions', comment = 'Sessions' );
 #set add table ( set id = 1, origin = 1, id = 81, full qualified name = 'public.schedule', comment = 'Schedule' );
 #set add table ( set id = 1, origin = 1, id = 82, full qualified name = 'public.skid_verifications', comment = 'Skid Verifications' );
 #set add table ( set id = 1, origin = 1, id = 83, full qualified name = 'public.survey_question_categories', comment = 'Survey Question Categories' );
 #set add table ( set id = 1, origin = 1, id = 84, full qualified name = 'public.survey_responses', comment = 'Survey Responses' );
 #set add table ( set id = 1, origin = 1, id = 85, full qualified name = 'public.taxes', comment = 'Taxes' );
 #set add table ( set id = 1, origin = 1, id = 86, full qualified name = 'public.skid_contents', comment = 'Skid Contents' );
 #set add table ( set id = 1, origin = 1, id = 87, full qualified name = 'public.skids', comment = 'Skids' );
 #set add table ( set id = 1, origin = 1, id = 88, full qualified name = 'public.survey_question_available_answers', comment = 'Survey Available Answers' );
#set add table ( set id = 1, origin = 1, id = 89, full qualified name = 'public.tbl_addresses', comment = 'Addresses' );
 #set add table ( set id = 1, origin = 1, id = 90, full qualified name = 'public.stockpurposes', comment = 'Stock Purposes' );
 #set add table ( set id = 1, origin = 1, id = 91, full qualified name = 'public.survey_answers', comment = 'Survey Answers' );
 #set add table ( set id = 1, origin = 1, id = 92, full qualified name = 'public.tbl_projecttype_defaults', comment = 'Project Type Defaults' );
 #set add table ( set id = 1, origin = 1, id = 93, full qualified name = 'public.tbl_equipment_specifications', comment = 'Equipment Specifications' );
 #set add table ( set id = 1, origin = 1, id = 94, full qualified name = 'public.tbl_material_prices', comment = 'Material Prices' );
 #set add table ( set id = 1, origin = 1, id = 95, full qualified name = 'public.tbl_quote_users_by', comment = 'Quote Users By' );
 #set add table ( set id = 1, origin = 1, id = 96, full qualified name = 'public.tbl_project_pdfs', comment = 'Project PDFS' );
 #set add table ( set id = 1, origin = 1, id = 97, full qualified name = 'public.tbl_quote_details', comment = 'Quote Details' );
 #set add table ( set id = 1, origin = 1, id = 98, full qualified name = 'public.tbl_equipment', comment = 'Equipment' );
 #set add table ( set id = 1, origin = 1, id = 99, full qualified name = 'public.tbl_project_contents', comment = 'Project Contents' );
 #set add table ( set id = 1, origin = 1, id = 100, full qualified name = 'public.tbl_service_prices', comment = 'Service Prices' );
 #set add table ( set id = 1, origin = 1, id = 101, full qualified name = 'public.tbl_reports', comment = 'Reports' );
 #set add table ( set id = 1, origin = 1, id = 102, full qualified name = 'public.tbl_service_defaults', comment = 'Service Defaults' );
 #set add table ( set id = 1, origin = 1, id = 103, full qualified name = 'public.tbl_ship_via', comment = 'Ship_Via' );
#set add table ( set id = 1, origin = 1, id = 104, full qualified name = 'public.trade_references', comment = 'Trade References' );
 #set add table ( set id = 1, origin = 1, id = 105, full qualified name = 'public.uploads', comment = 'Uploads' );
 #set add table ( set id = 1, origin = 1, id = 106, full qualified name = 'public.tbl_warehouse', comment = 'Warehouse' );
 #set add table ( set id = 1, origin = 1, id = 107, full qualified name = 'public.user_notifications', comment = 'User Notification' );
 #set add table ( set id = 1, origin = 1, id = 108, full qualified name = 'public.user_purchaseorder_limits', comment = 'User Purchase Order Limits' );
 #set add table ( set id = 1, origin = 1, id = 109, full qualified name = 'public.tbl_quote_users_for', comment = 'Quote Users For' );
 #set add table ( set id = 1, origin = 1, id = 110, full qualified name = 'public.user_types', comment = 'User Types' );
 #set add table ( set id = 1, origin = 1, id = 111, full qualified name = 'public.tbl_service_specifications', comment = 'Service Specifications' );
 #set add table ( set id = 1, origin = 1, id = 112, full qualified name = 'public.user_notification_types', comment = 'User Notification Types' );
 #set add table ( set id = 1, origin = 1, id = 113, full qualified name = 'public.users_in_usergroups', comment = 'Users in User Groups' );
 #set add table ( set id = 1, origin = 1, id = 114, full qualified name = 'public.manifests', comment = 'Manifests' );
#set add table ( set id = 1, origin = 1, id = 115, full qualified name = 'public.projecttype_categories', comment = 'projecttype_categories' );
 #set add table ( set id = 1, origin = 1, id = 116, full qualified name = 'public.emailcampaign_sent', comment = 'emailcampaign_sent' );
 #set add table ( set id = 1, origin = 1, id = 117, full qualified name = 'public.users_in_marketing_categories', comment = 'users_in_marketing_categories' );
 #set add table ( set id = 1, origin = 1, id = 118, full qualified name = 'public.car_reasons', comment = 'car_reasons' );
 #set add table ( set id = 1, origin = 1, id = 119, full qualified name = 'public.rfidscanners', comment = 'rfidscanners' );
 #set add table ( set id = 1, origin = 1, id = 120, full qualified name = 'public.orders', comment = 'orders' );
 #set add table ( set id = 1, origin = 1, id = 121, full qualified name = 'public.tbl_quotes', comment = 'quotes' );
 #set add table ( set id = 1, origin = 1, id = 122, full qualified name = 'public.pricelists', comment = 'pricelists' );
 #set add table ( set id = 1, origin = 1, id = 123, full qualified name = 'public.usergroups', comment = 'usergroups' );
 #set add table ( set id = 1, origin = 1, id = 124, full qualified name = 'public.rfidtags', comment = 'RFIDTags' );
 #set add table ( set id = 1, origin = 1, id = 125, full qualified name = 'public.company', comment = 'Company' );
 #set add table ( set id = 1, origin = 1, id = 127, full qualified name = 'public.surveys', comment = 'Surveys' );
 #set add table ( set id = 1, origin = 1, id = 128, full qualified name = 'public.emailcampaigns', comment = 'Email Campaigns' );
 #set add table ( set id = 1, origin = 1, id = 129, full qualified name = 'public.survey_questions', comment = 'Survey Questions' );
 #set add table ( set id = 1, origin = 1, id = 130, full qualified name = 'public.inventorychecks', comment = 'Inventory Checks' );
 #set add table ( set id = 1, origin = 1, id = 131, full qualified name = 'public.paper_purchase_orders', comment = 'Paper Purchase Orders' );
 #set add table ( set id = 1, origin = 1, id = 132, full qualified name = 'public.locations', comment = 'Locations' );
 #set add table ( set id = 1, origin = 1, id = 133, full qualified name = 'public.car_areas', comment = 'CAR Areas' );
 #set add table ( set id = 1, origin = 1, id = 134, full qualified name = 'public.users', comment = 'Users' );
 #set add table ( set id = 1, origin = 1, id = 135, full qualified name = 'public.tbl_projects', comment = 'Projects' );
#
	# ----
	# Create the second node, tell the two nodes how to connect to 
	# each other and that they should listen for events on each
	# other. Note that these conninfo arguments are used by the
	# slon daemon on node 1 to connect to the database of node 2
	# and vice versa. So if the replication system is supposed to
	# use a separate backbone network between the database servers,
	# this is the place to tell it.
	# ----
	store node ( id = 2, comment = 'Node 2' );
	store path ( server = 1, client = 2,
		conninfo = 'dbname=$DBNAME1 host=$HOST1 user=$SLONY_USER password=$SLONY_PASS');
	store path ( server = 2, client = 1,
		conninfo = 'dbname=$DBNAME2 host=$HOST2 user=$SLONY_USER password=$SLONY_PASS');
	store listen ( origin = 1, provider = 1, receiver = 2 );
	store listen ( origin = 2, provider = 2, receiver = 1 );
_EOF_


