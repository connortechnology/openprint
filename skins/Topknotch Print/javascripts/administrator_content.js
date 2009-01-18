var Menus = new Menu('Main','Main','', '#', 'visible' );
if ( userType != 'A' ) {
} else {
	var services = Menus.add( 'Services', 'Services','','administrator/production/services.html;NOSSL','normal' );
	services.add( 'ServicesTypes', 'Types','','/administrator/production/service_types.html' );
	services.add( 'ServicesView/Edit', 'View/Edit', '','/administrator/production/services.html;SSL' );
	services.add( 'ServicesPricing', 'Pricing', '','/administrator/production/services_prices.html;SSL' );
	services.add( 'ServicesImport/Export', 'Import/Export', '','/administrator/production/services_definitions.html;SSL' );
	services.add( 'ServicesPriceLists', 'Price Lists', '','/administrator/production/pricelists.html;SSL' );
	services.add( 'ServiceDefaults', 'Defaults', '','/administrator/production/service_defaults.html;SSL' );

	var equipment = Menus.add( 'Equipment',  'Equipment', '','/administrator/production/equipment.html;SSL' );
	equipment.add( 'EquipmentView/Edit',  'View/Edit', '','/administrator/production/equipment.html;SSL' );
	equipment.add( 'EquipmentImport/Export',  'Import/Export', '','/administrator/production/equipment_import_export.html;SSL' );

	var materials = Menus.add( 'Materials',  'Materials','','/administrator/production/materials.html;SSL' );
	materials.add( 'MaterialsView/Edit',  'View/Edit', '','/administrator/production/materials.html;SSL' );
	materials.add( 'MaterialsPricing', 'Pricing', '','/administrator/production/materials_prices.html;SSL' );
	materials.add( 'MaterialsImport/Export',  'Import/Export', '','/administrator/production/materials_definitions.html;SSL' );
	materials.add( 'MaterialsPriceLists',  'Price Lists', '','/administrator/production/pricelists.html;SSL' );

	var project = Menus.add( 'Project',  'Project','','/administrator/production/project_types.html');
	project.add( 'ProjectTypes',  'Types', '','/administrator/project_types/edit.html' );
	project.add( 'ProjectDefaults',  'Defaults', '','/administrator/production/project_defaults.html' );
	project.add( 'ProjectTemplates',  'Templates', '','/administrator/production/project_templates.html' );
	project.add( 'Colours',  'Colours', '','/administrator/production/colour_import_export.html' );

	var products = Menus.add( 'Products',  'Products','','/administrator/products/edit.html');
	products.add( 'ProductsEdit',  'View/Edit', '','/administrator/products/edit.html' );
	products.add( 'ProductCategories',  'Categories', '','/administrator/product_categories/list.html' );

	var paper = Menus.add( 'Paper',  'Paper', '', '#' );
	paper.add( 'PaperView/Edit',  'View/Edit', '','/administrator/paper/list.html;SSL' );
	paper.add( 'PaperImport/Export',  'Import/Export', '','/administrator/paper/import_export.html;SSL' );
	paper.add( 'PaperPriceLists',  'Price Lists', '','/administrator/production/pricelists.html' );
	//paper.add( 'Usage',  'Usage', '','/administrator/paper/usage.html;NOSSL' );

	var managerial = Menus.add( 'Managerial',  'Managerial', '', '' );
	managerial.add( 'CreditApps', 'Credit Apps', '','/administrator/managerial/credit_applications.html;SSL' );
	managerial.add( 'CompanyProfiles',  'Company Profiles', '','/administrator/managerial/company_profiles.html;SSL' );
	managerial.add( 'User Profiles', 'User Profiles', '','/administrator/managerial/user_profiles.html;SSL' );
	managerial.add( 'Taxes', 'Taxes', '','/administrator/managerial/taxes.html;SSL' );
	managerial.add( 'Currencies',  'Currencies', '','/administrator/managerial/currency.html;SSL' );
	managerial.add( 'Configuration', 'Configuration', '','/administrator/managerial/configuration.html;SSL' );
	managerial.add( 'Shipping', 'Shipping', '','/administrator/managerial/shipping_options.html;SSL' );

	var reports = Menus.add( 'Reports', 'Reports', '', '#' );
	reports.add( 'Orders',  'Orders', '','/administrator/reports/orders.html;SSL' );
	reports.add( 'Quotes',  'Quotes', '','/administrator/reports/quotes.html;SSL' );
	reports.add( 'Projects', 'Projects', '','/administrator/reports/projects.html;SSL' );
	reports.add( 'Customer', 'Customer', '','/administrator/reports/customer_login.html;SSL' );
	reports.add( 'ServiceRep', 'Service Rep', '','/administrator/reports/CustomerServiceReps.html;SSL' );
}  // end if
