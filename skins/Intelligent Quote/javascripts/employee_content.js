var usergroups = getCookie( 'UserGroups' );

var Menus = new Menu('Main','Main', '','#', 'visible' );
Menus.add( 'Home', 'Home', 'menu_home.gif','/employee/index.html;NOSSL');

var account = Menus.add( 'Account', 'Account', 'menu_account.gif', '#' );
if ( userType == '' ) {
	account.add( 'Login', 'Login', 'menu_account_login.gif', '/employee/employee/login.html;SSL' );
} else {
	account.add( 'Logout','Logout', 'menu_account_logout.gif', '/employee/employee/logout.html;SSL' );
	account.add( 'Profile','Profile', 'menu_company_profile.gif', '/employee/employee/profile.html;SSL' );

	var production = Menus.add( 'Production','Production', 'menu_production.gif', '#' );
	production.add( 'Projects','Projects', 'menu_production_projects.gif', '/employee/production/projects.html;NOSSL' );
	production.add( 'Barcode','Barcode', 'menu_production_projects.gif', '/employee/production/barcode.html;NOSSL' );
	//production.add( 'PrintingOverview','PRINTING OVERVIEW', 'menu_production_printingoverview.gif', '/employee/production/printing_overview.html;NOSSL' );
	production.add( 'NewPrintingOverview','Press Schedule', 'menu_production_printingoverview.gif', '/employee/production/print_overview.html;NOSSL' );
	//if ( usergroups && isin( usergroups.split(';'), 'Scheduling' ) ) {
	//production.add( 'SetSchedule','Set SCHEDULE', 'menu_production_printingoverview.gif', '/employee/production/duc_interface.html;NOSSL' );
	//} // end if
	//production.add( 'BinderyOverview','BINDERY OVERVIEW', 'menu_production_binderyoverview.gif', '/employee/production/bindery_overview.html;NOSSL' );
	production.add( 'BinderySchedule','Bindery Schedule', 'menu_production_binderyoverview.gif', '/employee/production/bindery_schedule.html;NOSSL' );

	if ( usergroups && isin( usergroups.split(';'), 'Reporting' ) ) {
		var reports = Menus.add( 'Reports', 'Reports', 'reports.gif', '#' );
		reports.add( 'PrepressReport','Prepress', 'menu_production_prepressoverview.gif', '/employee/reports/prepress_overview.html;NOSSL' );
		reports.add( 'Efficiency','Efficiency', 'menu_production_printingoverview.gif', '/employee/reports/efficiency.html;NOSSL' );
		//reports.add( 'BinderyReport','BINDERY OVERVIEW', 'menu_production_binderyoverview.gif', '/employee/production/bindery_overview.html;NOSSL' );
		reports.add( 'DeliveryReport','Delivery', 'blah.gif', '/employee/reports/delivery.html;NOSSL' );
		reports.add( 'TurnaroundReport','Turnaround', 'blah.gif', '/employee/reports/turnaround.html;NOSSL' );
	} // end if

	if ( usergroups && isin( usergroups.split(';'), 'Marketing' ) ) {
		var marketing = Menus.add( 'Marketing','Marketing', 'menu_marketing.gif', '#' );
		marketing.add( 'Categories','Categories', 'menu_categories.gif', '/employee/marketing/categories.html;SSL' );
		marketing.add( 'Banners','Banners', 'marketing_banners.gif', '/employee/marketing/banners.html;SSL' );
		marketing.add( 'EmailCampaigns','Email Campaigns', 'marketing_mail.gif', '/employee/marketing/email_campaigns.html;SSL' );
		marketing.add( 'Surveys','Surveys', 'marketing_mail.gif', '/employee/marketing/surveys.html;SSL' );
	} // end if

	if ( usergroups && isin( usergroups.split(';'), 'Accounting' ) ) {
		var accounting = Menus.add( 'Accounting','Accounting', 'menu_accounting.gif', '#' );
		accounting.add( 'Outstanding','Outstanding', 'sub_accounting.gif', '/employee/accounting/search.html;NOSSL' );
		accounting.add( 'Credit','Customer Credit', 'credit.gif', '/employee/accounting/credit.html;NOSSL' );
	} // end if
	if ( usergroups && isin( usergroups.split(';'), 'Inventory' ) ) {
		var inventory = Menus.add( 'Inventory','Inventory', 'menu_inventory.gif', '#' );
		inventory.add( 'PurchaseOrders','Purchase Orders', 'inventory_ppos.gif', '/employee/inventory/purchase_orders.html;NOSSL' );
		inventory.add( 'Paper', 'Paper', 'inventory_paper.gif', '/employee/inventory/paper.html;NOSSL' );
		inventory.add( 'Skids', 'Skids', 'inventory_skids.gif', '/employee/inventory/skids.html;NOSSL' );
	} // end if

	var support = Menus.add( 'Support',  'Support', 'menu_support.gif','#');
	support.add( 'Helpdesk', 'Helpdesk', 'menu_support_helpdesk.gif', '/employee/support/helpdesk_search.html;NOSSL' );
	support.add( 'Returns', 'Returns', 'menu_support_returns.gif', '/employee/support/returns.html;NOSSL' );
	support.add( 'Complaints', 'Complaints', 'menu_support_complaints.gif', '/employee/support/complaints.html;NOSSL' );
}

