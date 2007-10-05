
var Menus = new Menu('Main','Main','','#','visible');

//Menus.add( 'Home', 'Home', '','/index.html;NOSSL');
var company = Menus.add( 'Company', 'Company','', '/main/company/profile.html;NOSSL' );
company.add('CompanyProfile','Profile','', '/main/company/profile.html;NOSSL' );
company.add('Policies', 'Policies', '', '/main/company/policies.html;NOSSL' );
company.add('News', 'News', '', '/main/company/news.html;NOSSL' );
company.add('Contact', 'Contact', '', '/main/company/contact.html;NOSSL' );

var account = Menus.add( 'Account', 'Account', '', '#' );
if ( userType != '' ) {
	account.add( 'AccountLogout', 'Logout', '', '/main/account/logout.html;NOSSL' );
	account.add( 'AccountUserProfile', 'User Profile', '', '/main/account/user_profile.html;SSL' );
	account.add( 'AccountCompanyProfile', 'Company Profile', '', '/main/account/company_profile.html;SSL' );
//if ( ! ( userType == "E" || userType == "A" ) ) {
	account.add( 'AccountCreditApp', 'Credit App', '', '/main/account/credit_application.html;SSL' );
	account.add( 'AccountResellerApp', 'Reseller App', '', '/main/account/reseller_application.html;SSL' );
//} // end if
	if ( userType == 'E' || userType == 'A' ) {
		account.add( 'AccountSelectCompany', 'Switch Company', '', '/main/account/select_customer.html;NOSSL' );
	} // end if
} else {
	account.add( 'AccountLogin', 'Login', '', '/main/account/login.html;SSL' );
	account.add( 'AccountRegistration', 'Registration', '', '/main/account/registration.html;SSL' );
} // end if

//var services = Menus.add( 'Services','Services','', '#' );
//services.add( 'Prepress', 'Prepress', '', '/main/services/prepress.html;NOSSL' );
//services.add( 'Printing', 'Printing', '', '/main/services/printing.html;NOSSL' );
//services.add( 'PostProduction', 'Post Production', '', '/main/services/post_production.html;NOSSL' );

var projects = Menus.add( 'Projects', 'Project', '', '#' );
projects.add( 'ProjectOverview', 'Overview', '', '/main/project/overview.html;NOSSL' );
projects.add( 'CreateProject', 'Create Project', '', '/main/project/create_stage1.html;NOSSL' );
projects.add( 'CurrentProject', 'Current Project', '', '/main/project/view.html;NOSSL' );
if ( userType != '' ) {
	// Only logged in people have a history
	projects.add( 'ProjectHistory', 'Project History', '', '/main/project/history.html;NOSSL' );
} // end if

var quotes = Menus.add( 'Quotes', 'Quotes', '', '/main/quote/overview.html;NOSSL' );
quotes.add( 'QuoteOverview', 'Overview', '', '/main/quote/overview.html;NOSSL' );
quotes.add( 'CurrentQuote', 'Current Quote', '', '/main/quote/details.html;NOSSL' );
if ( userType != '' ) {
	// Only logged in people have a history
quotes.add( 'QuoteHistory', 'Quote History', '', '/main/quote/history.html;NOSSL' );
} // end if

var orders = Menus.add( 'Orders', 'Orders', '', '/main/order/overview.html;NOSSL' );
orders.add( 'OrderOverview', 'Overview', '', '/main/order/overview.html;NOSSL' );
orders.add( 'CurrentOrder', 'Current Order', '', '/main/order/information.html;NOSSL' );
if ( userType != '' ) {
	// Only logged in people have a history
orders.add( 'OrderHistory', 'Order History', '', '/main/order/history.html;NOSSL' );
} // end if


var support = Menus.add( 'Support', 'Support', '', '/main/search/search_site.html;NOSSL' );
support.add( 'Glossary', 'Glossary', '', '/support/glossary.html;NOSSL' );
support.add( 'Helpdesk',  'Helpdesk', '',"/support/help_desk.html;NOSSL");

