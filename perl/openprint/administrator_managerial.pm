use strict;
package openprint::administrator_managerial;

use openprint ();

require sql;
require ssi;
require configuration;
require Configuration;
require email;
require openprint::Currency;
require openprint::User;
require openprint::User_Type;
require openprint::logs;
require openprint::address;
require openprint::Company;
require openprint::Company_Profile;
require openprint::Tax;
require openprint::Email;
require openprint::Email_Account;
require openprint::UserGroup;
require openprint::Invoice;
require openprint::Payment;
require openprint::Timetrack;
require openprint::User_Profile_Field;
require openprint::Company_Profile_Field;
require openprint::Company_Category;
require openprint::Company_Credit;

require Authen::Passphrase;
require Authen::Passphrase::BlowfishCrypt;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub configuration {

	if ( $param{'btnFunction'} eq 'New' ) {
		if ( sql::execute( $log, $dbh, 'SELECT * FROM Configuration WHERE name=? LIMIT 1', $param{'name'} ) ) {
			sql::update( $log, $dbh, 'configuration', [ 'name=?', $param{'name'} ], {
				'description'	=>	$param{'description'},
				'type'			=>	$param{'type'},
				'category'		=>	( $param{'new_category'} ? $param{'new_category'} : $param{'category'} ),
				'value'			=>	$param{'value'},
			} );
		} else {
			sql::insert( $log, $dbh, 'configuration', {
				'name'	=>	$param{'name'},
				'description'	=>	$param{'description'},
				'type'			=>	$param{'type'},
				'category'		=>	( $param{'new_category'} ? $param{'new_category'} : $param{'category'} ),
				'value'			=>	$param{'value'},
			} );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		foreach my $C ( Configuration->find() ) {
			if ( ! exists $param{$$C{name}} ) {
				$log->error("No value in param for $$C{name}");
				next;
			} # end if

			my $new_value = $param{$$C{name}};
			if ( $$C{type} eq 'list' ) {
				$new_value = join(',', misc::trim( split(',', $new_value ) ) );
			} # end if

			my $name = $$C{name};
			if ( $$C{name} ne Configuration->transform('name',$name) ) {
$log->debug("Name change detected: $$C{name}");
				$variable{error} .= $C->delete();
				$C->description( $$C{name} ) if ! $C->description();
				$variable{error} .= $C->save({value=>$new_value, name=>$$C{name},  });
			} elsif ( $$C{value} ne $new_value ) {
				$C->save({ value=>$new_value });
			} else {
				$log->debug("Value unchanged for $$C{name}: currnet: $$C{value} new: $param{$$C{name}}");
			} # end if
		} # end while

		# Add record to audit log - action "Update Configuration".
		new openprint::Log()->save({'action'=>'Update Configuration'});
	} elsif ( $param{'action'} eq 'delete' ) {
		sql::execute( undef, undef, 'DELETE FROM Configuration WHERE name=?', $param{'name'} );
	} # end if
} # end sub configuration

sub _configuration {
	if ( $param{'action'} eq 'delete' ) {
		sql::execute( undef, undef, 'DELETE FROM Configuration WHERE name=?', $param{'name'} );
	} # end if
} # end sub _configuration

sub _configuration_popup {
	if ( $param{name} ) {
		$variable{Entry} = Configuration->find_one(name=>$param{name});
		if ( ! $variable{Entry} ) {
			$variable{Entry} = new Configuration();
			$variable{error} = "No entry found for $param{name}<br/>";
		} # end if
	} else {
		$variable{Entry} = new Configuration();
	} # end if
} # end sub

sub taxes {

	if ( $param{'btnFunction'} eq 'Delete' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $id ( ref $param{'tax_ids'} eq 'ARRAY' ? @{$param{'tax_ids'}} : $param{'tax_ids'} ) {
			my $Tax = new openprint::Tax( $id );
			openprint::logs::insertLogRecord('74', sprintf('Country: %s | State: %s', $Tax->country(), $Tax->state() ) );
			$variable{'error'} .= $Tax->delete();
		} # end foreach
		sql::end_transaction( $dbh, $ac );
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $Tax ( openprint::Tax->find() ) {
			$variable{'error'} .= $Tax->save({
				'name'			=>	$param{'name-'.$Tax->id()},
				'rate'			=>	$param{'rate-'.$Tax->id()},
				'period_start'	=> ( Date::Calc::check_date( @param{'period_start-'.$$Tax{id}.'_year','period_start-'.$$Tax{id}.'_month','period_start-'.$$Tax{id}.'_day'} ) ? sprintf('%.4d-%.2d-%.2d', @param{'period_start-'.$$Tax{id}.'_year','period_start-'.$$Tax{id}.'_month','period_start-'.$$Tax{id}.'_day'} ) : undef ),
				'period_end'	=> ( Date::Calc::check_date( @param{'period_end-'.$$Tax{id}.'_year','period_end-'.$$Tax{id}.'_month','period_end-'.$$Tax{id}.'_day'} ) ? sprintf('%.4d-%.2d-%.2d', @param{'period_end-'.$$Tax{id}.'_year','period_end-'.$$Tax{id}.'_month','period_end-'.$$Tax{id}.'_day'} ) : undef ),
				});
		} # end foreach Tax
		if ( $param{'rate-New'} ) {
			my $Tax = new openprint::Tax();
			$variable{'error'} .= $Tax->save({
				'name'			=>	$param{'name-New'},
				'rate'			=>	$param{'rate-New'},
				'country'		=>	$param{'country-New'},
				'state'			=>	$param{'state-New'},
				'period_start'	=> ( Date::Calc::check_date( @param{'period_start-New_year','period_start-New_month','period_start-New_day'} ) ? sprintf('%.4d-%.2d-%.2d', @param{'period_start-New_year','period_start-New_month','period_start-New_day'} ) : undef ),
				'period_end'	=> ( Date::Calc::check_date( @param{'period_end-New_year','period_end-New_month','period_end-New_day'} ) ? sprintf('%.4d-%.2d-%.2d', @param{'period_end-New_year','period_end-New_month','period_end-New_day'} ) : undef ),
				});
		} # end if New Tax

		sql::end_transaction( $dbh, $ac );
	} # end if
} # end sub taxes 

sub currency {
	if ( $param{'btnFunction'} eq 'Save' ) {
		# Add record to audit log - action "Update Currency".
		(new openprint::Log())->save({action=>'Update Currency'});

		if ( $param{name} ) {
			my $Currency = new openprint::Currency();
			$variable{error} .= $Currency->save({
				name	=>	$param{name},
				short	=>	$param{short},
				symbol	=>	$param{symbol},
				});
		} # end if

		foreach my $Currency ( openprint::Currency->find() ) {
			if ( $param{'name-'.$Currency->id()} ) {
				$variable{error} .= $Currency->save({
						name	=>	$param{'name-'.$$Currency{id}},
						short	=>	$param{'short-'.$$Currency{id}},
						symbol	=>	$param{'symbol-'.$$Currency{id}},
						});
			} # end if
		} # end foreach
	} # end if

} # end sub currency

sub _currency_conversions {
	$variable{Currency} = new openprint::Currency( $param{currency_id} );
	if ( $param{btnFunction} eq 'Add' ) {

		my $now = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', Date::Calc::Today_and_Now() );
		# Find current
        my $Conversion = openprint::Currency_Conversion->find_one(from_id=>$param{currency_id}, to_id=>$param{to_id}, period_end=>undef);
        if ( ! $Conversion ) {
            $Conversion = new openprint::Currency_Conversion();
            $variable{error} .= $Conversion->save({
					from_id	=>	$param{currency_id}, 
					to_id	=>	$param{to_id},
					rate	=>	$param{amount},
					});
        } elsif (Math::Round::nearest(0.01,$Conversion->rate()) != Math::Round::nearest(0.01, $param{amount} ) ) {
            $variable{error} .= $Conversion->save({period_end=>$now});
            $variable{error} .= $Conversion->save({id=>undef,
					period_start=>$now,
					period_end	=>	undef,
					rate=>$param{amount}});
		} else {
			$variable{warning} .= 'No change made.';
        } # end if

        $Conversion = openprint::Currency_Conversion->find_one(to_id=>$param{currency_id}, from_id=>$param{to_id}, period_end=>undef);
        if ( ! $Conversion ) {
            $Conversion = new openprint::Currency_Conversion();
            $variable{error} .= $Conversion->save({
					to_id	=>	$param{currency_id},
					from_id	=>	$param{to_id},
					rate	=>	Math::Round::nearest(0.0001,1/$param{amount}),
					});
        } elsif ( $Conversion->rate() != Math::Round::nearest(0.0001, 1/$param{amount}) ) {
            $variable{error} .= $Conversion->save({period_end=>$now});
            $variable{error} .= $Conversion->save({
					id			=>	undef,
					period_start=>	$now,
					period_end	=>	undef,
					rate		=>	Math::Round::nearest(0.0001,1/$param{amount}),
					});
        } # end if
	} # end if
} # end sub currency_conversions

sub user_profiles {

	my $user_id = $param{ddmUser} ? openprint::User->transform( 'id', $param{ddmUser} ) : undef;
	my $User = $variable{User} = new openprint::User( $user_id );

	my $user_role = $param{'ddmUserRole'};

	if ( exists $param{ddmCustomer} ) {
		if ( $param{ddmCustomer} and ( $User->company_id() != $param{ddmCustomer} ) ) {
			# Prevent selection of user from another company
			$User = new openprint::User();
		} # end if
	} else {
		# The porpose of this code was something to do with selecting by email address. It would load the user, but not change the
		$param{'ddmCustomer'} = $User->company_id() if $User->id();
	} # end if

	# selected company
	my $cust_id = $param{'ddmCustomer'};
	$cust_id = $session{'company_id'} if ! $cust_id;

	if ( $param{'btnFunction'} eq '<<' ) {
		$User = $User->Prev( 'type'=>$param{'ddmUserRole'}, 'company_id'=>$param{'ddmCustomer'} );
	} elsif ($param{'btnFunction'} eq '>>') {
		$User = $User->Next( 'type'=>$param{'ddmUserRole'}, 'company_id'=>$param{'ddmCustomer'} );
    } elsif ( $param{'btnFunction'} eq 'merge' ) {
		if ( $$User{id} == $openprint::param{merge_user_id} ) {
			$variable{error} .= 'Choose a different user to merge into.';
		} else {
			my $ac = sql::start_transaction( $dbh );
			foreach my $type ( 'Order','Quote','Project', 'Log','Timetrack' ) {
				require "openprint/$type.pm";
				foreach ( "openprint::$type"->find( user_id=>$param{merge_user_id}) ) {
					$variable{error} .= $_->save({user_id=>$User->id()});
				} # end foreach
			} # end foreach type
			foreach my $type ( 'Claim', 'PurchaseOrder' ) {
				require "openprint/$type.pm";
				foreach ( "openprint::$type"->find( contact_id=>$param{merge_user_id}) ) {
					$variable{error} .= $_->save({contact_id=>$User->id()});
				} # end foreach
			} # end foreach type
			new openprint::User( $param{merge_user_id} )->delete();
			sql::end_transaction( $dbh, $ac );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Undelete' ) {
		if ( $_ = $User->undelete() ) {
			$variable{'error'} .= "Error undeleting user: $_<br/>";
		} else {
			$variable{'information'} = 'User undeleted successfully.';
		} # end if
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

		my @Users = openprint::User->find( 'email lc' => lc $param{email} ) if $param{email};
		if ( @Users > 1 or ( ( @Users == 1 ) and ( $Users[0]->id() != $User->id() ) ) ) {
			my $error = "There is already one or more users with the specified email address.  They are listed below:<br/>";
			foreach my $U ( @Users ) {
				$error .= sprintf('<a href="/administrator/managerial/user_profiles.html?ddmUser=%d">%s : %s &lt;%s&gt; %s</a><br/>', $U->id(), $U->Company()->name(), $U->name(), $U->email(), $U->deleted() ? 'deleted' : '' );
			} # end foreach U
		
			return misc::error( $log, $dbh, \%variable, 'User already exists.', $error);
		} # end if

		if ( ! $param{password} ) {
			delete $param{password};
		} elsif ( $config{encrypt_passwords} ) {
			my $ppr = Authen::Passphrase::BlowfishCrypt->from_rfc2307($User->password());
			if ( ! $ppr->match($param{password}) ) {
				$param{password_changed_on} = 'NOW()';
				my $ppr = Authen::Passphrase::BlowfishCrypt->new( cost => 8, salt_random => 1, passphrase => $param{password} );
				$param{password} = $ppr->as_rfc2307();
			} else {
				delete $param{password};
			} # end if
		
		} elsif ( $param{password} ne $User->password() ) {
			$param{password_changed_on} = 'NOW()';
		} # end if

		# This has to exist, in order to save the no assistants situation
		$param{'assistant_ids'} = [] if ! exists $param{'assistant_ids'};
		$param{'csr_ids'} = [] if ! exists $param{'csr_ids'};
		my $error = $User->save( \%param );
		if ( ! $error ) {
			$User->Profile()->save( \%param );
			foreach my $Type ( openprint::PurchaseOrder_ContentType->find() ) {
				$User->po_limit( $Type->id(), $param{'po_limit-'.$Type->id()} );
			} # end foreach Type
		} # end if

		if ( $error ) {
			return misc::error( $log, $dbh, \%variable, 'Error Saving.', "There was an error saving the user's information. $error");
		} # end if

		if ( $config{mail_db_name} ) {
			my @domains = email::domains();
			my ( $user, $domain ) = $User->email() =~ /^([^\@]+)\@(.+)$/;
			if ( sets::isin( $domain, \@domains ) ) {
				if ( $param{'VacationState'} ) {
					email::start_vacation( $User->email(), @param{'VacationSubject','VacationMessage'} );
				} else {
					email::stop_vacation( $User->email() );
				} # end if
				if ( $param{'EmailPassword'} and $param{'EmailPassword'} eq $param{'VerifyEmailPassword'} ) {
					email::set_password( @param{'email','EmailPassword'} );
				} # end if
				my @aliases = ();
				foreach my $alias ( split "\r\n", $param{'aliases'} ) {
					next if ! $alias;
					push @aliases, $alias;
				} # end foreach
				push @aliases, $User->email() if ! @aliases;
				email::aliases( $User->email(), @aliases );
			} # end if
		} # end if

		my @categories = sql::execute( $log, $dbh, 'SELECT id FROM Marketing_Categories' );

		sql::execute( $log, $dbh, 'DELETE FROM Users_in_Marketing_Categories WHERE user_id=?', $User->id() );

		# add them back in 
		my $sth = $dbh->prepare( q{INSERT INTO Users_in_Marketing_Categories (category_id,user_id) VALUES ( ?, ? )} );
		foreach my $cat ( ref $param{'selectUserCategories'} eq 'ARRAY' ? @{$param{'selectUserCategories'}} : $param{'selectUserCategories'} ) {
			if ( sets::isin( $cat, \@categories ) ) {
				$sth->execute( $cat, $User->id() ) or $log->error( DBI->errstr );
			} # end if
		} # end foreach

		sql::execute( $log, $dbh, q{DELETE FROM users_in_userGroups WHERE user_id=?}, $User->id() );
		if ( $param{'UserGroups'} ) {
			foreach my $group_id ( ref $param{'UserGroups'} eq 'ARRAY' ? @{$param{'UserGroups'}} : $param{'UserGroups'} ) {
				sql::insert( $log, $dbh, 'users_in_usergroups', ['usergroup_id', $group_id, 'user_id', $User->id() ] );
			} # end foreach
		} # end if

		foreach my $service_default_id ( sql::execute( undef, undef, 'SELECT id FROM User_Service_Defaults WHERE user_id=?', $User->id() ) ) {
			if ( $param{'name-'.$service_default_id} ) {
				sql::update( undef, undef, 'User_Service_Defaults', ['id=?'=>$service_default_id], {
						'servicetype_id'=>$param{'servicetype_id-'.$service_default_id} ? $param{'servicetype_id-'.$service_default_id} : undef,
						'name'=>$param{'name-'.$service_default_id},
						'value'=>$param{'value-'.$service_default_id}
						});
			} else {
				sql::execute( undef, undef, 'DELETE FROM User_Service_Defaults WHERE id=?', $service_default_id );
			} # end if
		} # end foreach
		if ( $param{'name-'} ) {
			sql::insert( undef, undef, 'User_Service_Defaults', {
					user_id			=>	$User->id(),
					servicetype_id	=>	$param{'servicetype_id-'} ? $param{'servicetype_id-'} : undef,
					name			=>	$param{'name-'},
					value			=>	$param{'value-'} 
					} );
		} # end if

		my %notifications;
		my %types = sql::execute(undef,undef,'SELECT id,name FROM User_Notification_Types');
		foreach my $k ( keys %types ) {
			$notifications{$types{$k}} = $param{"notification_$k"};
		} # end foreach
		$User->notifications( \%notifications );

		$variable{'information'} = 'Record saved successfully.';
		$variable{ExternalRedirect} = '/administrator/managerial/user_profiles.html?ddmUser='.$User->id();
	} # end if btnFunction

	# if we don't have a selected user, pick the first one returned filtered by company and user type if specified
	my @Users = openprint::User->find( 
		( $cust_id ? ( 'company_id'=>$cust_id ) : () ), 
		( $user_role ? ( 'type'=>$user_role ) : () ),
		( $param{'deleted'} ne '' ? ( 'deleted'=>$param{'deleted'} ) : () ),
		'order'=>'lower(firstname),lower(lastname)'
		);

	if ( $User->deleted() ) {
		unshift @Users, $User;
	} # end if

	if ( ! $User->id() ) {
		if ( sets::isin( $session{user_id}, map { $_->id() } @Users ) ) {
			$User = new openprint::User( $session{user_id} );
		} else {
			$User = $Users[0] if @Users;
		} # end if
    } # end if
	if ( $User->id() ) {
		if ( $User->deleted() ) {
			unshift @Users, $User;
		} elsif ( ! sets::isin( $User->id(), [ map { $_->id() } @Users ] ) ) {
			unshift @Users, $User;
		} # end if
    } # end if

	# load user fields

	$param{ddmCustomer} = $cust_id if ! $param{ddmCustomer};
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

	if ( $config{mail_db_name} ) {
		my @domains = email::domains();
		my ( $user, $domain ) = $User->email() =~ /^([^\@]+)\@(.+)$/;
		if ( sets::isin( $domain, \@domains ) ) {
			$variable{'DoEmail'} = 1;
			@variable{'VacationState','VacationSubject','VacationMessage'} = email::get_vacation( $User->email() );
			@{$variable{'Aliases'}} = email::aliases( $User->email() );
		} # end if
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
	$variable{'selectUserCategories'} = ssi::make_drop_down( \@available_categories, \@users_categories );

	$session{$r->uri().'?company_id'} = $param{ddmCustomer};

} # end sub user_profiles


sub company_profiles {

# form field to db field mappings
	my %shipping_fields = (
			'txtShippingCompanyName'	=>	'CompanyName',
			'rdbShippingSalutation'	 	=>	'Salutation',
			'txtShippingFirstName'		=>	'FirstName',
			'txtShippingLastName'		=>	'LastName',
			'txtShippingAddress1'		=>	'Address1',
			'txtShippingAddress2'		=>	'Address2',
			'txtShippingCity'			=>	'City',
			'ddmShippingStateProvince'	=>	'StateProvince',
			'ddmShippingCountry'		=>	'Country',
			'txtShippingPostalCode'		=> 'PostalCode',
			'txtShippingPhone'			=>	'Phone',
			'txtShippingExtension'		=>	'Extension',
			'txtShippingFax'			=>	'Fax',
			'txtShippingEmail'			=>	'Email',
	);

	my $index = $param{'ddmCustomer'};
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
	} elsif ( $param{'btnFunction'} eq 'merge' ) {
		if ( $openprint::param{'ddmCustomer'} == $openprint::param{'merge_company_id'} ) {
			$variable{'error'} .= 'Choose a different company to merge into.';
		} else {
			my $ac = sql::start_transaction( $dbh );
			my $Company = new openprint::Company( $index );
			foreach my $type ( 'User','Order','Quote','Project', 'Claim', 'Log','Timetrack' ) {
				require "openprint/$type.pm";
				foreach ( "openprint::$type"->find( company_id=>$param{'merge_company_id'}) ) {
					$_->save({'company_id'=>$Company->id()});
				} # end foreach
			} # end foreach type
			foreach my $Timetrack ( openprint::Timetrack->find('owner_id'=>$param{'merge_company_id'}) ) {
				$Timetrack->save({'owner_id'=>$Company->id()});
			} # end foreach Timetrack
			foreach ( openprint::Invoice->find('invoicer_id'=>$param{'merge_company_id'}) ) {
				$_->save({'invoicer_id'=>$Company->id()});
			} # end foreach 
			foreach ( openprint::Invoice->find('invoicee_id'=>$param{'merge_company_id'}) ) {
				$_->save({'invoicee_id'=>$Company->id()});
			} # end foreach 
			foreach my $Payment ( openprint::Payment->find('payor_id'=>$param{'merge_company_id'}) ) {
				$Payment->save({'payor_id'=>$Company->id()});
 #if $Payment->payor_id() == $Company->id();
			} # end foreach  Payment
			foreach my $Payment ( openprint::Payment->find('recipient_id'=>$param{'merge_company_id'}) ) {
				$Payment->save({'recipient_id'=>$Company->id()});
# if $Payment->recipient_id() == $Company->id();
			} # end foreach  Payment
			foreach my $Stock ( openprint::Paper->find(supplier_id=>$param{merge_company_id}) ) {
				$Stock->save({supplier_id=>$Company->id()});
 #if $_->supplier_id() == $Company->id();
			} # end foreach  Stock
			new openprint::Company( $param{'merge_company_id'} )->delete();
			sql::end_transaction( $dbh, $ac );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		if ( ! $param{name} ) {
			$variable{error} .= 'Empty company name. You must supply a Company Name.<br/>';
		} else {
			$index = $param{'company_id'};
			$Company = new openprint::Company( $param{'company_id'} );
			$param{'start_year'} =~ s/\D//g;
			if ( $param{'start_year'} ) {
				$param{'start_month'} = '01' if ! $param{'start_month'};
				$param{'established'} = $param{'start_year'} . '-' . $param{'start_month'} . '-01';
			} # end if
			$variable{'error'} .= $Company->save( \%param );
			$index = $Company->id();

			if ( $index > 0 ) {
				my $ac = sql::start_transaction( $dbh );
				$Company->Profile()->save( \%param );
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
				$Company->save_shipping( \%params );

				$Company->save_tradereferences( \%param );

				$dbh->do( 'LOCK TABLE Company_Credit IN ACCESS EXCLUSIVE MODE' ) or $log->error( DBI->errstr );

				foreach my $Supplier ( openprint::Company->find('offers_credit'=>1) ) {
					my $Credit = new openprint::Company_Credit( {'company_id'=>$index, 'supplier_id'=>$Supplier->id() } );

					if (
							( $Credit->terms() != openprint::Company_Credit->transform('terms', $param{'terms-'.$$Supplier{id}} ) ) or
							( $Credit->denydays() != openprint::Company_Credit->transform('denydays', $param{'denydays-'.$$Supplier{id}} ) ) or
							( $Credit->warndays() != openprint::Company_Credit->transform('warndays', $param{'warndays-'.$$Supplier{id}} ) ) or
							( $Credit->limit() != openprint::Company_Credit->transform('limit', $param{'limit-'.$$Supplier{id}} ) ) or
							( $Credit->hold() ne openprint::Company_Credit->transform('hold', $param{'hold-'.$$Supplier{id}} ) ) or
							( $Credit->downpayment() != openprint::Company_Credit->transform('downpayment', $param{'downpayment-'.$$Supplier{id}} ) ) or
							( $Credit->cod() != openprint::Company_Credit->transform('cod', $param{'cod-'.$$Supplier{id}} ) ) or
							( $Credit->late_payment_amount() != openprint::Company_Credit->transform('late_payment_amount', $param{'late_payment_amount-'.$$Supplier{id}} ) ) or
							( $Credit->late_payment_units() ne openprint::Company_Credit->transform('late_payment_units', $param{'late_payment_units-'.$$Supplier{id}} ) ) or
							( $Credit->early_payment_amount() != openprint::Company_Credit->transform('early_payment_amount', $param{'early_payment_amount-'.$$Supplier{id}} ) ) or
							( $Credit->early_payment_units() ne openprint::Company_Credit->transform('early_payment_units', $param{'early_payment_units-'.$$Supplier{id}} ) ) or
							( $Credit->early_payment_days() != openprint::Company_Credit->transform('early_payment_days', $param{'early_payment_days-'.$$Supplier{id}} ) )
					   ) {
						my $note = 'Old credit: ' . $Credit->to_string() if $Credit->supplier_id();
						$variable{'error'} .= $Credit->save( { 'company_id'=>$index, 'supplier_id'=>$Supplier->id(), 
								map { $_ => $param{$_.'-'.$Supplier->id()} } ( 'terms', 'denydays', 'warndays', 'limit', 'hold', 'downpayment', 'cod', 'late_payment_amount','late_payment_units','early_payment_amount','early_payment_units', 'early_payment_days' ) } );
						$note .= '<br/>new credit: ' . $Credit->to_string();
						$variable{'error'} .= (new openprint::Log())->save( {
								action		=> 	'Credit Information Changed', 
								object_id   =>  $index,
								object_type	=>	'openprint::Company',
								note        =>  $note,
								});
					} else {
						$variable{'information'} .= 'Credit unchanged for ' . $Supplier->name() . '<br/>';
					} # end if
				} # end foreach Supplier
				sql::end_transaction( $dbh, $ac );
				$variable{ExternalRedirect} = '/administrator/managerial/company_profiles.html?ddmCustomer='.$Company->id();
				return;
			} # end if $index
		} # end if input checks
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$Company = new openprint::Company( $param{'company_id'} );
		$index = $Company->next();
		$Company->delete();
		$Company = new openprint::Company( $index );
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		$Company = new openprint::Company( $param{'company_id'} );
		if ( ! $Company->destroy() ) {
			$index = $Company->next();
		} # end if
		$Company = new openprint::Company( $index );
	} elsif ( $openprint::param{'btnFunction'} eq 'Undelete' ) {
		$index = $param{'company_id'};
		$Company = new openprint::Company( $param{'company_id'} );
		$Company->undelete();
	} # end if btnFunction

	if ( ! $index ) {
		$index = $session{company_id};
		$Company = new openprint::Company($index);
	} # end if

	my @customers_categories;
	if ( $index ) {
		my $shipping_address = $Company->get_shipping_address();
		@variable{ keys %shipping_fields } = ssi::htmlize( $shipping_address->get( @shipping_fields{ keys %shipping_fields } ) );
		$_ = q{SELECT category_id FROM Companies_in_Marketing_Categories WHERE Company_id =?};
		@customers_categories = sql::execute( $log, $dbh, $_, $index );
	} # end if

	$variable{'txtPricingLevel'} = sprintf ( "%.0f", $variable{'txtPricingLevel'} ) . "%";

	# Get Customer Category Inforamation - get all categories, and highlight the ones this customer is in.
	my @available_categories = map { $_->id(), $_->name() } openprint::MarketingCategory->find();
	$variable{'selectCustomerCategories'} = ssi::make_drop_down( \@available_categories, \@customers_categories );

	$variable{'CustomerIndex'} = $index;
	$variable{'Company'} = $Company;
} # end sub company_profiles

sub _company_accounting_contacts {
	$variable{'Company'} = new openprint::Company( $param{'company_id'} );
	if ( $param{'new_accounting_contact_id'} ) {
		$variable{'error'} .= sql::insert( undef, undef, 'companies_accountingcontacts', 'company_id', $variable{'Company'}->id(), 'user_id', $param{'new_accounting_contact_id'} );
	} # end if
	if ( $param{'action'} eq 'delete' ) {
		sql::execute( undef, undef, 'DELETE FROM companies_accountingcontacts WHERE company_id=? AND user_id=?', @param{'company_id','user_id'} );
	} # end if
} # end sub

sub payment_options {
	require openprint::PaymentType;
	$variable{'PaymentType'} = new openprint::PaymentType( $param{'paymenttype_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $variable{'PaymentType'}->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $variable{'PaymentType'}->delete();
	} # end if
} # end sub payment_options
sub emails {
	my $mail_dbh = email::db_connect();
	$openprint::Email::dbh = $mail_dbh;
 
	if ( $param{'action'} eq 'Delete' ) {
		foreach my $Email ( openprint::Email_Account->find('id'=>$param{'id'}) ) {
			$variable{'error'} .= $Email->delete();
		} # end foreach Email
	} elsif ( $param{'action'} eq 'Save' ) {
	} # end if
} # end sub emails

sub email {
	my $mail_dbh = email::db_connect();
	if ( $mail_dbh ) {
		$openprint::Email_Account::dbh = $mail_dbh;
		$variable{'Email'} = new openprint::Email_Account( $param{'id'} );
	} # end if
} # end sub email

sub usergroups {
	if ( $param{'command'} eq 'Save' ) {
		my $Group = new openprint::UserGroup( $param{'id'} );
		if ( $param{'filename'} ) {
			my $Asset = openprint::Asset::upload( 'filename' );
			if ( ref $Asset ne 'openprint::Asset' ) {
				$variable{'error'} .= $Asset;
			} else {
				$param{'asset_id'} = $Asset->id();
			} # end if
		} # end if
		$variable{'error'} .= $Group->save( \%param );
	} # end if
} # end sub usergroups
sub usergroup {
	$variable{'UserGroup'} = new openprint::UserGroup( $param{'id'} );
} # end sub usergroup

sub user_profile_fields {
	if ( $param{'action'} eq 'Save' ) {
		foreach my $Field ( openprint::User_Profile_Field->find() ) {
			$variable{'error'} .= $Field->save({
				'name'	=>	$param{'name-'.$Field->id()},
				'description'	=>	$param{'description-'.$Field->id()},
				'type'	=>	$param{'type-'.$Field->id()},
				'values'	=>	[ misc::trim( split(',', $param{'values-'.$Field->id()} ) ) ],
				'defaults'	=>	[ misc::trim( split(',', $param{'defaults-'.$Field->id()} ) ) ],
				'required'	=>	$param{'required-'.$Field->id()},
				'searchable'	=>	$param{'searchable-'.$Field->id()},
				'search_default'	=>	$param{'search_default-'.$Field->id()},
				'match'	=>	$param{'match-'.$Field->id()},
				'viewable'	=>	$param{'viewable-'.$Field->id()},
				'on_registration'	=>	$param{'on_registration-'.$Field->id()},
			});
		} # end foreach Field
	} # end if
} # end sub user_profile_fields
sub _field_tr {
	my $object_name;
	if ( $ENV{'HTTP_REFERER'} =~ /user_profile_fields/ ) {
		$object_name = 'openprint::User_Profile_Field';
	} elsif ( $ENV{'HTTP_REFERER'} =~ /company_profile_fields/ ) {
		$object_name = 'openprint::Company_Profile_Field';
	} # end if
	if ( ! $object_name ) {
		$log->error("Unknown referrer: $ENV{'HTTP_REFERER'}");
		return;
	} # end if
	
	$variable{'Field'} = $object_name->new( $param{'field_id'} );
	if ( $param{'action'} eq 'Add' ) {
		$variable{'error'} .= $variable{'Field'}->save({
			'name'	=>	'name',
		});
	} elsif ( $param{'action'} eq 'Delete' ) {
		$variable{'error'} .= $variable{'Field'}->delete();
		$variable{'Field'} = $object_name->new() if ! $variable{'error'};
	} elsif ( $param{'action'} eq 'Copy' ) {
		$variable{'Field'} = $variable{'Field'}->copy();
		$variable{'error'} .= $variable{'Field'}->save( \%param );
	} # end if
} # end sub _field_tr

sub _user_fields_tbody {
	if ( $param{'action'} eq 'up' ) {
		my @Fields = openprint::User_Profile_Field->find('order'=>'sort');
		my $i = 0;
		while ( $i < @Fields ) {
			last if $Fields[$i]->id() == $param{'field_id'};
			$i += 1;
		} # end while
		if ( $i and $i < @Fields ) {
			$_ = $Fields[$i-1];
			$Fields[$i-1] = $Fields[$i];
			$Fields[$i] = $_;
			$i = 0;
			foreach my $Field ( @Fields ) {
				$Field->save({'sort'=>$i});
				$i += 1;
			} # end foreach Field
		} # end if
	} elsif ( $param{'update'} ) {
		$param{'update'} =~ s/fields\[\]=//g;
		my $i = 0;
		foreach my $field_id ( split('&', $param{'update'} ) ) {
			my $Field = new openprint::User_Profile_Field( $field_id );
			$Field->save({'sort'=>$i});
			$i += 1;
		} # end foreach $feild_id
	} # end if
} # end sub _user_fields_tbody

sub company_profile_fields {
	if ( $param{action} eq 'Save' ) {
		foreach my $Field ( openprint::Company_Profile_Field->find() ) {
			$variable{'error'} .= $Field->save({
				name	=>	$param{'name-'.$Field->id()},
				description	=>	$param{'description-'.$Field->id()},
				type	=>	$param{'type-'.$Field->id()},
				values	=>	[ split(',', $param{'values-'.$Field->id()} ) ],
				defaults	=>	[ misc::trim( split(',', $param{'defaults-'.$Field->id()} ) ) ],
				required	=>	$param{'required-'.$Field->id()},
				searchable	=>	$param{'searchable-'.$Field->id()},
				search_default	=>	$param{'search_default-'.$Field->id()},
				match			=>	$param{'match-'.$Field->id()},
				on_registration	=>	$param{'on_registration-'.$Field->id()},
				viewable		=>	$param{'viewable-'.$Field->id()},
			});
		} # end foreach Field
	} # end if
} # end sub company_profile_fields

sub _company_fields_tbody {
	if ( $param{action} eq 'up' ) {
		my @Fields = openprint::Company_Profile_Field->find('order'=>'sort');
		my $i = 0;
		while ( $i < @Fields ) {
			last if $Fields[$i]->id() == $param{'field_id'};
			$i += 1;
		} # end while
		if ( $i and $i < @Fields ) {
			$_ = $Fields[$i-1];
			$Fields[$i-1] = $Fields[$i];
			$Fields[$i] = $_;
			$i = 0;
			foreach my $Field ( @Fields ) {
				$Field->save({'sort'=>$i});
				$i += 1;
			} # end foreach Field
		} # end if
	} elsif ( $param{update} ) {
		$param{update} =~ s/fields\[\]=//g;
		my $i = 0;
		foreach my $field_id ( split('&', $param{update} ) ) {
			my $Field = new openprint::Company_Profile_Field( $field_id );
			$Field->save({sort=>$i});
			$i += 1;
		} # end foreach $feild_id
	} # end if
} # end sub _company_fields_tbody

sub _search_by_email {
} # end sub _search_by_email

sub page_settings {
	require openprint::Page_Setting;
	if ( $param{action} eq 'save' ) {
		foreach my $PS ( openprint::Page_Setting->find(), new openprint::Page_Setting() ) {

			my @usergroup_ids = ref $param{"usergroup_ids-$$PS{id}"} eq 'ARRAY' ? @{$param{"usergroup_ids-$$PS{id}"}} : ( $param{"usergroup_ids-$$PS{id}"} ) if $param{"usergroup_ids-$$PS{id}"};

			if ( defined $PS->id() and ! $param{'url-'.$PS->id()} ) {
				$PS->delete();
			} elsif ( 
					( $PS->url() ne openprint::Page_Setting->transform('url',$param{'url-'.$PS->id()}) ) or 
					( $PS->cacheable() ne $param{'cacheable-'.$PS->id()} ) or 
					( $PS->user_level() ne $param{'user_level-'.$PS->id()} ) or
					( $PS->keywords() ne $param{'keywords-'.$PS->id()} ) or
					( $PS->description() ne $param{'description-'.$PS->id()} ) or
					( $PS->message() ne $param{'message-'.$PS->id()} ) or
					( sets::union( ( $PS->usergroup_ids() ? @{$PS->usergroup_ids()} : () ), @usergroup_ids ) != sets::intersection( ( $PS->usergroup_ids() ? @{$PS->usergroup_ids()} : () ), @usergroup_ids ) ),
	
				) {
				$variable{'error'} .= $PS->save({
						url			=>	$param{'url-'.$$PS{id}},
						cacheable	=>	$param{'cacheable-'.$$PS{id}},
						user_level	=>	$param{'user_level-'.$$PS{id}},
						keywords	=>	$param{'keywords-'.$$PS{id}},
						description	=>	$param{'description-'.$$PS{id}},
						message		=>	$param{'message-'.$$PS{id}},
						usergroup_ids	=>	\@usergroup_ids,
						});
			} # end if need to save
		} # end foreach PS
	} # end if
} # end sub page_settings

sub user_relationships {
	require openprint::User_Relationship;
	if ( $param{'action'} eq 'save' ) {
		foreach my $URT ( openprint::User_Relationship_Type->find() ) {
			$variable{'error'} .= $URT->save({
				'name'	=>	$param{'name-'.$URT->id()},
				'text1'	=>	$param{'text1-'.$URT->id()},
				'text2'	=>	$param{'text2-'.$URT->id()},
				'text3'	=>	$param{'text3-'.$URT->id()},
			});
		} # end foreach URT
		if ( $param{'name-new'} ) {
			my $URT = new openprint::User_Relationship_Type();
			$variable{'error'} .= $URT->save({
				'name'	=>	$param{'name-new'},
				'text1'	=>	$param{'text1-new'},
				'text2'	=>	$param{'text2-new'},
				'text3'	=>	$param{'text3-new'},
			});
		} # end if
	} # end if
} # end sub user_relationships
sub upload_log {
	ssi::save_params( '/administrator/managerial/upload_log.html', ( 
		( map { 'uploaded_on_start_'.$_ } ( 'year', 'month', 'day', 'hour','minute' ) ),
		( map { 'uploaded_on_end_'.$_ } ( 'year', 'month', 'day', 'hour','minute' ) ),
		'company_id','type',
	) );

	ssi::setup_date_select( '/administrator/managerial/upload_log.html', 'uploaded_on_start', -1 );
	ssi::setup_date_select( '/administrator/managerial/upload_log.html', 'uploaded_on_end', '' );
} # end sub upload_log

sub promo_codes {
	require openprint::Promo_Code;
	if ( $param{'action'} eq 'save' ) {
		foreach my $PC ( openprint::Promo_Code->find() ) {
			if ( ! $param{'code-'.$PC->code()}  ) {
				$PC->delete();
			} elsif ( 
					( $PC->code() ne $param{'code-'.$PC->code()} ) or 
					( $PC->name() ne $param{'name-'.$PC->id()} ) or 
					( $PC->effect() ne $param{'effect-'.$PC->id()} )
				) {
				$variable{'error'} .= $PC->save({
						'code'=>$param{'code-'.$$PC{code}},
						'name'=>$param{'name-'.$$PC{code}},
						'effect'=>$param{'effect-'.$$PC{code}},
						});
			} # end if need to save
		} # end foreach PC
		if ( $param{'code-new'} ) {
			my $PC = new openprint::Promo_Code();
			$variable{'error'} .= $PC->save({
					'code'=>$param{'code-new'},
					'name'=>$param{'name-new'},
					'effect'=>$param{'effect-new'},
					});
		} # end if
	} # end if
} # end sub promo_codes

sub logs {
} # end sub logs
sub _logs {
	if ( $param{'action'} eq 'delete' ) {
		my $Log = new openprint::Log( $param{'log_id'} );
		$Log->delete();
	} # end if
} # end sub _logs

sub bitcoin {
} # end sub bitcoin
sub authorizations {
	require openprint::Authorization;
	require openprint::Object_Type;
	_authorizations();
	if ( $param{action} eq 'Save' ) {
		foreach my $Auth ( (new openprint::Authorization()), openprint::Authorization->find() ) {
			next if ! $param{"object_type_id-$$Auth{id}"};

			$variable{error} .= $Auth->save({
				mode			=>	$param{"mode-$$Auth{id}"},
				object_type_id	=>	$param{"object_type_id-$$Auth{id}"},
				object_id		=>	$param{"object_id-$$Auth{id}"},
				usertype_id		=>	$param{"usertype_id-$$Auth{id}"},
				usergroup_id	=>	$param{"usergroup_id-$$Auth{id}"},
				setting			=>	$param{"setting-$$Auth{id}"},
			});
		} # end foreach Auth
		$variable{ExternalRedirect} = '/administrator/managerial/authorizations.html';
	} # end if
} # end sub authorizations
sub _authorizations {
	ssi::save_params( '/administrator/managerial/authorizations.html', ( 'object_type_id' ) );
} # end sub _authorizations

sub companies {
	_companies();
} # end sub companies
sub _companies {
	ssi::save_params( '/administrator/managerial/companies.html', ( 
				'salesrep_id', 'marketing_category_id', 'company_name',
				( map { 'created_on_start_' . $_ } ( 'year','month','day' ) ),
				) );
	$session{$r->uri().'?salesrep_id_exclude'} = $param{salesrep_id_exclude};
} # end sub _companies

sub folds {
	_folds();
} # end sub folds

sub _folds {
	ssi::save_params( '/administrator/managerial/folds.html', ( 'equipment_id', 'type' ) );
} # end sub _folds

sub shipping_rates {
	require openprint::Shipping_Rate;
}

sub _merge_popup {
	$variable{Company} = new openprint::Company( $param{company_id} );
}

sub _user_logs {
	$variable{User} = new openprint::User( $param{user_id} );
	ssi::save_params( '/administrator/managerial/user_profiles.html',
			( map { 'log_created_on_start_' . $_ } ( 'year','month','day','hour','minute' ) ),
			( map { 'log_created_on_end_' . $_ } ( 'year','month','day','hour','minute' ) ),
	);
} # end sub _logs
1;
__END__
