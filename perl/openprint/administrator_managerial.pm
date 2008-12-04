package openprint::administrator_managerial;
use MIME::QuotedPrint;

use strict;

require sql;
require ssi;
require configuration;
require email;
require openprint::Currency;
require openprint::User;
require openprint::logs;
require openprint::customer;
require openprint::obj_customer;
require openprint::address;
require openprint::Company;
require openprint::customer_credit;
require openprint::Tax;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%session;
*param = \%param;
*config = \%config;

sub configuration {

	if ( $param{'btnFunction'} eq 'Save' ) {
		my @config = sql::execute( $log, $dbh, 'SELECT Name, Value, Type FROM Configuration ORDER BY lower(category), name' );
		while ( my ( $name, $value, $type ) = splice @config,0,3 ) {
			my $newvalue = $param{$name};
			if ( $type eq 'list' ) {
				$newvalue = join(',', misc::trim( split(',', $newvalue ) ) );
			}
			if ( $value ne $newvalue ) {
				configuration::save_entry( $log, $dbh, $name, $newvalue );
			} # end if
		} # end while

		# Add record to audit log - action "Update Configuration".
		openprint::logs::insertLogRecord('77',);
	} # end if
} # end sub configuration

sub taxes {

	if ( $param{'btnFunction'} eq 'Delete' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $key ( keys %param ) {
			if ( $key =~ /chkDelete-(\d*)/ ) {
				my $Tax = new openprint::Tax( $1 );
				$variable{'error'} .= $Tax->delete();
				
				openprint::logs::insertLogRecord('74', sprintf('Country: %s | State: %s', $Tax->country(), $Tax->state() ) );
			} # end if
		} # end foreach
		sql::end_transaction( $dbh, $ac );
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $Tax ( openprint::Tax::find() ) {
			$variable{'error'} .= $Tax->save({
				'federaltax_rate'	=>	$param{'federaltax_rate-'.$Tax->id()},
				'statetax_rate'		=>	$param{'statetax_rate-'.$Tax->id()},
				});
		} # end foreach Tax
		if ( $param{'federaltax_rate-New'} or $param{'statetax_rate-New'} ) {
			my $Tax = new openprint::Tax();
			$variable{'error'} .= $Tax->save({
				'federaltax_rate'	=>	$param{'federaltax_rate-New'},
				'statetax_rate'		=>	$param{'statetax_rate-New'},
				'country'			=>	$param{'country-New'},
				'state'				=>	$param{'state-New'},
				});
		} # end if New Tax

		sql::end_transaction( $dbh, $ac );
	} # end if
} # end sub taxes 

sub currency {

	if ( $param{'btnFunction'} eq 'Save' ) {

		# Add record to audit log - action "Update Currency".
		openprint::logs::insertLogRecord('76',);

		if ( $param{'strName'} ) {
			my $Currency = new openprint::Currency();
			$Currency->name($param{'strName'});
			$Currency->short($param{'strShort'});
			$Currency->symbol($param{'strSymbol'});
			$Currency->save();
		} # end if

		foreach my $Currency ( openprint::Currency::find() ) {
			if ( $param{'strName'.$Currency->id()} ) {
				$Currency->name($param{'strName'.$Currency->id()});
				$Currency->short($param{'strShort'.$Currency->id()});
				$Currency->symbol($param{'strSymbol'.$Currency->id()});
				$Currency->save();
			} # end if
		} # end foreach
	} # end if

} # end sub currency_edit

