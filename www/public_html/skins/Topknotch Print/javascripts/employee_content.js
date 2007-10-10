var usergroups = getCookie( 'UserGroups' );

var Menus = new Menu('Main','Main', '','#', 'visible' );

var account = Menus.add( 'Account', 'ACCOUNT', 'menu_account.gif', '#' );
if ( userType == '' ) {
	account.add( 'Login', 'LOGIN', 'menu_account_login.gif', '/employee/employee/login.html;SSL' );
} else {
	account.add( 'Logout','LOGOUT', 'menu_account_logout.gif', '/employee/employee/logout.html;SSL' );
	account.add( 'Profile','PROFILE', 'menu_company_profile.gif', '/employee/employee/profile.html;SSL' );

	var production = Menus.add( 'Production','PRODUCTION', 'menu_production.gif', '#' );
	production.add( 'Projects','PROJECTS', 'menu_production_projects.gif', '/employee/production/projects.html;NOSSL' );
	production.add( 'Barcode','BARCODE', 'menu_production_projects.gif', '/employee/production/barcode.html;NOSSL' );
	//production.add( 'PrintingOverview','PRINTING OVERVIEW', 'menu_production_printingoverview.gif', '/employee/production/printing_overview.html;NOSSL' );
	production.add( 'NewPrintingOverview','PRINT SCHEDULE', 'menu_production_printingoverview.gif', '/employee/production/print_overview.html;NOSSL' );
	//if ( usergroups && isin( usergroups.split(';'), 'Scheduling' ) ) {
	//production.add( 'SetSchedule','SET SCHEDULE', 'menu_production_printingoverview.gif', '/employee/production/duc_interface.html;NOSSL' );
	//} // end if
	//production.add( 'BinderyOverview','BINDERY OVERVIEW', 'menu_production_binderyoverview.gif', '/employee/production/bindery_overview.html;NOSSL' );
	production.add( 'BinderySchedule','BINDERY SCHEDULE', 'menu_production_binderyoverview.gif', '/employee/production/bindery_schedule.html;NOSSL' );

	if ( usergroups && isin( usergroups.split(';'), 'Reporting' ) ) {
		var reports = Menus.add( 'Reports', 'REPORTS', 'reports.gif', '#' );
		reports.add( 'PrepressReport','PREPRESS OVERVIEW', 'menu_production_prepressoverview.gif', '/employee/production/prepress_overview.html;NOSSL' );
		reports.add( 'Efficiency','EFFICIENCY', 'menu_production_printingoverview.gif', '/employee/reports/efficiency.html;NOSSL' );
		reports.add( 'BinderyReport','BINDERY OVERVIEW', 'menu_production_binderyoverview.gif', '/employee/production/bindery_overview.html;NOSSL' );
		reports.add( 'DeliveryReport','DELIVERY', 'blah.gif', '/employee/reports/delivery.html;NOSSL' );
		reports.add( 'TurnaroundReport','TURNAROUND', 'blah.gif', '/employee/reports/turnaround.html;NOSSL' );
	} // end if

	if ( usergroups && isin( usergroups.split(';'), 'Accounting' ) ) {
		var accounting = Menus.add( 'Accounting','ACCOUNTING', 'menu_accounting.gif', '#' );
		accounting.add( 'Outstanding','OUTSTANDING', 'sub_accounting.gif', '/employee/accounting/search.html;NOSSL' );
		accounting.add( 'Credit','CUSTOMER CREDIT', 'credit.gif', '/employee/accounting/credit.html;NOSSL' );
	} // end if
	if ( usergroups && isin( usergroups.split(';'), 'Inventory' ) ) {
		var inventory = Menus.add( 'Inventory','INVENTORY', 'menu_inventory.gif', '#' );
		inventory.add( 'PurchaseOrders','PURCHASE ORDERS', 'inventory_ppos.gif', '/employee/inventory/purchase_orders.html;NOSSL' );
		inventory.add( 'Paper', 'PAPER', 'inventory_paper.gif', '/employee/inventory/paper.html;NOSSL' );
		inventory.add( 'Skids', 'SKIDS', 'inventory_skids.gif', '/employee/inventory/skids.html;NOSSL' );
	} // end if

	var support = Menus.add( 'Support',  'SUPPORT', 'menu_support.gif','#');
	support.add( 'Helpdesk', 'HELPDESK', 'menu_support_helpdesk.gif', '/employee/support/helpdesk_search.html;NOSSL' );
	support.add( 'Returns', 'RETURNS', 'menu_support_returns.gif', '/employee/support/returns.html;NOSSL' );
}

