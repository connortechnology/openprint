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


sub configuration {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $openprint::param{'btnFunction'} eq 'Save' ) {
		my @config = sql::execute( $log, $dbh, 'SELECT Name, Value, Type FROM Configuration ORDER BY lower(category), name' );
		while ( my ( $name, $value, $type ) = splice @config,0,3 ) {
$log->debug("param: $name old: $value new: $openprint::param{$name}");
			my $newvalue = $openprint::param{$name};
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
    my ( $r, $log, $dbh, $variable ) = @_;

    if ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $key ( keys %openprint::param ) {
			if ( $key =~ /chkDelete-(.*)-(.*)/ ) {
				sql::execute( $log, $dbh, q{DELETE FROM Taxes WHERE Country=? AND State=?}, $1, $2 );
				
            # Add record to audit log - action "Delete Taxes".
            openprint::logs::insertLogRecord('74', "Country: $1 | State: $2",);
			} # end if
		} # end foreach
		sql::end_transaction( $dbh, $ac );
    } elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		my $ac = sql::start_transaction( $dbh );
		my @data = sql::execute( $log, $dbh, 'SELECT Country, State FROM Taxes' );
		while ( my ( $country, $state ) = splice @data, 0, 2 ) {
			sql::update( $log, $dbh, 'Taxes', [ 'Country=? AND State=?', $country, $state ], [
				'dblStatePercent', ( $openprint::param{"txtSST$state"} ? $openprint::param{"txtSST$state"} : undef ),
				'dblFederalPercent', ( $openprint::param{"txtFST$state"} ? $openprint::param{"txtFST$state"} : undef ),
				'dblHarmonisedPercent', ( $openprint::param{"txtHST$state"} ? $openprint::param{"txtHST$state"} : undef ),
				]
				);

         # Add record to audit log - action "Delete Taxes".
         openprint::logs::insertLogRecord('73', "$country, $state - State: " . $openprint::param{"txtSST$state"} . " | Federal: " . $openprint::param{"txtFST$state"} . " | Harmonised: " . $openprint::param{"txtHST$state"},);
				
        } # end foreach
		sql::insert( $log, $dbh, 'Taxes',[ 'Country', $openprint::param{'txtCountryNew'}, 
				'State', $openprint::param{'txtStateNew'},
				'dblStatePercent',	( $openprint::param{'txtSSTNew'} ? $openprint::param{"txtSSTNew"} : undef ),
				'dblFederalPercent', ( $openprint::param{'txtFSTNew'} ? $openprint::param{"txtFSTNew"} : undef ),
				'dblHarmonisedPercent',	( $openprint::param{'txtHSTNew'} ? $openprint::param{"txtHSTNew"} : undef ),
				] );

		if($openprint::param{'txtCountryNew'}) {
# Add record to audit log - action "Delete Taxes".
			openprint::logs::insertLogRecord('74', $openprint::param{'txtCountryNew'} . ", " . $openprint::param{'txtStateNew'} . " - State: " . $openprint::param{"txtSSTNew"} . " | Federal: " . $openprint::param{"txtFSTNew"} . " | Harmonised: " . $openprint::param{"txtHSTNew"} ,);
		} # end if

		sql::end_transaction( $dbh, $ac );
    } # end if
} # end sub taxes 

sub currency {
    my ( $r, $log, $dbh, $variable ) = @_;

    if ( $openprint::param{'btnFunction'} eq 'Save' ) {

      # Add record to audit log - action "Update Currency".
      openprint::logs::insertLogRecord('76',);

        if ( $openprint::param{'strName'} ) {
			my $Currency = new openprint::Currency();
			$Currency->name($openprint::param{'strName'});
			$Currency->short($openprint::param{'strShort'});
			$Currency->symbol($openprint::param{'strSymbol'});
			$Currency->save();
        } # end if

		foreach my $Currency ( openprint::Currency::find() ) {
			if ( $openprint::param{'strName'.$Currency->id()} ) {
				$Currency->name($openprint::param{'strName'.$Currency->id()});
				$Currency->short($openprint::param{'strShort'.$Currency->id()});
				$Currency->symbol($openprint::param{'strSymbol'.$Currency->id()});
				$Currency->save();
            } # end if
        } # end foreach
    } # end if

} # end sub currency_edit