sub user_profiles {

	my $user_id = $param{'ddmUser'};
	my $user_role = $param{'ddmUserRole'};
	my $cust_id = $param{'ddmCustomer'};


	my $User = new openprint::User( $user_id );

	if ( $param{'btnFunction'} eq '<<' ) {
		$User = $User->Prev( 'type'=>$param{'ddmUserRole'}, 'company_id'=>$param{'ddmCustomer'} );
	} elsif ($param{'btnFunction'} eq '>>') {
		$User = $User->Next( 'type'=>$param{'ddmUserRole'}, 'company_id'=>$param{'ddmCustomer'} );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$User->delete();
		$User = $User->Next( 'type'=>$param{'ddmUserRole'}, 'company_id'=>$param{'ddmCustomer'} );
		$variable{'information'} = 'User marked deleted.';
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		$User->destroy();
		$User = $User->Next( 'type'=>$param{'ddmUserRole'}, 'company_id'=>$param{'ddmCustomer'} );
		$variable{'information'} = 'Record deleted.';

	} elsif ($param{'btnFunction'} eq 'Save') {
		if ( $param{'password'} ne $param{'verifypassword'} ) {
			return misc::error( $log, $dbh, \%variable, "Passwords don't match.", "Your password and verify password fields do not match.");
		} # end if

		my @Users = openprint::User::find( 'email' => lc $param{'email'} );
		if ( @Users > 1 or ( ( @Users == 1 ) and ( $Users[0]->id() != $User->id() ) ) ) {
			return misc::error( $log, $dbh, \%variable, 'User already exists.', "There is already a user with the specified email address.	Please try another.");
		} # end if

		#$param{'assistant_ids'} = '' if ! exists $param{'assistant_ids'};
		#$param{'csr_ids'} = '' if ! exists $param{'csr_ids'};
		delete $param{'password'} if ! $param{'password'};
		my $error = $User->save( \%param );

		if ( $error ) {
			return misc::error( $log, $dbh, \%variable, 'Error Saving.', "There was an error saving the user's information. $error");
		} # end if

		if ( $config{mail_db_name} and $User->email() =~ /(.*)\@point\-one\.com/ ) {
			if ( $param{'VacationState'} ) {
				email::start_vacation( $r, $log, $User->email(), @param{'VacationSubject','VacationMessage'} );
			} else {
				email::stop_vacation( $r, $log, $User->email() );
			} # end if
			if ( $param{'EmailPassword'} and $param{'EmailPassword'} eq $param{'VerifyEmailPassword'} ) {
				email::set_password( $r, $log, @param{'email','EmailPassword'} );
			} # end if
			my @aliases = ();
			foreach my $alias ( split "\r\n", $param{'aliases'} ) {
				next if ! $alias;
				push @aliases, $alias;
			} # end foreach
			push @aliases, $User->email() if ! @aliases;
			email::aliases( $log, $User->email(), @aliases );

			$sql::dbh = $dbh;
		} # end if

		my @categories = sql::execute( $log, $dbh, 'SELECT id FROM Marketing_Categories' );

		sql::execute( $log, $dbh, 'DELETE FROM Users_in_Marketing_Categories WHERE user_id=?', $user_id );

		# add them back in 
		my $sth = $dbh->prepare( q{INSERT INTO Users_in_Marketing_Categories (category_id,user_id) VALUES ( ?, ? )} );
		foreach my $cat ( ref $param{'selectUserCategories'} eq 'ARRAY' ? @{$param{'selectUserCategories'}} : $param{'selectUserCategories'} ) {
			if ( sets::isin( $cat, \@categories ) ) {
				$sth->execute( $cat, $user_id ) or $log->error( DBI->errstr );
			} # end if
		} # end foreach

		sql::execute( $log, $dbh, q{DELETE FROM Users_in_UserGroups WHERE User_Id=?}, $user_id );
		if ( $param{'UserGroups'} ) {
			foreach my $group_id ( ref $param{'UserGroups'} eq 'ARRAY' ? @{$param{'UserGroups'}} : $param{'UserGroups'} ) {
				sql::insert( $log, $dbh, 'Users_in_UserGroups', ['usergroup_id', $group_id, 'user_id', $user_id ] );
			} # end foreach
		} # end if

		foreach my $service_default_id ( sql::execute( undef, undef, 'SELECT id FROM User_Service_Defaults WHERE user_id=?', $user_id ) ) {
			if ( 'name'=>$param{'name-'.$service_default_id} ) {
			sql::update( undef, undef, 'User_Service_Defaults', ['id=?'=>$service_default_id], {
					'servicetype_id'=>$param{'servicetype_id-'.$service_default_id} ? $param{'servicetype_id-'.$service_default_id} : undef,
					'name'=>$param{'name-'.$service_default_id},
					'value'=>$param{'value-'.$service_default_id}
					});
			} else {
				sql::execute( undef, undef, 'DELETE FROM User_Service_Defaults WHERE id=?', $service_default_id );
			} # end if
		} # end foreach
		sql::insert( undef, undef, 'User_Service_Defaults', {
				'user_id'=>$user_id,
				'servicetype_id'=>$param{'servicetype_id-'} ? $param{'servicetype_id-'} : undef,
				'name'=>$param{'name-'},
				'value'=>$param{'value-'} 
				} );

		$variable{'information'} = "Record saved successfully.";
	} # end if btnFunction

	# if we don't have a selected user, pick the first one returned filtered by company and user type if specified
	my @Users = openprint::User::find( 'company_id'=>$cust_id, 'type'=>$user_role, 'order'=>'lower(firstname),lower(lastname)' );

	if ( ! $User->id() ) {
		if ( sets::isin( $session{user_id}, map { $_->id() } @Users ) ) {
			$User = new openprint::User( $session{user_id} );
		} else {
			$User = $Users[0] if @Users;
		} # end if
	} # end if

	# load user fields

	$variable{'UserIndex'} = $User->id();
	$variable{'User'} = $User;
	$variable{'NUM_USERS'} = scalar @Users;

	if ( $User->id() ) {
		my $count = 1;
		foreach my $U ( @Users ) {
			if ( $U->id() == $User->id() ) {
				$variable{'EDIT_USER_NUM'} = $count;
				last;
			} # endif
			$count += 1;
		} # end foreach
	} # end if 

	if ( $config{mail_db_name} and $User->email() =~ /(.*)\@point\-one\.com/ ) {
		@variable{'VacationState','VacationSubject','VacationMessage'} = email::get_vacation( $r, $log, $User->email() );
		@{$variable{'Aliases'}} = email::aliases( $log, $User->email() );
		$sql::dbh = $dbh;
	} # end if

				
	# fill in User Name Drop Down Menu
	$variable{'FILL_USER_NAME'} = ssi::make_drop_down( [ map { $_->id(), $_->name() } @Users ], $User->id() );

	# Get Marketing Category Inforamation - get all categories, and highlight the ones this user is in.
	my @available_categories = sql::execute( $log, $dbh, 'SELECT id, name FROM Marketing_Categories' );

	# get categories this customer is in we do it this way to limit databse transaction to 2.
	my @users_categories;
	if ( $User->id() ) {
		@users_categories = sql::execute( $log, $dbh,'SELECT category_id FROM Users_in_Marketing_Categories WHERE user_id=?', $User->id() );
	} # end if
	$variable{'selectUserCategories'} = ssi::make_select( \@available_categories, \@users_categories );

} # end sub edit


