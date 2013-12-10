use strict;
package openprint::employee_accounting;

require openprint::Credit_Application;
require MIME::QuotedPrint;
require openprint::Company_Credit;
require openprint::order;
require openprint::Order;
require openprint::Payment;
require misc;
require sql;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config);
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;
*config = \%openprint::config;

sub search {
	if ( $param{'btnFunction'} eq 'Go' ) {
        if ( $param{'StartDocket'} ) {
            my @orders = openprint::Order::find('docket'=>$param{'StartDocket'},'id'=>$param{'order_id'}, 'invoice_id'=>$param{'invoice_id'} );
            if ( @orders == 1 ) {
                $param{'order_id'} = $orders[0]->id();
                $variable{'Redirect'} = '/employee/accounting/details.html';
                return;
            } # end if
        } elsif ( $param{'project_id'} ) {
			my $Project = new openprint::Project( $param{'project_id'} );
			if ( $Project->id() and $Project->order_id() ) {
                $param{'order_id'} = $Project->order_id();
                $variable{'Redirect'} = '/employee/accounting/details.html';
                return;
            } # end if
        } # end if
    } # end if

	_search();
	ssi::setup_date_select( '/employee/accounting/search.html', 'ordered_on_start', '' );
	ssi::setup_date_select( '/employee/accounting/search.html', 'ordered_on_end', '' );
	if ( ! $session{'/employee/accounting/search.html?ddmStatus'} ) {
		$session{'/employee/accounting/search.html?ddmStatus'} = join(',', ( 'Complete','In Production',' Order Submitted', 'Pending Deposit', 'Paid', 'Picked Up','Re-Opened', 'Shipped', 'Waiting For Customer Approval', 'Waiting For Pickup', 'Waiting For QA Approval' ) );
	} # end if
} # end sub search

sub _search {
	ssi::save_params( '/employee/accounting/search.html',
			'ddmCustomer','ddmStatus','ddmEmployee','dblTotal1','dblTotal2',
			( map { 'ordered_on_start_'.$_ } ( 'year', 'month','day' ) ),
			( map { 'ordered_on_end_'.$_ } ( 'year', 'month','day' ) ),
			);
} # end sub _search