sub user_profiles {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $user_id = $openprint::param{'ddmUser'};
	my $user_role = $openprint::param{'ddmUserRole'};
	my $cust_id = $openprint::param{'ddmCustomer'};


	my $User = new openprint::User( $user_id );

	if ( $openprint::param{'btnFunction'} eq '<<' ) {
		$User = $User->Prev( 'type'=>$openprint::param{'ddmUserRole'}, 'company_id'=>$openprint::param{'ddmCustomer'} );
	} elsif ($openprint::param{'btnFunction'} eq '>>') {
		$User = $User->Next( 'type'=>$openprint::param{'ddmUserRole'}, 'company_id'=>$openprint::param{'ddmCustomer'} );
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$User->delete();
		$User = $User->Next( 'type'=>$openprint::param{'ddmUserRole'}, 'company_id'=>$openprint::param{'ddmCustomer'} );
        $$variable{'information'} = 'User marked deleted.';
	} elsif ( $openprint::param{'btnFunction'} eq 'Destroy' ) {
		$User->destroy();
		$User = $User->Next( 'type'=>$openprint::param{'ddmUserRole'}, 'company_id'=>$openprint::param{'ddmCustomer'} );
        $$variable{'information'} = 'Record deleted.';

	} elsif ($openprint::param{'btnFunction'} eq 'Save') {
		if ( $openprint::param{'password'} ne $openprint::param{'verifypassword'} ) {
			return misc::error( $log, $dbh, $variable, "Passwords don't match.", "Your password and verify password fields do not match.");
		} # end if

		my @Users = openprint::User::find( 'email' => lc $openprint::param{'email'} );
		if ( @Users > 1 or ( ( @Users == 1 ) and ( $Users[0]->id() != $User->id() ) ) ) {
			return misc::error( $log, $dbh, $variable, 'User already exists.', "There is already a user with the specified email address.  Please try another.");
		} # end if

		#$openprint::param{'assistant_ids'} = '' if ! exists $openprint::param{'assistant_ids'};
		#$openprint::param{'csr_ids'} = '' if ! exists $openprint::param{'csr_ids'};
		delete $openprint::param{'password'} if ! $openprint::param{'password'};
		my $error = $User->save( \%openprint::param );

		if ( $error ) {
			return misc::error( $log, $dbh, $variable, 'Error Saving.', "There was an error saving the user's information. $error");
		} # end if

		if ( $openprint::config{mail_db_name} and $User->email() =~ /(.*)\@point\-one\.com/ ) {
			if ( $openprint::param{'VacationState'} ) {
				email::start_vacation( $r, $log, $User->email(), @openprint::param{'VacationSubject','VacationMessage'} );
			} else {
				email::stop_vacation( $r, $log, $User->email() );
			} # end if
			if ( $openprint::param{'EmailPassword'} and $openprint::param{'EmailPassword'} eq $openprint::param{'VerifyEmailPassword'} ) {
                email::set_password( $r, $log, @openprint::param{'email','EmailPassword'} );
            } # end if
            my @aliases = ();
            foreach my $alias ( split "\r\n", $openprint::param{'aliases'} ) {
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
		foreach my $cat ( ref $openprint::param{'selectUserCategories'} eq 'ARRAY' ? @{$openprint::param{'selectUserCategories'}} : $openprint::param{'selectUserCategories'} ) {
			if ( sets::isin( $cat, \@categories ) ) {
				$sth->execute( $cat, $user_id ) or $log->error( DBI->errstr );
			} # end if
		} # end foreach

		sql::execute( $log, $dbh, q{DELETE FROM Users_in_UserGroups WHERE User_Id=?}, $user_id );
		if ( $openprint::param{'UserGroups'} ) {
			foreach my $group_id ( ref $openprint::param{'UserGroups'} eq 'ARRAY' ? @{$openprint::param{'UserGroups'}} : $openprint::param{'UserGroups'} ) {
				sql::insert( $log, $dbh, 'Users_in_UserGroups', ['usergroup_id', $group_id, 'user_id', $user_id ] );
			} # end foreach
		} # end if

		$$variable{'information'} = "Record saved successfully.";
	} # end if btnFunction

	# if we don't have a selected user, pick the first one returned filtered by company and user type if specified
	my @Users = openprint::User::find( 'company_id'=>$cust_id, 'type'=>$user_role, 'order'=>'lower(strfirstname),lower(strlastname)' );

	if ( ! $User->id() ) {
		if ( sets::isin( $openprint::session{user_id}, map { $_->id() } @Users ) ) {
			$User = new openprint::User( $openprint::session{user_id} );
		} else {
			$User = $Users[0] if @Users;
		} # end if
    } # end if

	# load user fields

	$$variable{'UserIndex'} = $User->id();
	$$variable{'User'} = $User;
	$$variable{'NUM_USERS'} = scalar @Users;

	if ( $User->id() ) {
		my $count = 1;
		foreach my $U ( @Users ) {
			if ( $U->id() == $User->id() ) {
				$$variable{'EDIT_USER_NUM'} = $count;
				last;
			} # endif
			$count += 1;
		} # end foreach
	} # end if 

	if ( $openprint::config{mail_db_name} and $User->email() =~ /(.*)\@point\-one\.com/ ) {
		@$variable{'VacationState','VacationSubject','VacationMessage'} = email::get_vacation( $r, $log, $User->email() );
		@{$$variable{'Aliases'}} = email::aliases( $log, $User->email() );
		$sql::dbh = $dbh;
	} # end if

				
	# fill in User Name Drop Down Menu
    $$variable{'FILL_USER_NAME'} = ssi::make_drop_down( [ map { $_->id(), $_->name() } @Users ], $User->id() );

	# Get Marketing Category Inforamation - get all categories, and highlight the ones this user is in.
    my @available_categories = sql::execute( $log, $dbh, 'SELECT id, name FROM Marketing_Categories' );

    # get categories this customer is in we do it this way to limit databse transaction to 2.
    my @users_categories;
	if ( $User->id() ) {
		@users_categories = sql::execute( $log, $dbh,'SELECT category_id FROM Users_in_Marketing_Categories WHERE user_id=?', $User->id() );
	} # end if
	$$variable{'selectUserCategories'} = ssi::make_select( \@available_categories, \@users_categories );

} # end sub edit


sub company_profiles {
	my ( $r, $log, $dbh, $variable ) = @_;

# form field to db field mappings
	my %fields = (
			'rdbAccountActivation'  =>  'AccountActivation',
			'txtAccountNum'         =>  'AccountNumber',
			'txtCompanyName'        =>  'Name',
			'txtAddress1'           =>  'Address1',
			'txtAddress2'           =>  'Address2',
			'txtCity'               =>  'City',
			'ddmStateProvince'      =>  'StateProvince',
			'txtStateProvince'      =>  'StateProvince',
			'ddmCountry'            =>  'Country',
			'txtCountry'            =>  'Country',
			'txtPostalCode'         =>  'PostalCode',
			'txtPhone'              =>  'Phone',
			'txtExtension'          =>  'Extension',
			'txtFax'                =>  'Fax',
			'rdbLegalForm'              =>  'LegalForm',
			'txtLegalBusinessName'  =>  'LegalBusinessName',
			'txtBusinessType'       =>  'BusinessType',
			'BusinessStartDate'     =>  'BusinessStartDate',
			'txtPresidentOwner'     =>  'PresidentOwner',
			'ddmEmployees'          =>  'Employees',
			'ddmAnnualSales'        =>  'AnnualSales',
			'txtGSTNumber'          =>  'TaxNumber1',
			'txtPSTNumber'          =>  'TaxNumber2',
			'rdbGSTExempt'          =>  'TaxExempt1',
			'rdbPSTExempt'          =>  'TaxExempt2',
			'ddmPriceList'          =>  'PriceList',
			'ddmCurrency'			=>	'Currency',
			'ddmSalesPerson'        =>  'SalesPerson',
			'txtBankBranch'         =>  'BankBranch',
			'txtBankName'           =>  'BankName',
			'txtBankAccountNo'  =>  'BankAccountNumber',
			'txtBankAccountManager' =>  'BankAccountManager',
			'txtBankPhone'          =>  'BankPhone',
			'txtBankFax'            =>  'BankFax',
			'txtBankEmail'          =>  'BankEmail',
			'rdbReseller'           =>  'Reseller',
			'rdbSupplier'           =>  'Supplier',
			'txtCustomGreeting'     =>  'CustomGreeting',
			'txtPricingLevel'		=>  'Discount',
	);
	my %shipping_fields = (
			'txtShippingCompanyName'    =>  'CompanyName',
			'rdbShippingSalutation'     =>  'Salutation',
			'txtShippingFirstName'      =>  'FirstName',
			'txtShippingLastName'       =>  'LastName',
			'txtShippingAddress1'       =>  'Address1',
			'txtShippingAddress2'       =>  'Address2',
			'txtShippingCity'           =>  'City',
			'ddmShippingStateProvince'  =>  'StateProvince',
			'ddmShippingCountry'        =>  'Country',
			'txtShippingPostalCode'  => 'PostalCode',
			'txtShippingPhone'          =>  'Phone',
			'txtShippingExtension'      =>  'Extension',
			'txtShippingFax'            =>  'Fax',
			'txtShippingEmail'          =>  'Email',
	);

	my %credit_fields = (
			'txtDenyDays'          =>  'DenyDays',
			'txtWarnDays'          =>  'WarnDays',
			'txtCreditLimit'    =>  'Limit',
			'rdbCreditHold'     =>  'Hold',
			'txtDownpayment'    =>  'Downpayment',
			);

	my $index = $openprint::param{'ddmCustomer'};
	my $Company = new openprint::Company( $index );

	if ( $openprint::param{'btnFunction'} eq '<<' ) {
		$index = $Company->prev();
		$Company = new openprint::Company( $index );
	} elsif ( $openprint::param{'btnFunction'} eq '>>') {
		$index = $Company->next();
		$Company = new openprint::Company( $index );
	} elsif ( $openprint::param{'btnFunction'} eq 'Go' ) {
		if ( $openprint::param{'txtSearchAccountNum'} ne '' ) {
			( $index ) = sql::execute( $log, $dbh, 'SELECT Index from Company WHERE strAccountNum=?',$openprint::param{'txtSearchAccountNum'}); 
		} # end if 
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {

		my $customer = new openprint::obj_customer( $log, $dbh, $index );

		if ( $Company->activation() ne $openprint::param{'rdbAccountActivation'} ) {
			my %info;
			$info{'Company'} = $Company;
			my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );

			$_ = $openprint::param{'rdbAccountActivation'} eq 'Y' ? 'account_activated.html' : 'account_deactivated.html';
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . "/email_content/$_" );
			$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );

			$email_template = ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info ); 

			my @to = sql::execute( $log, $dbh, 'SELECT strEmail FROM Users WHERE CompanyIndex=?', $index );
			my %mail = (
					SMTP    => $openprint::config{'Mail Server'},
					FROM    => $openprint::config{'AdministratorEmail'},
					TO      => join( ',', @to ),
					SUBJECT => "Customer account status has changed!",
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );
		} # end if
		if ( $Company->reseller() and ( $Company->reseller() ne $openprint::param{'rdbReseller'} ) ) {
			my %info;
			my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
			$info{'Company'} = $Company;
			my @to = sql::execute( $log, $dbh, 'SELECT strEmail FROM Users WHERE CompanyIndex=?', $index );

			$_ = $openprint::param{'rdbReseller'} eq 'Y' ? 'customer_account_reseller.html' : 'customer_account_non_reseller.html';
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . "/email_content/$_" );
			$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );

			$email_template = ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info ); 
			my %mail = (
					SMTP    => $openprint::config{'Mail Server'},
					FROM    => $openprint::config{'AdministratorEmail'},
					TO      => join( ',', @to ),
					SUBJECT => "Customer account status has changed!",
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );
		} # end if