sub company_profiles {
	my ( $r, $log, $dbh, $variable ) = @_;

# form field to db field mappings
	my %shipping_fields = (
			'txtShippingCompanyName'	=>	'CompanyName',
			'rdbShippingSalutation'	 =>	'Salutation',
			'txtShippingFirstName'		=>	'FirstName',
			'txtShippingLastName'		=>	'LastName',
			'txtShippingAddress1'		=>	'Address1',
			'txtShippingAddress2'		=>	'Address2',
			'txtShippingCity'			=>	'City',
			'ddmShippingStateProvince'	=>	'StateProvince',
			'ddmShippingCountry'		=>	'Country',
			'txtShippingPostalCode'	=> 'PostalCode',
			'txtShippingPhone'			=>	'Phone',
			'txtShippingExtension'		=>	'Extension',
			'txtShippingFax'			=>	'Fax',
			'txtShippingEmail'			=>	'Email',
	);

	my %credit_fields = (
			'txtDenyDays'			=>	'DenyDays',
			'txtWarnDays'			=>	'WarnDays',
			'txtCreditLimit'	=>	'Limit',
			'rdbCreditHold'	 =>	'Hold',
			'txtDownpayment'	=>	'Downpayment',
			);

	my $index = $param{'ddmCustomer'} ? $param{'ddmCustomer'} : $session{'company_id'};
	my $Company = new openprint::Company( $index );

	if ( $param{'btnFunction'} eq '<<' ) {
		$index = $Company->prev();
		$Company = new openprint::Company( $index );
	} elsif ( $param{'btnFunction'} eq '>>') {
		$index = $Company->next();
		$Company = new openprint::Company( $index );
	} elsif ( $param{'btnFunction'} eq 'Go' ) {
		if ( $param{'txtSearchAccountNum'} ne '' ) {
			( $index ) = sql::execute( $log, $dbh, 'SELECT id from Company WHERE strAccountNum=?',$param{'txtSearchAccountNum'}); 
		} # end if 
	} elsif ( $param{'btnFunction'} eq 'Save' ) {

		my $customer = new openprint::obj_customer( $log, $dbh, $index );

		if ( $Company->activation() ne $param{'activation'} ) {
			my %info;
			$info{'Company'} = $Company;
			my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );

			$_ = $param{'activation'} eq 'Y' ? 'account_activated.html' : 'account_deactivated.html';
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . "/email_content/$_" );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

			$email_template = ssi::variable_substitution( \$email_template, \%info ); 

			my @to = map { sprintf('"%s %s" <%s>', $_->get('firstname','lastname','email')); } openprint::User::find('company_id'=>$index,'web_active'=>'Y');
			my %mail = (
					SMTP	=> $config{'Mail Server'},
					FROM	=> $config{'AdministratorEmail'},
					TO		=> join( ',', @to ),
					SUBJECT => 'Customer account status has changed!',
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );
		} # end if
		if ( $Company->reseller() and ( $Company->reseller() ne $param{'rdbReseller'} ) ) {
			my %info;
			my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
			$info{'Company'} = $Company;

			my @to = openprint::User::find('company_id'=>$index);

			$_ = $param{'rdbReseller'} eq 'Y' ? 'customer_account_reseller.html' : 'customer_account_non_reseller.html';
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . "/email_content/$_" );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

			$email_template = ssi::variable_substitution( \$email_template, \%info ); 
			my %mail = (
					SMTP	=> $config{'Mail Server'},
					FROM	=> $config{'AdministratorEmail'},
					TO		=> join( ',', map { sprintf('"%s" <%s>', $_->name(), $_->email() ); } @to ),
					SUBJECT => "Customer account status has changed!",
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );
		} # end if
