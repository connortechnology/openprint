package openprint::main_order;

use Email::Valid;
use Date::Calc qw(Add_Delta_Days check_date);

use strict;
use openprint ();
use vars qw( %config %param %variable $log $dbh %session );
*variable = \%openprint::variable;
*session = \%openprint::session;
*config = \%openprint::config;
*param = \%openprint::param;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

require sql;
require openprint::Currency;
require openprint::service;
require openprint::Order;
require openprint::order;
require openprint::OrderedProduct;
require openprint::press_schedule;
require openprint::Payment;
require openprint::Tax;

sub information {

	my $error;
	my $order_id = $param{'OrderID'};
	# Order creation can happen here as well, because we are doing away with quantity_select

	if ( $order_id and $param{'remove'} ) {
		my $project_index = $param{'remove'};
		$project_index =~ s/\D//g;
		my $ac = sql::start_transaction( $dbh );
		my $Project = new openprint::Project( $project_index );
		$Project->add_to_log( @session{'company_id','user_id'}, "Remove from order $order_id" );
		$Project->docket( '' );
		$Project->order_id( '' );
		$Project->save();
		$Project->update_status();
		sql::execute( $log, $dbh, q{DELETE FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, $order_id, $param{'remove'});
		sql::end_transaction( $dbh, $ac );
	} elsif ( $param{'btnFunction'} eq 'New Order' ) {
		# Re order situation
		$order_id = openprint::order::make_order_from_order( $order_id );
		return if ! $order_id;
	} elsif ( $param{'btnFunction'} eq 'ReOpen' ) {
		openprint::order::delete_unfinished_orders();
		if ( $order_id = $param{'OrderID'} ) {
			my $Order = new openprint::Order( $order_id );
			$Order->save({'status'=>'Re-Opened','session_id'=>$session{'_session_id'}});
			foreach my $OP ( $Order->Ordered_Projects() ) {
				$variable{'error'} .= $OP->save({'price'=>undef});
			} # end foreach
			$Order->add_to_log( 'Re-Opened' );
		} else {
			$error = 'No OrderID given to Re-Open.';
		} # end if OrderID
	} elsif ( $param{'btnFunction'} eq 'Process Order' ) {
		if ( $param{'quote_id'} ) {
			( $order_id, $error ) = openprint::order::make_order_from_quote( $param{'quote_id'} );
		} else {
			my $project_index = $param{'ProjectIndex'};
			$_ = q{SELECT strStatus FROM Orders WHERE id IN (SELECT OrderIndex FROM Order_Contents WHERE lngProjectIndex=?)}.
				q{AND strStatus IN ( 'Pending Deposit', 'In Production', 'Complete', 'Shipped', 'Waiting For Pickup', 'Picked Up' )};
			if ( sql::execute( $log, $dbh, $_, $project_index ) ) {
				return misc::error($log, $dbh, \%variable, q{Can't order project.}, "Project $project_index has already been ordered." );
			} # end if

			# Normal Order Creation
			( $order_id, $error ) = openprint::order::add_project_to_order( $param{'ProjectIndex'} );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Continue') { # saving projcet information
		$order_id = openprint::order::get_unfinished_order( ) if ! $order_id;
		foreach my $project_index ( sql::execute( $log, $dbh, q{SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?}, $order_id ) ) {
			$variable{'error'} .= openprint::order::save_project_information( $order_id, $project_index );
		} # end foreach
	} elsif ( $param{'Product'} and $param{'Quantity'} ) {
		( $order_id, $error ) = openprint::order::add_product( $order_id, @param{'Product','Quantity'} );
	} # end if

	if ( $error ) {
		return misc::error( $log, $dbh, \%variable, 'Error', $error );
	} # end if
	$order_id = openprint::order::get_unfinished_order( ) if ! $order_id;
	my $Order = new openprint::Order( $order_id );

	if ( ! $variable{'error'} ) {
		# Only check for errors if we don't have any yet
		my @errors;
		# If there are any unspecified quantities, keep looping on the selection page.
		foreach my $Project ( $Order->Projects() ) {
			if ( ! $Project->ordered_quantity_index() ) {
				push @errors, "Please select the quantity to order for project $$Project{id}<br/>";
			} # end if
			if ( ! $Project->reference() ) {
				push @errors, "Please give project $$Project{id} a reference<br/>";
			} # end if
			if ( ! $Project->shippingtype() ) {
				push @errors, "Please select a shipping type for project $$Project{id}<br/>";
			} # end if
		} # end foreach Project
		if ( @errors ) {
			$variable{'error'} = join('<br/>', @errors );
			#$openprint::log->error( "Order Error: $variable{'error'}" );
		} # end if
	} # end if

# First thing to do is to try to load info directly from the order.
	 @variable{'companyname',
	 'salutation',
	 'firstname',
	 'lastname',
	 'address1',
	 'address2',
	 'city',
	 'state',
	 'postalcode',
	 'country',
	 'phone',
	 'fax',
	 'email',
	 'alsonotify',
	} = $Order->get('company_name','salutation','first_name','last_name','address1','address2','city','state','postalcode','country','phone','fax','email','alsonotify');

	if ( $variable{'companyname'} eq '' ) {
		my $Company = new openprint::Company($session{'company_id'});
		@variable{'companyname',
			'address1',
			'address2',
			'city',
			'state',
			'postalcode',
			'country',
			'phone',
			'fax'} = $Company->get('name','address1','address2','city','state','postalcode','country','phone','fax');
	} # end if

	if ( $variable{'email'} eq '' ) {
		my $User = new openprint::User( $session{user_id} );
		# Assume that we are acting on someone else's behalf
		if ( sets::isin( $session{'user_type'}, [ 'A','E'] ) ) {
		
			# WE ARE logged in as someone else
			if ( $User->company_id() != $session{'company_id'} ) {
				my @Users = openprint::User->find( 
						'company_id'=>$param{'company_id'} ? $param{'company_id'} : $session{'company_id'}, 
						'order'=>'lower(lastname),lower(firstname)'
						);
				$User = $Users[0] if @Users;
			} # end if
		} # end if
		@variable{'email',
			'title',
			'firstname',
			'lastname',
			'salutation',
			'phone',
			'fax',
		} = $User->get('email','title','firstname','lastname','salutation','phone','fax');

	} # end if

	$variable{'OrderID'} = $order_id;
	$variable{'Order'} = new openprint::Order( $order_id );

} # end sub information

sub submit {
		
	my $order_id = $param{'OrderID'};
	$order_id = openprint::order::get_unfinished_order(  ) if ! $order_id;
	my $Order = new openprint::Order( $order_id );

	if ( $param{'btnFunction'} eq 'Continue') { # saving project information
		
		foreach my $Project ( $Order->Projects() ) {
			$variable{'error'} .= openprint::order::save_project_information( $order_id, $Project->id() );
		} # end foreach
		foreach my $Product ( $Order->Products() ) {
			if ( exists $param{'ProductQuantity'.$Product->id()} ) {
				$param{'ProductQuantity'.$Product->id()} =~ s/\D//g;
				$Product->quantity( $param{'ProductQuantity'.$Product->id()} );
			} # end if
			#my %price = $Product->Product()->get_price( $Product->quantity() );
			#$Product->price( $price{Price} );
			$variable{'error'} .= openprint::order::save_project_information( $order_id, $Product->Project()->id() );
			# Need to update price to include shipping costs
			my %Price = $Product->Product()->get_price( $Product->quantity() );
$openprint::log->debug("Initial price for " . $Product->quantity() . ' is : ' . $Price{'Price'} );
			my $Project = $Product->Project();
			my $services = $Project->services();
			foreach my $ShippingType ( openprint::ServiceType->find('category'=>'Shipping') ) {
				next if ! $$services{$ShippingType->name()};
				foreach my $service_id ( @{$$services{$ShippingType->name()}} ) {
					my $specs =  openprint::service::get_specs_ref( $Project, $service_id );
					$Price{'Price'} += $$specs{'txtPrice1'};
				} # end foreach service_id
			} # end foreach
			$Product->price( $Price{'Price'} );
			$Product->requested_for( sprintf('%.4d-%.2d-%.2d', @param{'ddmDueDateYear'.$$Project{'id'},'ddmDueDateMonth'.$$Project{'id'},'ddmDueDateDay'.$$Project{'id'}} ) ) if exists $param{'ddmDueDateYear'.$$Project{'id'}};
			$Product->save();
		} # end foreach Product

		$variable{'error'} .= openprint::order::store_order_info( $openprint::r, $log, $dbh, $session{'_session_id'}, \%variable );
		if ( $variable{'error'} ) {
			$variable{'Redirect'} = '/main/order/information.html';
			return;
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Save Service' ) {
		my $Project = new openprint::Project( $param{'ProjectIndex'} );
		openprint::print::save_service( $openprint::r, $log, $dbh, \%variable, $Project, $param{'ServiceIndex'} );
	} # end if

	my @errors;
	foreach my $Project ( $Order->Projects() ) {
		if ( ! $Project->ordered_quantity() ) {
			push @errors, "Please select the quantity to order for project $$Project{id}";
		} # end if
		if ( ! $Project->shippingtype() ) {
			push @errors, "Please select a shipping type for project $$Project{id}";
		} # end if
		if ( ! $Project->reference() ) {
			push @errors, "Please give project $$Project{id} a reference";
		} # end if
		my $services = $Project->services();
		my @ServiceTypes = openprint::ServiceType->find('category'=>'Shipping');
		foreach my $ServiceType ( @ServiceTypes ) {
			next if ! $$services{$ServiceType->name()};
			next if sets::isin( $ServiceType->name(), [ 'CustomerPickUp','Turnaround'] );
		
			foreach my $service_id ( @{$$services{$ServiceType->name()}} ) {
$log->debug("CHecking Shipping service $service_id " . $ServiceType->name() );
				my $specs = openprint::service::get_specs_ref( $Project, $service_id );
# do error checks
				push @errors, 'Please enter the Shipping Company Name.' if ! $$specs{'ToCompanyName'};
				push @errors, 'Please enter the Shipping Address.' if ! $$specs{'ToAddress1'};
				push @errors, 'Please enter the Shipping City.' if ! $$specs{'ToCity'};
				push @errors, 'Please enter the Shipping State/Province.' if ! $$specs{'ToStateProvince'};
				push @errors, 'Please enter the Shipping PostalCode.' if ! $$specs{'ToPostalCode'};
				push @errors, 'Please enter the Shipping Country.' if ! $$specs{'ToCountry'};
				push @errors, 'Please enter the Shipping Phone.' if ! $$specs{'ToPhone'};
				push @errors, 'Please enter the Shipping Email.' if	! $$specs{'ToEmail'};

				if ( ! Email::Valid->address($$specs{'ToEmail'} ) ) {
					push @errors, 'Shipping Email is not a valid email address.';
				} # end if
	
				if ( openprint::service::status( $Project->id(), $service_id ) eq 'uncalculated' ) {
					push @errors, 'Unable to calculate shipping:' . $$specs{'alert'}.'.';
				} # end if
			} # end foreach service_id
		} # end foreach ServiceType
		if ( $Project->order_id() != $order_id ) {
			$Project->order_id( $order_id );
			$Project->save();
		} # end if
	} # end foreach  Project
	if ( @errors ) {
		%param = ();
		$variable{'error'} .= join('<br/>', @errors );
		$variable{'Redirect'} = '/main/order/information.html';
		return;
	} # end if
	
	my $Currency = openprint::Currency::get_current();
	@variable{'CurrencyName','CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
	$variable{'Currency'} = $Currency;
	$variable{'Order'} = $Order;

	foreach my $Tax ( $Order->Taxes() ) {
		$Tax->amount(undef);
	} # end foreach Tax

	$variable{'OrderID'} = $order_id;

	@{$variable{'Projects'}} = $Order->Projects();
	$variable{'Order'} = $Order;

	if ( sets::isin( $session{'user_type'}, ['A','E'] ) ) {
		$variable{'AdministratorName'} = new openprint::User( $session{'user_id'} )->name();
	} # end if

} # end sub submit

sub confirmation {
	my $order_id = $param{'OrderID'};
	$order_id = openprint::order::get_unfinished_order( ) if ! $order_id;
	if ( $order_id eq '' ) {
		$log->error( "Still no Order ID" );
		return;
	} # end if

	my $Order = new openprint::Order( $order_id );

	if ( $Order->id() and ( sets::isin( $Order->status(), ['Incomplete','Re-Opened'] ) ) ) {
		if ( ( $Order->company_id() == $session{'company_id'} ) and ( $session{'company_id'} == new openprint::User( $session{'user_id'})->company_id() ) ) {
			if ( ! $param{'accept_terms'} ) {
				$variable{'error'} = 'Terms not accepted';
				$variable{'information'} = 'You must check the box to indicate your acceptance of the terms and conditions.';
				$variable{'Redirect'} = '/main/order/submit.html';
				return;
			} else {
				$Order->add_log( 'User accepted the terms and conditions.' );
				$Order->save({'terms_accepted'=>1});
			} # end if
		} # end if employee or admin

		# Commit Project Information
		foreach my $OP ( $Order->Ordered_Projects() ) {
			$OP->save({
				'reference'	=> $OP->Project()->reference(),
				'price'		=> $OP->Project()->Currency()->convert_from( $OP->price(undef) ),
				'quantity'	=> undef,
			});
		} # end foreach Project

		my $sub_total = $Order->subtotal(undef);
		foreach my $Tax ( $Order->Taxes() ) {
			$Tax->save({'amount'=>undef});
		} # end foreach Tax
		my $total = $Order->total(undef);

		my $customer_credit = new openprint::customer_credit( $session{'company_id'} );
		my ( $downpayment ) = $customer_credit->get( 'Downpayment' );
		if ( $downpayment eq '' ) {
			$downpayment = $config{'DefaultDownpayment'};
		} # end if
		$downpayment = $total * ( $downpayment / 100 );
		$downpayment = sprintf( '%.2f', $downpayment );

		my $status = ( ( $downpayment - $Order->paid() ) > 0 ) ? 'Pending Deposit': 'In Production';
		# Get Docket #
		my ( $docket_number ) = $Order->docket();
		if ( ! $docket_number ) {
			( $docket_number ) = sql::execute( $log, $dbh, q{SELECT nextval('DocketNumber_seq')} );
		} # end if

		# This is messed up.  I think an order should never switch companies unless it doesn't have a company assigned.  I don't see how it could work any other way.
		$Order->company_id( $session{'company_id'} ) if ! $Order->company_id();
		$Order->salesrep_id( new openprint::Company( $session{'company_id'} )->salesrep_id() );
		$Order->downpayment( $downpayment );
		$Order->status( $status );
		$Order->administrator_name( $param{'AdministratorName'} );
		$Order->administrator_comments( $param{'AdministratorComments'} );
		$Order->docket( $docket_number );
		$Order->currency_id( $session{'Currency_id'} );
		$Order->save();

		$Order->add_log( 'Submit Order' );
		
		$variable{'Downpayment'} = $downpayment - $Order->paid();
		$variable{'Downpayment'} = 0 if $variable{'Downpayment'} < 0;
		$variable{'Downpayment'} = sprintf( '%.2f', $variable{'Downpayment'} );

		foreach my $Project ( $Order->Projects() ) {
			sql::update( $log, $dbh, 'tbl_Project_Contents', ["lngProjectIndex=? AND strStatus NOT IN ( 'Complete', 'Approved', 'Proofs Out', 'Waiting For Customer Approval','Waiting For QA Approval','')", $Project->id()], 'strStatus', 'Ordered' );
			$Project->docket( $docket_number );
			$Project->order_id( $Order->id() );
			$Project->status( $status eq 'Pending Deposit' ? $status : 'In Prepress' );
			$Project->save();	
			$Project->update_status();

			openprint::press_schedule::add_project_to_press_schedule( $Project );
		} # end foreach Project
		foreach my $Product ( $Order->Products() ) {
			my $Project = $Product->Project();
			sql::update( $log, $dbh, 'tbl_Project_Contents', ["lngProjectIndex=? AND strStatus NOT IN ( 'Complete', 'Approved', 'Proofs Out', 'Waiting For Client Approval','Waiting For QA Approval','')", $Project->id()], 'strStatus', 'Ordered' );
			$Project->docket( $docket_number );
			$Project->order_id( $Order->id() );
			$Project->status( $status eq 'Pending Deposit' ? $status : 'In Prepress' );
			$Project->save();	
			$Project->update_status();

			openprint::press_schedule::add_project_to_press_schedule( $Project );
		} # end foreach Product
		$Order->update_status();
# send out email notifications
		$Order->send_sales_order( );

# *************************** WE are going to manually invoice for now *******************
		if ( $variable{'Downpayment'} > 0 ) {
		#	send_invoice( $r, $log, $dbh, $order_id );
		} # end if
	} # end if

	$variable{'OrderID'} = $order_id;
	$variable{'Order'} = $Order;
	delete $session{'OrderID'}
} # end sub confirmation

sub history {
	ssi::setup_date_select( '/main/order/history.html', 'created_on_start', -30 );
	ssi::setup_date_select( '/main/order/history.html', 'created_on', 0 );
	ssi::save_params( '/main/order/history.html', 
			'ddmOrderedBy',
			'created_on_start_year', 'created_on_start_month','created_on_start_day', 
			'created_on_end_year', 'created_on_end_month','created_on_end_day', 
			);

} # end sub history
sub _history {
	ssi::save_params( '/main/order/history.html', 
			'ddmOrderedBy',
			'created_on_start_year', 'created_on_start_month','created_on_start_day', 
			'created_on_end_year', 'created_on_end_month','created_on_end_day', 
			);

} # end sub _history

sub history_details {
	my $order_id = $param{'OrderID'};
	my $Order = new openprint::Order( $order_id );

	if ( $param{'btnFunction'} eq 'AcceptTerms' ) {
		if ( ( $Order->company_id() != $session{'company_id'} ) or ( new openprint::User( $session{'user_id'} )->company_id() != $session{'company_id'} ) ) {
			$variable{'error'} = 'Terms not accepted';
			$variable{'information'} = 'You are not authorised to accept the terms and conditions.';
		} elsif ( ! $param{'accept_terms'} ) {
			$variable{'error'} = 'Terms not accepted';
			$variable{'information'} = 'You must check the box to indicate your acceptance of the terms and conditions.';
		} else {
			$Order->add_log( 'User accepted the terms and conditions.' );
			$Order->save({'terms_accepted'=>1});
		} # end if

	} elsif ( $param{'btnFunction'} eq 'Cancel' ) {
		openprint::order::cancel_order( $order_id );
	} elsif ( $param{'btnFunction'} eq 'Pay' ) {
		$Order->pay();
	} elsif ( $param{'btnFunction'} eq 'Save Payment' ) {

		if ( ( ! $param{'Amount'} ) or $param{'Amount'} =~ /[^-\$\d\.]/ ) {
			$variable{'error'} .= 'Invalid Amount<br/>';
			$variable{'information'} .= 'Please enter a valid monetary amount.';
		} # end if
		if ( ! Date::Calc::check_date( @param{'received_on_year','received_on_month','received_on_day'} ) ) {
			$variable{'error'} .= 'Invalid received on date.';
			$variable{'information'} .= 'Please enter a valid date.';
		} # end if
		if ( ! $variable{'error'} ) {

			my $Payment = new openprint::Payment();
			my $error .= $Payment->save( {
					'order_id'		=> $order_id,
					'payor_id'		=> $Order->company_id(),
					'recipient_id'	=> new openprint::User( $session{'user_id'} )->company_id(),
					'amount'		=> $param{'Amount'},
					'method'		=> 'Manual',
					'currency_id'	=> $Order->currency_id(),
					'description'	=> $param{'Description'},
					'completed'		=> 1,
					} );
			if ( $error ) {
				return misc::error( $log, $dbh, \%variable, 'Error Saving Payment', $error );
			} # end if

			openprint::order::get_misc( \%variable, $Order );

			if ( $variable{'DepositDue'} > 0 ) {
				foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
					sql::update( $log, $dbh, 'Projects', ['id=? AND strStatus=?', $project_index, 'In Prepress'], 'strStatus', 'Pending Deposit' );
					sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?',$project_index, 'Ordered'], 'strStatus', 'Pending Deposit' );
				} # end foreach
			} else {
				$Order->status('In Production') if $Order->status() eq 'Pending Deposit';

				foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
					sql::update( $log, $dbh, 'Projects', ['id=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'In Prepress' );
					sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'Ordered' );
				} # end foreach
				if ( $variable{'AmountPaid'} >= $variable{'TOTAL'} ) {
					$Order->status('Paid') if $Order->status() eq 'Complete';
				} # end if
				$Order->save();
			} # end if no error
        } # end if btnFunction
	} elsif ( $param{'btnFunction'} eq 'Delete Payment' ) {
		my $Payment = new openprint::Payment( $param{'payment_id'} );
		if ( ! $Payment->id() ) {
			$variable{'error'} .= 'Invalid payment id specified.<br/>';
		} else {
			if ( my $error = $Payment->delete() ) {
				$variable{'error'} .= 'Payment not deleted: <br/>' . $error . '<br/>';
			} else {
				$variable{'information'} .= 'Payment deleted successfully.<br/>';
				$Order->update_status();
			} # end if
		} # end if
   } elsif ( $param{'btnFunction'} eq 'Invoice' ) {
	   $Order->invoice_id( $param{'invoice_id'} );
	   $Order->invoiced_on( 'NOW()' );
	   $Order->save();
	} elsif ( $param{'btnFunction'} eq 'Resend') {
		$Order->send_sales_order( );
		$variable{'information'} .= "Order emails sent.<br/>";
	} # end if
	openprint::order::display_order( $order_id );
} # end sub history_details

sub _CustomerPickUp {
} # end sub _CustoemrPickUp
sub _view_log {
} # end sub _view_log
1;
__END__