if ( 0 ) {
		if ( $Company->supplier() ne $openprint::param{'rdbSupplier'} ) {
			my %info;
			my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
			$info{'Company'} = $Company;
			my @to = sql::execute( $log, $dbh, 'SELECT strEmail FROM Users WHERE CompanyIndex=?', $index );

			$_ = $openprint::param{'rdbSupplier'} eq 'Y' ? 'customer_account_supplier.html' : 'customer_account_non_supplier.html';
			$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . "/email_content/$_" );
			$info{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$info{'ReplacementText'}, \%info );
			$email_template = ssi::variable_substitution( $r, $log, $dbh, \$email_template, \%info );
			my %mail = (
					SMTP    => $openprint::config{'Mail Server'},
					FROM    => $openprint::config{'AdministratorEmail'},
					TO      => join( ',', @to ),
					SUBJECT => 'Customer account status has changed!',
					);
			misc::send_email_with_attachment( $log, \%mail, ( '', encode_qp($email_template), 'text/html', 'quoted-printable' ) );
		} # end if
} # end if

		my %params;
		foreach my $field ( keys %fields ) {
			$params{$fields{$field}} = $openprint::param{$field} if defined $openprint::param{$field};
		} # end foreach
		if ( $openprint::param{'txtStartYear'} ) {
			$openprint::param{'ddmStartMonth'} = '01' if ! $openprint::param{'ddmStartMonth'};
			$params{'BusinessStartDate'} = $openprint::param{'txtStartYear'} . '-' . $openprint::param{'ddmStartMonth'} . '-01';
		} # end if
		$customer->set( \%params );
		$index = $customer->{index};

		if ( $index > 0 ) {
# Otherwise Error!
# Customer Categories
# I was trying to do this the hard way.  Then it occurred to me: Just delete them all from the table, and add back in the ones we want.  
			my @customercategories = sql::execute( $log, $dbh, 'SELECT id FROM Marketing_Categories' );

			sql::execute( $log, $dbh, q{DELETE FROM Companies_in_Marketing_Categories WHERE company_Id =?}, $index );
# add them back in 
			my $sth = $dbh->prepare( q{INSERT INTO Companies_in_Marketing_Categories (Category_Id,Company_Id) VALUES ( ?, ? )} );
			foreach my $cat ( $openprint::param{'selectCustomerCategories'} ) {
				if ( sets::isin( $cat, \@customercategories ) ) {
					$sth->execute( $cat, $index ) or $log->error( DBI->errstr );
				} # end if
			} # end foreach

			my %params;
			foreach my $field ( keys %shipping_fields ) {
				$params{$shipping_fields{$field}} = $openprint::param{$field} if defined $openprint::param{$field};
			} # end foreach
			$customer->save_shipping( \%params );

			openprint::customer::save_tradereferences( $r, $log, $dbh, $index );

			my $customer_credit = new openprint::customer_credit( $index );
			my %params;
			foreach my $field ( keys %credit_fields ) {
				$params{$credit_fields{$field}} = $openprint::param{$field} if defined $openprint::param{$field};
			} # end foreach
			$customer_credit->set( \%params );
		} # end if $index
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$index = $Company->next();
		$Company->delete();
		$Company = new openprint::Company( $index );
	} # end if btnFunction