if ( 0 ) {
		if ( $Company->supplier() ne $param{'rdbSupplier'} ) {
			my %info;
			my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
			$info{'Company'} = $Company;
			my @to = openprint::User::find('company_id'=>$index);

			$_ = $param{'rdbSupplier'} eq 'Y' ? 'customer_account_supplier.html' : 'customer_account_non_supplier.html';
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . "/email_content/$_" );
			$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
			$email_template = ssi::variable_substitution( \$email_template, \%info );
			my %mail = (
					SMTP	=> $config{'Mail Server'},
					FROM	=> $config{'AdministratorEmail'},
					TO		=> join( ',', map { sprintf('"%s" <%s>', $_->name(), $_->email() ); } @to ),
					SUBJECT => 'Customer account status has changed!',
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );
		} # end if
} # end if

		$param{'start_year'} =~ s/\D//g;
		if ( $param{'start_year'} ) {
			$param{'start_month'} = '01' if ! $param{'start_month'};
			$param{'established'} = $param{'start_year'} . '-' . $param{'start_month'} . '-01';
		} # end if
		$variable{'error'} .= $Company->save( \%param );
		$index = $Company->id();

		if ( $index > 0 ) {
# Otherwise Error!
# Customer Categories
# I was trying to do this the hard way.	Then it occurred to me: Just delete them all from the table, and add back in the ones we want.	
			my @customercategories = sql::execute( $log, $dbh, 'SELECT id FROM Marketing_Categories' );

			sql::execute( $log, $dbh, q{DELETE FROM Companies_in_Marketing_Categories WHERE company_Id =?}, $index );
# add them back in 
			my $sth = $dbh->prepare( q{INSERT INTO Companies_in_Marketing_Categories (Category_Id,Company_Id) VALUES ( ?, ? )} );
			foreach my $cat ( $param{'selectCustomerCategories'} ) {
				if ( sets::isin( $cat, \@customercategories ) ) {
					$sth->execute( $cat, $index ) or $log->error( DBI->errstr );
				} # end if
			} # end foreach

			my %params;
			foreach my $field ( keys %shipping_fields ) {
				$params{$shipping_fields{$field}} = $param{$field} if defined $param{$field};
			} # end foreach
			$customer->save_shipping( \%params );

			openprint::customer::save_tradereferences( $r, $log, $dbh, $index );

			my $customer_credit = new openprint::customer_credit( $index );
			my %params;
			foreach my $field ( keys %credit_fields ) {
				$params{$credit_fields{$field}} = $param{$field} if defined $param{$field};
			} # end foreach
			$customer_credit->set( \%params );
		} # end if $index
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$Company->delete();
		$Company = new openprint::Company( $Company->id() );
		$index = $Company->id();
	} # end if btnFunction