sub details {

    my $order_id = $param{'order_id'};
	my $Order = new openprint::Order( $order_id );

	if ( $param{'btnFunction'} eq 'Send' ) {
		openprint::order::send_sales_order( $r, $log, $dbh, $order_id );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		my $Payment = new openprint::Payment( $param{payment_id} );
		if ( $Payment->id() ) {
			$variable{'error'} .= $Payment->delete();
		} # end if
		$variable{'ExternalRedirect'} = '/employee/accounting/details.html?order_id='.$Order->id() if ! $variable{'error'};
	} elsif ( $param{'btnFunction'} eq 'Pay' ) {
		$variable{'error'} .= $Order->pay();
		$variable{'ExternalRedirect'} = '/employee/accounting/details.html?order_id='.$Order->id() if ! $variable{'error'};
	} elsif ( $param{'btnFunction'} eq 'Invoice' ) {
		$Order->invoice_id( $param{'invoice_id'} );
		$Order->invoiced_on( 'NOW()' );
		$Order->save();
	} elsif ( $param{'btnFunction'} eq 'ChangeSupplier' ) {
		if ( ! $param{'supplier_id'} ) {
			$variable{'error'} .= 'No supplier specified.  No change made.<br/>';
		} elsif ( $Order->supplier_id() == $param{'supplier_id'} ) {
			$variable{'error'} .= 'Supplier is already ' . $Order->Supplier()->name().'. No change made.<br/>';
		} else {
			$Order->add_log( "Supplier changed from " . $Order->Supplier()->name() . ' to ' . (new openprint::Company($param{supplier_id}))->name() );
			$variable{'error'} .= $Order->save({supplier_id=>$param{supplier_id}});
		} # end if
		$variable{'ExternalRedirect'} = '/employee/accounting/details.html?order_id='.$Order->id() if ! $variable{'error'};
    } elsif ( $param{'btnFunction'} eq 'Save' ) {
		
		my $error;
		$error .= 'Please enter a valid monetary amount.<br/>' if ( ! $param{'amount'} ) or $param{'amount'} =~ /[^-\$\d\.]/;
		$error .= 'Please enter a valid received on date.<br/>' if ! Date::Calc::check_date( @param{'received_on_year','received_on_month','received_on_day'} );

		return misc::error( $log, $dbh, \%variable, 'Payment errors', $error ) if $error;

		my $Payment = new openprint::Payment();
		$error = $Payment->save({
			'order_id'			=>	$order_id,
			'recipient_id'		=>	$Order->supplier_id(),
			'payor_id'			=>	$Order->company_id(),
			'amount'			=>	$param{'amount'},
			'received_on'		=>  join('-', @param{'received_on_year','received_on_month','received_on_day'} ),
			'method'			=>	$param{'method'},
			'currency_id'		=>	$Order->currency_id(),
			'memo'				=>	$param{'memo'},
			'transaction_id'	=>	$param{'transaction_id'},
		});
		if ( $error ) {
			return misc::error( $log, $dbh, \%variable, 'Error Saving Payment', $error );
		} # end if

		openprint::order::get_misc( $log, $dbh, \%variable, $order_id );

		if ( $variable{'DepositDue'} > 0 ) {
			foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
				sql::update( $log, $dbh, 'tbl_Projects', ['Index=? AND strStatus=?', $project_index, 'In Prepress'], 'strStatus', 'Pending Deposit' );
				sql::update( $log, $dbh, 'tbl_Project_Contents', "lngProjectIndex=$project_index AND strStatus='Ordered'", 'strStatus', 'Pending Deposit' );
			} # end foreach
		} else {
			$Order->status('In Production') if $Order->status() eq 'Pending Deposit';

			foreach my $project_index ( sql::execute( $log, $dbh, 'SELECT lngProjectIndex FROM Order_Contents WHERE OrderIndex=?', $order_id ) ) {
				sql::update( $log, $dbh, 'tbl_Projects', ['Index=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'In Prepress' );
				sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND strStatus=?', $project_index, 'Pending Deposit'], 'strStatus', 'Ordered' );
			} # end foreach
			if ( $variable{'AmountPaid'} >= $variable{'TOTAL'} ) {
				$Order->status('Paid') if $Order->status() eq 'Complete';
			} # end if
			$Order->save();
		} # end if
		$variable{'ExternalRedirect'} = '/employee/accounting/details.html?order_id='.$Order->id();
		#openprint::order::send_invoice( $r, $log, $dbh, $order_id );
    } elsif ( $param{'btnFunction'} eq 'Cancel' ) {
       openprint::order::cancel_order( $log, $dbh, $order_id );
	} # end if

	openprint::order::get_invoice_to( $log, $dbh, \%variable, $order_id );
	openprint::order::get_ship_to( $log, $dbh, \%variable, $order_id );
	$variable{'CCITYPROVCOUNTRY'} = misc::build_city_prov_country(@variable{'txtCity','txtStateProvince','txtCountry'} );
	$variable{'FCITYPROVCOUNTRY'} = misc::build_city_prov_country(@variable{'txtShippingCity','txtShippingStateProvince','txtShippingCountry'} );
	openprint::order::get_misc( $log, $dbh, \%variable, $order_id );
	openprint::order::get_projects( $log, $dbh, \%variable, $order_id );
	$variable{'OrderID'} = $order_id;
	my $Currency = $Order->Currency();
	@variable{'CurrencyName','CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
	$variable{'Order'} = $Order;
} # end sub details

sub credit {

	my $company_id = $param{'ddmCustomer'};

	if ( $param{'btnFunction'} eq 'Go' ) {
		 if ( $param{'txtSearchAccountNum'} ne '' ) {
			( $company_id ) = sql::execute( $log, $dbh,'SELECT Index from Company WHERE strAccountNum=?',$param{'txtSearchAccountNum'} );
		} # end if

	} elsif ( $param{'btnFunction'} eq 'Pay' ) {
		if ( ! $param{'PAID'} ) {
			$variable{'error'} = 'Please select an order to pay.<br/>';
		} else {
			my @errors;
			foreach my $order_id ( ref $param{'PAID'} eq 'ARRAY' ? @{$param{'PAID'}} : $param{'PAID'} ) {
				my $Order = new openprint::Order( $order_id );
				if ( $Order->company_id() != $company_id ) {
					push @errors, 'Order ' . $Order->id() . ' does not belong to ' . new openprint::Company($company_id)->name().'.';
					next;
				} # end if
				push @errors, $Order->pay();
			} # end foreach
			if ( @errors ) {
				$variable{'error'} = join('<br/>', @errors );
			} # end if
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		if ( ! $company_id ) {
			$variable{'error'} .= 'No customer specified.<br/>';
		} else {
			my $ac = sql::start_transaction( $dbh );
			$dbh->do( 'LOCK TABLE Company_Credit IN ACCESS EXCLUSIVE MODE' ) or $log->error( DBI->errstr );
			foreach my $Supplier ( openprint::Company->find('offers_credit'=>1) ) {
				my $Credit = new openprint::Company_Credit( {'company_id'=>$company_id, 'supplier_id'=>$Supplier->id() } );

                if (
                        ( $Credit->denydays() != openprint::Company_Credit->transform('denydays', $param{'denydays-'.$$Supplier{id}} ) ) or
                        ( $Credit->warndays() != openprint::Company_Credit->transform('warndays', $param{'warndays-'.$$Supplier{id}} ) ) or
                        ( $Credit->limit() != openprint::Company_Credit->transform('limit', $param{'limit-'.$$Supplier{id}} ) ) or
                        ( $Credit->hold() ne openprint::Company_Credit->transform('hold', $param{'hold-'.$$Supplier{id}} ) ) or
                        ( $Credit->downpayment() != openprint::Company_Credit->transform('downpayment', $param{'downpayment-'.$$Supplier{id}} ) ) or
                        ( $Credit->cod() != openprint::Company_Credit->transform('cod', $param{'cod-'.$$Supplier{id}} ) )
                        ) {
                    my $note = 'Old credit: ' . $Credit->to_string() if $Credit->supplier_id();
					$variable{'error'} .= $Credit->save( { 'company_id'=>$company_id, 'supplier_id'=>$Supplier->id(), 
							map { $_ => $param{$_.'-'.$Supplier->id()} } ( 'denydays','warndays','limit','hold','downpayment','cod' ) } );
                    $note .= '<br/>new credit: ' . $Credit->to_string();
                    $variable{'error'} .= (new openprint::logRecord())->save( {
							action_type	=>	105,
							object_id	=>	$company_id,
							user_id		=>	$session{user_id},
							company_id	=>	$session{company_id},
							note		=>	$note,
});
                } else {
                    $variable{'information'} .= 'Credit unchanged for ' . $Supplier->name() . '<br/>';
                } # end if
			} # end foreach Supplier
			sql::end_transaction( $dbh, $ac );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Export' ) {
		my @header = ( 'Creditor', 'Company Internal Name','Legal Name', 'Warn After Days', 'Deny After Days', 'Limit', 
				'Hold', 'Downpayment', 'COD', 'Balance', 'Remaining', 'Note' );
		my @data;
		openprint::Company->find();
		foreach my $Credit ( openprint::Company_Credit->find() ) {
			push @data, ( $Credit->Supplier()->name(), $Credit->Company()->name(), $Credit->Company()->business_name(),
				 $Credit->warndays(), $Credit->denydays(), $Credit->limit(), 
				 $Credit->hold(), $Credit->downpayment(), $Credit->cod(),
				 $Credit->debt(), $Credit->remaining(), '',
				 );
		} # ebd foreach Credut
		misc::export_csv( $r, $log, \%variable, 'Credit.csv', \@header, \@data );
	} elsif ( $param{'btnFunction'} eq 'Import' ) {
		my $upload;
		if ( ! $param{'import'} ) {
			$variable{'error'} = 'Please select a file for import.';
		} elsif ( ! ( $upload = $r->upload('import') ) ) {
			$variable{'error'} = 'Something wrong with upload.';
		} else {
			my $io = $upload->io();
			$_ = <$io>;

			my %Companies = map { $_->name(), $_ } openprint::Company->find();
			my %Legal = map { $_->business_name(), $_ } values %Companies;
			my $csv = Text::CSV_XS->new({binary=>1});
			my $ac = sql::start_transaction( $dbh );
			while ( <$io> ) {
				$csv->parse($_);
				#my ( $creditor_name, $company_name, $legal_name, $warndays, $denydays, $limit, $hold, $downpayment, $cod, $note ) = misc::trim( $csv->fields() );
				my ( $creditor_name, $company_name, $legal_name, $warndays, $denydays, $limit, $hold, $downpayment, $cod, $note ) = $csv->fields();
$log->debug("$creditor_name, $company_name, $legal_name, $warndays, $denydays, $limit, $hold, $downpayment, $cod, $note");
				next if ! $creditor_name;
				next if ! $company_name;
				if ( ! $Companies{$creditor_name} ) {
					$variable{'error'} .= "Unknown creditor $creditor_name<br/>";
					next;
				} elsif ( ! $Companies{$creditor_name}->offers_credit() ) {
					$variable{'error'} .= "Creditor $creditor_name doesn't offer credit.  Adding anyways.<br/>";
				} # end if
				if ( ! $Companies{$company_name} ) {
					if ( $Legal{$company_name} ) {
						$Companies{$company_name} = $Legal{$company_name};
					} elsif ( $legal_name and $Legal{$legal_name} ) {
						$Companies{$company_name} = $Legal{$legal_name};
					} elsif ( substr( $company_name, -1,1) eq '.' and $Companies{substr($company_name,0,-1)} ) {
						$Companies{$company_name} = $Companies{substr($company_name,0,-1)};
					} elsif ( substr( $company_name, -1,1) ne '.' and $Companies{$company_name.'.'} ) {
						$Companies{$company_name} = $Companies{$company_name.'.'};
					} elsif ( substr( $company_name, -3,3) ne 'Inc' and $Companies{$company_name.' Inc'} ) {
						$Companies{$company_name} = $Companies{$company_name.' Inc'};
					} elsif ( substr( $company_name, -3,3) ne 'Ltd' and $Companies{$company_name.' Ltd'} ) {
						$Companies{$company_name} = $Companies{$company_name.' Ltd'};
					} elsif ( substr( $company_name, -4,4) eq ' Inc' and $Companies{substr($company_name,0,-4)} ) {
						$Companies{$company_name} = $Companies{substr($company_name,0,-4)};
					} elsif ( substr( $company_name, -5,5) eq ' Inc.' and $Companies{substr($company_name,0,-5)} ) {
						$Companies{$company_name} = $Companies{substr($company_name,0,-5)};
					} elsif ( substr( $company_name, -4,4) eq ' Ltd' and $Companies{substr($company_name,0,-4)} ) {
						$Companies{$company_name} = $Companies{substr($company_name,0,-4)};
					} elsif ( substr( $company_name, -5,5) eq ' Ltd.' and $Companies{substr($company_name,0,-5)} ) {
						$Companies{$company_name} = $Companies{substr($company_name,0,-5)};
					} else {
$log->debug("$company_name " . substr( $company_name, -1,1) . ','. substr($company_name,0,-1) );
						$variable{'error'} .= "Unknown company $company_name<br/>";
						next;
					} # end if
				} # end if
				$warndays = openprint::Company_Credit->transform('warndays', $warndays);
				$denydays = openprint::Company_Credit->transform('denydays', $denydays);
				$limit = openprint::Company_Credit->transform('limit', $limit);
				$downpayment = openprint::Company_Credit->transform('downpayment', $downpayment);
				$cod = openprint::Company_Credit->transform('cod', $cod);
				$hold = 1 if sets::isin(lc $hold, [ 'y','yes' ] );
				$hold = 0 if $hold != 1;
				my $Credit = $Companies{$company_name}->Credit($Companies{$creditor_name}->id());
				if ( 
					( $warndays eq '' or $Credit->warndays() == $warndays ) and
					( $denydays eq '' or $Credit->denydays() == $denydays ) and
					( $limit eq '' or $Credit->limit() == $limit ) and
					( $hold eq '' or $Credit->hold() == $hold ) and
					( $downpayment eq '' or $Credit->downpayment() == $downpayment ) and
					( $cod eq '' or $Credit->cod() == $cod ) 
	) {
					$variable{'information'} .= "No change made for $creditor_name for $company_name $legal_name<br/>";
					next;
				} # end if

$variable{'information'} .= "$company_name for $creditor_name changed:".join(', ',
					(( $warndays eq '' or $Credit->warndays() == $warndays ) ? () : ('warn days: '.$Credit->warndays().' to '.$warndays )),
					(( $denydays eq '' or $Credit->denydays() == $denydays ) ? () : ('deny days: '.$Credit->denydays().' to '.$denydays )),
					(( $limit eq '' or $Credit->limit() == $limit )? () : ('limit: ' . $Credit->limit().' to ' . $limit )),
					(( $hold eq '' or $Credit->hold() == $hold ) ? () : ( 'hold: ' . $Credit->hold().' to ' . $hold )),
					(( $downpayment eq '' or $Credit->downpayment() == $downpayment ) ? () : ( 'downpayment: ' . $Credit->downpayment() . $downpayment )),
					(( $cod eq '' or $Credit->cod() == $cod ) ? () : ('cod: ' . $Credit->cod() . ' to ' . $cod ) ),
).'<br/>';

				$variable{error} .= $Credit->save({
					( $$Credit{'company_id'} ? () : ( 'company_id'=>$Companies{$company_name}->id() ) ),
					( $$Credit{'supplier_id'} ? () : ( 'supplier_id'=>$Companies{$creditor_name}->id() ) ),
					( $warndays ne '' ? ('warndays'=>$warndays) : () ),
					( $denydays ne '' ? ('denydays'=>$denydays) : () ),
					( $limit ne '' ? ('limit'=>$limit) : () ),
					( $hold ne '' ? ('hold'=>$hold) : () ),
					( $downpayment ne '' ? ('downpayment'=>$downpayment) : () ),
					( $cod ne '' ? ('cod'=>$cod) : () ),
					});
				$variable{'error'} .= (new openprint::logRecord())->save({'action_type'=>104,user_id=>$session{user_id},company_id=>$session{company_id},note=>$note. " for $company_name for $creditor_name"}) if $note;
			$log->debug($Credit->to_string());
			} # end while
			(new openprint::logRecord())->save({'action_type'=>104,user_id=>$session{user_id},company_id=>$session{company_id},note=>$variable{'error'}.$variable{'information'}});
			sql::end_transaction( $dbh, $ac );
		} # end if	
	} # end if btnFunction

$variable{'CompanyIndex'} = $company_id;
$variable{'Company'} = new openprint::Company($company_id);
} # end sub credit

sub stock {
	require openprint::ManifestContent;

	if ( $param{'btnFunction'} eq 'Save' ) {
		foreach my $Type ( openprint::Manifest_Content_Type->find('cost'=>undef) ) {
			$param{'cost-'.$Type->id()} =~ s/[^\d\.]//g;
			if ( $param{'units-'.$Type->id()} eq '/lb' ) {
				$param{'cost-'.$Type->id()} *= 100;
			} # end if
			if ( ( $param{'supplier_invoice-'.$Type->id()} ne $Type->supplier_invoice() ) or ( $param{'cost-'.$Type->id()} != $Type->cost() ) ) {
				$variable{'error'} .= $Type->save({'supplier_invoice'=>$param{'supplier_invoice-'.$Type->id()}, 'cost'=>$param{'cost-'.$Type->id()} });
			} # end if
		} # end foreach
	} else {
		_stock();
		ssi::setup_date_select( '/employee/accounting/stock.html', 'received_on_start', -30 );
		ssi::setup_date_select( '/employee/accounting/stock.html', 'received_on_end', 0 );
	} # end if
} # end sub stock

sub _stock {
	ssi::save_params( '/employee/accounting/stock.html',
			( map { 'received_on_start_'.$_ } ( 'year', 'month','day' ) ),
			( map { 'received_on_end_'.$_ } ( 'year', 'month','day' ) ),
			);
} # end sub _stock

sub credit_applications {

	ssi::setup_date_select( '/employee/accounting/credit_applications.html', 'created_on_start', -180 );
	ssi::setup_date_select( '/employee/accounting/credit_applications.html', 'created_on_end', 0 );
	ssi::save_params( '/employee/accounting/credit_applications.html',
			'ddmStatus',
			'created_on_start_year', 'created_on_start_month','created_on_start_day',
			'created_on_end_year', 'created_on_end_month','created_on_end_day',
		);

} # end sub credit_applications

sub credit_application {

	my $Application = $variable{'Application'} = new openprint::Credit_Application( $param{'credit_index'} );
	if ( ! $Application->id() ) {
		$variable{'error'} .=  'Application does not exist.';
		return;
	} # end if

	my $Company = $variable{'Company'} = $Application->Company();
	if ( ! $Company->id() ) {
		$variable{'error'} .= 'The company that created this credit app has been deleted from the system.  This credit app has been deleted.';
	} # end if

	my $User = $variable{'User'} = $Application->User();
	my $Credit = $variable{'Credit'} = $Company->Credit();

	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $Application->save({
				'status'				=>	$param{'status'},
				'granted_terms'			=>	$param{'denydays'},
				'granted_limit'			=>	$param{'limit'},
				'granted_downpayment'	=>	$param{'downpayment'},
				'granted_cod'			=>	$param{'cod'},
				});
		
		$variable{'error'} .= $Credit->save( \%param );
		if ( ! $variable{'error'} ) {

			$variable{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/credit_change_notification.html' );
			$variable{'ReplacementText'} = ssi::variable_substitution( $r, $log, $dbh, \$variable{'ReplacementText'}, \%variable );
			$_ = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
			my $template = ssi::variable_substitution( $r, $log, $dbh, \$_, \%variable );
			$variable{'error'} .= ( new openprint::Email())->send(
					FROM	=> $config{'AdministratorEmail'},
					TO		=> $Application->User()->email(),
					SUBJECT => 'Credit Status Changed.',
					ATTACHMENTS	=> [ '', MIME::QuotedPrint::encode_qp($template), 'text/html', 'quoted-printable' ],
				);
		} # end if
		$variable{'ExternalRedirect'} = '/employee/accounting/credit_applications.html' if ! $variable{'error'};
	} # end if

} # end sub credit_application

1;
__END__