# we no longer default to displaying the first record.  The user must select one.,
	if ( $index > 0 ) {
		my $customer = new openprint::obj_customer( $log, $dbh, $index );

        @$variable{ keys %fields } = ssi::htmlize( $customer->get( @fields{ keys %fields } ) );
        $$variable{'rdbReseller'.$$variable{'rdbReseller'}} = 'CHECKED';
        $$variable{'rdbSupplier'.$$variable{'rdbSupplier'}} = 'CHECKED';
        @$variable{ keys %shipping_fields } = ssi::htmlize( $customer->load_shipping( @shipping_fields{ keys %shipping_fields } ) );

		$$variable{'rdbLegalForm'.$$variable{'rdbLegalForm'}} = 'CHECKED';
		$$variable{'rdbPSTExempt'.$$variable{'rdbPSTExempt'}} = 'CHECKED';
		$$variable{'rdbGSTExempt'.$$variable{'rdbGSTExempt'}} = 'CHECKED';
		
		$$variable{'rdbAccountActivation'.$$variable{'rdbAccountActivation'}} = 'CHECKED';

		$$variable{'txtPricingLevel'} = sprintf ( "%.0f", $$variable{'txtPricingLevel'} ) . "%";
		$$variable{'txtDownpayment'} = sprintf ( "%.0f", $$variable{'txtDownpayment'} ) . "%";

		openprint::customer::load_tradereferences( $r, $log, $dbh, $index, $variable );
		my $shipping_address = $customer->get_shipping_address();
		@$variable{ keys %shipping_fields } = ssi::htmlize( $shipping_address->get( @shipping_fields{ keys %shipping_fields } ) );
		$$variable{'rdbShippingSalutation'.$$variable{'rdbShippingSalutation'}} = 'CHECKED';

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
    $$variable{'selectCustomerCategories'} = ssi::make_select( \@available_categories, \@customers_categories );

	@$variable{'txtStartYear','ddmStartMonth'} = $$variable{'BusinessStartDate'} =~ /^(\d+)-(\d+)-(\d+)/;
    $$variable{'ddmStartMonth'} = ssi::getmonths( $$variable{'ddmStartMonth'} );

    $$variable{'ddmSalesPeople'} = ssi::make_drop_down( [ map { $_->id(), $_->name() } openprint::User::find('type'=>'E', 'web_active'=>'Y', 'order'=>'lower(strfirstname),lower(strlastname)') ], $$variable{'ddmSalesPerson'} );

	$$variable{'ddmEmployees'} = ssi::getemployee_numbers( $r, $log, $dbh, $$variable{'ddmEmployees'} );
	$$variable{'ddmAnnualSales'} = ssi::getannual_sales( $r, $log, $dbh, $$variable{'ddmAnnualSales'} );

	$$variable{'ddmStateProvince'} = ssi::return_states_and_provinces($$variable{'ddmStateProvince'});
	$$variable{'ddmCountry'} = ssi::return_countries($$variable{'ddmCountry'});
	$$variable{'ddmShippingStateProvince'} = ssi::return_states_and_provinces($$variable{'ddmShippingStateProvince'});
	$$variable{'ddmShippingCountry'} = ssi::return_countries($$variable{'ddmShippingCountry'});

    $_ = "SELECT Index, Name FROM Pricelists ORDER BY lower(Name)";
    $$variable{'ddmPriceList'} = ssi::fill_drop_down( $log, $dbh, $_, $$variable{'ddmPriceList'} );

	my $total;
	my $payments;
	if ( $index ) {
		$_ = "SELECT SUM(curTotalSale) FROM Orders WHERE CompanyIndex='$index'\n".
			"AND strStatus IN ('Pending Deposit','In Production','Paid')";
		( $total ) = sql::execute( $log, $dbh, $_ );
		( $payments ) = sql::execute( $log, $dbh, 'SELECT SUM(curAmount) FROM Payments WHERE company_id=?',$index);
	} # end if

	$$variable{'CreditBalance'} = '$ '.sprintf( "%.2f", ( $total - $payments ) );
	if ( $$variable{'txtCreditLimit'} < ($total - $payments) ) {
		$$variable{'CreditRemaining'} = '$ 0.00';
	} else {
		$$variable{'CreditRemaining'} = '$ '.sprintf( '%.2f', ( $$variable{'txtCreditLimit'} - ($total - $payments) ) );
	} # end if

	$$variable{'CustomerIndex'} = $index;
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

				if ( ! sql::execute( $log, $dbh, 'SELECT index FROM company WHERE index=?', $$variable{'hiddenCustomerID'} ) ) {
					return misc::error( $log, $dbh, $variable, 'Deleted Customer', "The company that created this credit app has been deleted from the system.  This credit app has been deleted." );
				} # end if

				$$variable{'FinancialStatementAvailable'} = $$variable{'FinancialStatementAvailable'} eq 'Y' ? 'Yes' : 'No';

				my $customer_credit = new openprint::customer_credit( $$variable{'hiddenCustomerID'}, $openprint::session{'company_id'} );
				my %params;

				foreach my $field ( keys %credit_fields ) {
					$params{$credit_fields{$field}} = $r->param($field) if defined $r->param($field);
				} # end foreach
				$params{'txtSignature'} = $$variable{'Signature'};
				$customer_credit->set( \%params );
				$params{'siteURL'} = $openprint::config{'siteURL'};
				$params{'SecureSiteURL'} = $openprint::config{'SecureSiteURL'};

				my ( $email ) = sql::execute( $log, $dbh, 'SELECT strEmail FROM Users WHERE index=?', $$variable{'UserIndex'} );

				$params{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/credit_change_notification.html' );
				$params{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$params{'ReplacementText'}, \%params );
				$_ = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/email_template.html' );
				my $template = ssi::variable_substitution( $r, $log, $dbh, \$_, \%params );
				my %mail = (
						SMTP	=> $openprint::config{'Mail Server'},
						FROM	=> $openprint::config{'AdministratorEmail'},
						TO		=> $email,
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

	@{$$variable{'CreditApps'}} = ();
	$_ = "SELECT Id, strSignature, date(dtmCreationDate), (SELECT strName FROM Company WHERE index=company_id), strStatus\n".
		"FROM CreditApplications\n".
		"WHERE date(dtmCreationDate) BETWEEN date('$$variable{'StartDate'}') AND date('$$variable{'EndDate'}')\n";
	$_ .= "AND strStatus = 'Approved'\n" if $r->param('ddmStatus') eq 'Approved';
	$_ .= "AND strStatus = 'Declined'\n" if $r->param('ddmStatus') eq 'Declined';
	$_ .= "AND strStatus != 'Non-Reviewed'\n" if $r->param('ddmStatus') eq 'Reviewed';
	$_ .= "AND strStatus = 'Non-Reviewed'\n" if $r->param('ddmStatus') eq 'Non-Reviewed';
	$_ .= "AND company_Id = '".$r->param('ddmCompany')."'\n" if $r->param('ddmCompany');
	#$_ .= "AND lngSupplierIndex = '$openprint::session{'company_id'}'";
	$_ .= "ORDER BY dtmCreationDate, Id";
	@{$$variable{'CreditApps'}} = sql::execute( $log, $dbh, $_ );

	$$variable{$r->param('ddmStatus')} = 'SELECTED';
} # end sub credit_applications

sub credit_application {
	my ( $r, $log, $dbh, $variable ) = @_;

	my %credit_fields = (
		'txtTerms'			=>	'Terms',
		'CreditLimit'		=>	'CreditLimit',
		'txtDownpayment'	=>	'Downpayment',
	);

	my $credit_app = $r->param('credit_index');
	$$variable{'credit_index'} = $credit_app;

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

		$$variable{'FinancialStatementAvailable'} = $$variable{'FinancialStatementAvailable'} eq 'Y' ? 'Yes' : 'No';
		$$variable{'verdict'.$$variable{'verdict'}} = 'CHECKED';

		my $customer_credit = new openprint::customer_credit( $$variable{'hiddenCustomerID'}, $openprint::session{'company_id'} );

		my $Company = $$variable{'Company'} = new openprint::Company( $$variable{'hiddenCustomerID'} );
		my $User = $$variable{'User'} = new openprint::User( $$variable{'UserIndex'} );

		@$variable{ keys %credit_fields } = ssi::htmlize( $customer_credit->get( @credit_fields{ keys %credit_fields } ) );
		$$variable{'rdbTerms'.$$variable{'rdbTerms'}} = 'CHECKED';

	} # end if
} # end sub admin_credit_app

1;
__END__