# we no longer default to displaying the first record.	The user must select one.,
	if ( $index > 0 ) {
		my $customer = new openprint::obj_customer( $log, $dbh, $index );

		$variable{'txtPricingLevel'} = sprintf ( "%.0f", $variable{'txtPricingLevel'} ) . "%";
		$variable{'txtDownpayment'} = sprintf ( "%.0f", $variable{'txtDownpayment'} ) . "%";

		openprint::customer::load_tradereferences( $r, $log, $dbh, $index, $variable );
		my $shipping_address = $customer->get_shipping_address();
		@$variable{ keys %shipping_fields } = ssi::htmlize( $shipping_address->get( @shipping_fields{ keys %shipping_fields } ) );
		$variable{'rdbShippingSalutation'.$variable{'rdbShippingSalutation'}} = 'CHECKED';

		my $customer_credit = new openprint::customer_credit( $index );
		@$variable{ keys %credit_fields } = ssi::htmlize( $customer_credit->get( @credit_fields{ keys %credit_fields } ) );
	} # end if

	# Get Customer Category Inforamation - get all categories, and highlight the ones this customer is in.
	my @available_categories = sql::execute( $log, $dbh, 'SELECT id, name FROM Marketing_Categories' );
	
	# get categories this customer is in we do it this way to limit databse transaction to 2.
	my @customers_categories;
	if ( $index ) {
		$_ = q{SELECT category_id FROM Companies_in_Marketing_Categories WHERE Company_id =?};
		@customers_categories = sql::execute( $log, $dbh, $_, $index );
	} # end if
	$variable{'selectCustomerCategories'} = ssi::make_select( \@available_categories, \@customers_categories );

	$variable{'ddmShippingStateProvince'} = ssi::return_states_and_provinces($variable{'ddmShippingStateProvince'});
	$variable{'ddmShippingCountry'} = ssi::return_countries($variable{'ddmShippingCountry'});

	my $total;
	my $payments;
	if ( $index ) {
		$_ = "SELECT SUM(curTotalSale) FROM Orders WHERE CompanyIndex=? AND strStatus IN ('Pending Deposit','In Production','Paid')";
		( $total ) = sql::execute( $log, $dbh, $_, $index );
		( $payments ) = misc::sum( map { $_->amount() } openprint::Payment::find('completed'=>1, 'payor_id'=>$index, 'recipient_id'=>$session{'company_id'} ) );
	} # end if

	$variable{'CreditBalance'} = '$ '.sprintf( "%.2f", ( $total - $payments ) );
	if ( $variable{'txtCreditLimit'} < ($total - $payments) ) {
		$variable{'CreditRemaining'} = '$ 0.00';
	} else {
		$variable{'CreditRemaining'} = '$ '.sprintf( '%.2f', ( $variable{'txtCreditLimit'} - ($total - $payments) ) );
	} # end if

	$variable{'CustomerIndex'} = $index;
	$variable{'Company'} = $Company;
} # end sub company_profiles


sub credit_applications {
	my ( $r, $log, $dbh, $variable ) = @_;

		if ( $r->param('btnFunction') eq 'Save' ) {
			my %credit_fields = (
					'txtTerms'			=>	'Terms',
					'CreditLimit'		=>	'CreditLimit',
					'txtDownpayment'	=>	'Downpayment',
					);
			my $credit_app = $r->param('credit_index');

			if ( $credit_app ) {
				sql::update( $log, $dbh, 'CreditApplications', "Id = $credit_app", 
						'strStatus',			$r->param('verdict'),
						'lngGrantedTerms',			$r->param('txtTerms'),
						'dblGrantedCreditLimit',	$r->param('CreditLimit'),
						'dblGrantedDownpayment',	$r->param('txtDownpayment'),
						);
				$_ = "SELECT company_id, user_id, strSignature, ysnFinancialStatementAvailable,strFirstOrderValue,strAnnualPurchases, dblCreditLimit, strAccountsPayableContact, to_char(dtmCreationDate,'Day Month DD, YYYY HH24:MI') FROM CreditApplications ".
					"WHERE id=?";

				@$variable{
					'hiddenCustomerID',
					'UserIndex',
					'Signature',
					'FinancialStatementAvailable',
					'FirstOrderValue',
					'AnnualPurchases',
					'AccountLimitDesired',
					'AccountsPayableContact',
					'SubmissionDate',
				} = sql::execute( $log, $dbh, $_, $credit_app );

				if ( ! sql::execute( $log, $dbh, 'SELECT id FROM company WHERE id=?', $variable{'hiddenCustomerID'} ) ) {
					return misc::error( $log, $dbh, \%variable, 'Deleted Customer', "The company that created this credit app has been deleted from the system.	This credit app has been deleted." );
				} # end if

				$variable{'FinancialStatementAvailable'} = $variable{'FinancialStatementAvailable'} eq 'Y' ? 'Yes' : 'No';

				my $customer_credit = new openprint::customer_credit( $variable{'hiddenCustomerID'}, $session{'company_id'} );
				my %params;

				foreach my $field ( keys %credit_fields ) {
					$params{$credit_fields{$field}} = $r->param($field) if defined $r->param($field);
				} # end foreach
				$params{'txtSignature'} = $variable{'Signature'};
				$customer_credit->set( \%params );
				$params{'siteURL'} = $config{'siteURL'};
				$params{'SecureSiteURL'} = $config{'SecureSiteURL'};

				my $User = new openprint::User( $variable{'UserIndex'} );

				$params{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/credit_change_notification.html' );
				$params{'ReplacementText'} = ssi::variable_substitution( \$params{'ReplacementText'}, \%params );
				my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
				my $template = ssi::variable_substitution( \$_, \%params );
				my %mail = (
						SMTP	=> $config{'Mail Server'},
						FROM	=> $config{'AdministratorEmail'},
						TO		=> sprintf('"%s" <%s>', $User->name(), $User->email() ),
						SUBJECT => 'Credit Status Changed.'
						);
				misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($template), 'text/html', 'quoted-printable' ) );
			} # end if
		} # end if

	ssi::get_start_end_dates( $log, $dbh, $variable,
			$r->param('ddmStartYear'),
			$r->param('ddmStartMonth'),
			$r->param('ddmStartDay'),
			$r->param('ddmEndYear'),
			$r->param('ddmEndMonth'),
			$r->param('ddmEndDay') );

	@{$variable{'CreditApps'}} = ();
	$_ = "SELECT Id, strSignature, date(dtmCreationDate), (SELECT name FROM Companies WHERE id=company_id), strStatus\n".
		"FROM CreditApplications\n".
		"WHERE date(dtmCreationDate) BETWEEN date('$variable{'StartDate'}') AND date('$variable{'EndDate'}')\n";
	$_ .= "AND strStatus = 'Approved'\n" if $r->param('ddmStatus') eq 'Approved';
	$_ .= "AND strStatus = 'Declined'\n" if $r->param('ddmStatus') eq 'Declined';
	$_ .= "AND strStatus != 'Non-Reviewed'\n" if $r->param('ddmStatus') eq 'Reviewed';
	$_ .= "AND strStatus = 'Non-Reviewed'\n" if $r->param('ddmStatus') eq 'Non-Reviewed';
	$_ .= "AND company_Id = '".$r->param('ddmCompany')."'\n" if $r->param('ddmCompany');
	#$_ .= "AND lngSupplierIndex = '$session{'company_id'}'";
	$_ .= "ORDER BY dtmCreationDate, Id";
	@{$variable{'CreditApps'}} = sql::execute( $log, $dbh, $_ );

	$variable{$r->param('ddmStatus')} = 'SELECTED';
} # end sub credit_applications

sub credit_application {
	my ( $r, $log, $dbh, $variable ) = @_;

	my %credit_fields = (
		'txtTerms'			=>	'Terms',
		'CreditLimit'		=>	'CreditLimit',
		'txtDownpayment'	=>	'Downpayment',
	);

	my $credit_app = $r->param('credit_index');
	$variable{'credit_index'} = $credit_app;

	if ( $credit_app ) {
		$_ = "SELECT company_Id, User_Id, strSignature, ysnFinancialStatementAvailable,strFirstOrderValue,\n".
			"strAnnualPurchases, dblCreditLimit, lngTerms, strAccountsPayableContact,\n".
			"to_char(dtmCreationDate,'Day Month DD, YYYY HH24:MI'), strStatus, lngGrantedTerms, dblGrantedCreditLimit, dblGrantedDownpayment\n".
			"FROM CreditApplications ".
			"WHERE Id=?";
		
		 @$variable{
			'hiddenCustomerID',
			'UserIndex',
			'Signature',
			'FinancialStatementAvailable',
			'FirstOrderValue',
			'AnnualPurchases',
			'AccountLimitDesired',
			'AccountTermsDesired',
			'AccountsPayableContact',
			'SubmissionDate',
			'verdict',
			'GrantedTerms',
			'GrantedCreditLimit',
			'GrantedDownpayment',
			} = sql::execute( $log, $dbh, $_, $credit_app );

		$variable{'FinancialStatementAvailable'} = $variable{'FinancialStatementAvailable'} eq 'Y' ? 'Yes' : 'No';
		$variable{'verdict'.$variable{'verdict'}} = 'CHECKED';

		my $customer_credit = new openprint::customer_credit( $variable{'hiddenCustomerID'}, $session{'company_id'} );

		my $Company = $variable{'Company'} = new openprint::Company( $variable{'hiddenCustomerID'} );
		my $User = $variable{'User'} = new openprint::User( $variable{'UserIndex'} );

		@$variable{ keys %credit_fields } = ssi::htmlize( $customer_credit->get( @credit_fields{ keys %credit_fields } ) );
		$variable{'rdbTerms'.$variable{'rdbTerms'}} = 'CHECKED';

	} # end if
} # end sub admin_credit_app

1;
__END__
