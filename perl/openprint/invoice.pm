use strict;
package openprint::invoice;

use openprint ();
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require Math::Round;

require openprint::Invoice;
require openprint::Invoice_Interest;
require openprint::Tax;
require openprint::Bitcoin_Address;

sub history {

	if ( $param{btnFunction} eq 'Send' ) {
		my $Invoice = openprint::Invoice->find_one( 'id'=>$param{invoice_id} );
		if ( ! $Invoice ) {
			$variable{error} .= "Invoice $param{invoice_id} not found";
		} else {
			$variable{error} .= $Invoice->send();
			$variable{information} .= 'Invoice ' . $Invoice->id() . ' sent.<br/>';
			$variable{ExternalRedirect} = '/invoice/history.html';
			return;
		} # end if
	} elsif ( $param{btnFunction} eq 'Send To Me' ) {
		my $Invoice = openprint::Invoice->find_one( id=>$param{invoice_id} );
		if ( ! $Invoice ) {
			$variable{error} .= "Invoice $param{invoice_id} not found";
		} else {
			$variable{error} .= $Invoice->send( new openprint::User( $session{user_id} ) );
			$variable{information} .= 'Invoice ' . $Invoice->id() . ' sent.<br/>';
		} # end if
		$variable{ExternalRedirect} = '/invoice/history.html';
		return;
	} elsif ( $param{btnFunction} eq 'Download' ) {
		my @Taxes = openprint::Tax->find(
				( Date::Calc::check_date( @param{'created_on_start_year','created_on_start_month','created_on_start_day'} ) ?
				  ( 'period_end null_or_>=' =>sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'created_on_start_year','created_on_start_month','created_on_start_day'} ) ) : () ),
				( Date::Calc::check_date( @param{'created_on_end_year','created_on_end_month','created_on_end_day'} ) ?
				  ( 'period_start null_or_<='       =>  sprintf('%.4d-%.2d-%.2d 23:59:59', @param{'created_on_end_year','created_on_end_month','created_on_end_day'} ) ) : () ),
				'order'     =>  'period_start,name',
				);

		my @Header = ('ID','Due On','Company','SubTotal',
				( map { sprintf('%s (%d%)', $_->name(), $_->rate() ) } @Taxes ),
				'Total','Interest','Owing');
		my @Data;

		my ($subtotal, $interest_total, $total, $owing_total, %tax_totals );

		foreach my $Invoice ( openprint::Invoice->find( 
					ssi::date_filter( 'created_on_start', 'created_on >=', \%param ),
					ssi::date_filter( 'created_on_end', 'created_on <=', \%param ),
					ssi::date_filter( 'due_on_start', 'due_on >=', \%param ),
					ssi::date_filter( 'due_on_end', 'due_on <=', \%param ),
					( $param{company_id} ? ( 'invoicee_id'       => $param{company_id} ) : () ),
					'invoicer_id'       => $session{company_id},
					'order'             => 'id',
					) ) {
			if ( $param{paid} ne '' ) {
				if ( $Invoice->is_paid() ) {
					next if $param{paid} == 0;
				} else {
					next if $param{paid} == 1;
				} # end if
			} # end if
            if ( $param{'/invoice/history.html?bad_debt'} != 2 ) {
                if ( $Invoice->bad_debt() ) {
                    next if $param{'/invoice/history.html?bad_debt'} == 0;
                } elsif ( $Invoice->bad_debt() eq '0' ) {
                    next if $param{'/invoice/history.html?bad_debt'} == 1;
                } # end if
            } # end if

			$subtotal += $Invoice->subtotal();
			$total += $Invoice->total();
			$interest_total += $Invoice->interest();
			$owing_total += $Invoice->owing();
			foreach my $Tax ( @Taxes ) {
				$tax_totals{$Tax->id()} += $Invoice->Tax( $Tax )->amount();
			} # end foreach Tax

			push @Data, $Invoice->id(), $Invoice->due_on(), $Invoice->Invoicee()->name(), $Invoice->subtotal(), 
				 ( map { $Invoice->Tax( $_ )->amount() } @Taxes ),
				 $Invoice->total(), $Invoice->interest(), $Invoice->owing();
		} # end foreach Invoice
		push @Data, 'Totals:', '', '', $subtotal, ( map { $tax_totals{$_->id()} } @Taxes ), $total, $interest_total, $owing_total;

		misc::export_csv( $r, $log, \%variable, 'invoices.csv', \@Header, \@Data );
	} elsif ( $param{btnFunction} eq 'Account Statement' ) {
		_history();
		my %data;

		my $email_template = misc::load_file( $log, $config{SkinPath}.'/email_template.html' );
		my @attachments;
		$data{ReplacementText} = ssi::include( '/email_content/account_statement.html', \%data );
		push @attachments, '', MIME::QuotedPrint::encode_qp( ssi::variable_substitution( \$email_template, \%data ) ), 'text/html', 'quoted-printable';

		my @Invoices = openprint::Invoice->find(
				ssi::date_filter('/invoice/history.html?created_on_start', 'created_on >=' ),
				ssi::date_filter('/invoice/history.html?created_on_end', 'created_on >=' ),
				'invoicee_id'       => $session{'/invoice/history.html?company_id'},
				'invoicer_id'       => $session{company_id},
				'order'             => 'id',
				);
		foreach my $Invoice ( @Invoices ) {
			next if $Invoice->is_paid();
			next if $Invoice->bad_debt();
			next if ! $Invoice->posted();

			$data{uri} = 'invoice';
			$data{Invoice} = $Invoice;
			$data{ReplacementText} = ssi::include( '/email_content/invoice.html', \%data );
			push @attachments, 'Invoice '.$$Invoice{id}.'.html', MIME::QuotedPrint::encode_qp( Encode::encode('utf-8',ssi::variable_substitution( \$email_template, \%data ) ) ), 'text/html', 'quoted-printable';
		} # end foreach Invoice

		my @Recipients = new openprint::Company($param{company_id})->AccountingContacts();
		(new openprint::Email())->send(
					FROM    => $config{AccountingEmail},
					TO      =>  \@Recipients,
					#TO      => new openprint::User( $session{user_id} ),
					BCC     => new openprint::User( $session{user_id} ),
					SUBJECT => 'Account Statement from ' . ( new openprint::User( $session{user_id} )->Company()->name() ),
					ATTACHMENTS	=>	\@attachments,
					);
		$variable{information} .= 'Account statement sent to ' . join('<br/>', map { sprintf('&quot;%s %s&quot; &lt;%s&gt;',$_->get('firstname','lastname','email')) } @Recipients );
	} # end if
	_history();
	ssi::setup_date_select( '/invoice/history.html', 'created_on_start', -365 );
	ssi::setup_date_select( '/invoice/history.html', 'created_on_end', '' );
	ssi::setup_date_select( '/invoice/history.html', 'due_on_start', -365 );
	ssi::setup_date_select( '/invoice/history.html', 'due_on_end', '' );

	$session{'/invoice/history.html?paid'} = '0' if ! sets::isin( $session{'/invoice/history.html?paid'}, [ 0,1,''] );
	$session{'/invoice/history.html?bad_debt'} = '0' if ! sets::isin( $session{'/invoice/history.html?bad_debt'}, [ 0,1,''] );
	$session{'/invoice/history.html?employee_id'} = $session{user_id} if ! exists $session{'/invoice/history.html?employee_id'};
} # end sub history

sub _history {
	ssi::save_params( '/invoice/history.html', ( 
		( map { 'created_on_start_'.$_ } ( 'year','month','day' ) ),
		( map { 'created_on_end_'.$_ } ( 'year','month','day' ) ),
		( map { 'due_on_start_'.$_ } ( 'year','month','day' ) ),
		( map { 'due_on_end_'.$_ } ( 'year','month','day' ) ),
		'paid','company_id','bad_debt','product_id') );
} # end sub _history

sub edit {
	my $Invoice = $variable{Invoice} = new openprint::Invoice( $param{invoice_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$param{currency_id} = openprint::Currency::get_current()->id() if ! $param{currency_id};
		my @due_on = ssi::date( 'due_on', \%param );
		$param{due_on} = sprintf('%.4d-%.2d-%.2d', @due_on ) if ! $param{due_on} and Date::Calc::check_date( @due_on );
		my @posted_on = ssi::date( 'posted_on', \%param );
		$param{posted_on} = sprintf('%.4d-%.2d-%.2d', @posted_on ) if ! $param{posted_on} and Date::Calc::check_date( @posted_on );
		my @early_payment_date = ssi::date( 'early_payment_date', \%param );

		$param{early_payment_date} = sprintf('%.4d-%.2d-%.2d', @early_payment_date ) if ( ! $param{early_payment_date} ) and Date::Calc::check_date( @early_payment_date );
		$param{invoicer_id} = $session{company_id} if ! $param{invoicer_id};
		if ( $param{invoicee} ) {
			my $Invoicee = openprint::Company->find_one(name=>openprint::Company->transform('name', $param{invoicee}) );
			if ( ! $Invoicee ) {
				$Invoicee = new openprint::Company();
				$Invoicee->save({name=>$param{invoicee}});
			} # end if
			$param{invoicee} = $Invoicee->id();
		} else {
			delete $param{invoicee};
		} # end if
		$variable{error} .= $variable{Invoice}->save(\%param);
		foreach my $Product ( $Invoice->Products() ) {
			$variable{error} .= $Product->save({
				description	=>	$param{'product-description-'.$Product->id()},
				price		=>	$param{'product-price-'.$Product->id()},
				quantity	=>	$param{'product-quantity-'.$Product->id()},
				po			=>	$param{'product-po-'.$Product->id()},
				});
		} # end foreach Product
		if ( $param{invoice_id} and ! $variable{error} ) {
			$variable{information} .= 'Invoice saved.<br/>';
			$variable{ExternalRedirect} = '/invoice/view.html?invoice_id='.$Invoice->id();
		} # end if
	} elsif ( $param{btnFunction} eq 'Post' ) {
		if ( ! ( $variable{error} .= $Invoice->save({posted=>1,posted_on=>'NOW()'}) ) ) {
			$Invoice->add_to_log( 'Invoice posted.' );
			$variable{information} .= 'Invoice posted.<br/>';
			delete $param{invoice_id};
			if ( $session{'/invoice/history.html?company_id'} and ( $session{'/invoice/history.html?company_id'} != $Invoice->invoicee_id() ) ) {
				delete $session{'/invoice/history.html?company_id'};
			} # end if
			$variable{ExternalRedirect} = '/invoice/view.html?invoice_id='.$Invoice->id();
			return;
		} # end if
	} elsif ( $param{btnFunction} eq 'UnPost' ) {
		if ( ! ( $variable{error} .= $Invoice->save({'posted'=>0}) ) ) {
			$Invoice->add_to_log( 'Invoice unposted.' );
			$variable{information} .= 'Invoice unposted.<br/>';
			$variable{ExternalRedirect} = '/invoice/view.html?invoice_id='.$Invoice->id();
			return;
		} # end if
	} # end if
	if ( ! $variable{Invoice}->id() ) {
		# Defaults, don't know who the company is yet
		$variable{Invoice}->due_on( join('-', Date::Calc::Add_Delta_Days( Date::Calc::Today(), 15 ) ) );
		$variable{Invoice}->early_payment_date( join('-', Date::Calc::Add_Delta_Days( Date::Calc::Today(), 7 ) ) );
		if ( $param{order_id} ) {
			my $Order = new openprint::Order($param{order_id});
			$$Invoice{invoicee_id} = $Order->company_id();
			my @Projects ;
			foreach my $P ( $Order->Ordered_Projects() ) {
				my $NewP = new openprint::Invoiced_Project();;
				$NewP->project_id( $P->project_id() );
				$NewP->Invoice( $Invoice );
			} # end foreach
		} # end if
	} # end if
} # end sub edit

sub view {
	my $Invoice = $variable{Invoice} = new openprint::Invoice( $param{invoice_id} );
	if ( ! $Invoice ) {
		$variable{error} .= "Invoice $param{invoice_id} not found";
		return;
	} 
	if ( $param{btnFunction} eq 'Calculate Interest' ) {
		if ( ! $Invoice->monthly_interest() ) {
			$variable{error} .= 'Invoice has no monthly interest rate!';
		} elsif ( ! $Invoice->due_on() ) {
			$variable{error} .= 'Invoice has no due date!';
		} # end if

		my $changed = 0;

		my ( $year, $month, $day ) = $Invoice->due_on() =~ /(\d\d\d\d)-(\d\d)-(\d\d)/;
		my $last_period;
		my $paid = 0;
		#( $year, $month, $day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, Date::Calc::Days_in_Month( $year, $month ) );
		while ( Date::Calc::Date_to_Time( $year, $month, $day,0, 0, 0 ) <= time ) {

			my $date_string = sprintf('%4d-%.2d-%.2d', $year, $month, $day);

			# The point is to calculate howmuch has beenpaidby this point
			foreach my $P ( openprint::Invoice_Payment->find(invoice_id=>$Invoice->id(), 'received_on >'=>$last_period, 'received_on <='=>$date_string )) {
				$paid += $P->amount();
			} # end foreach
			# Includes tax
			my $total = $Invoice->total();
			foreach my $I ( openprint::Invoice_Interest->find(invoice_id=>$Invoice->id(), 'compounded_on <'=>$date_string )) {
				$total += $I->amount();
			} # end foreach InvoiceInterest

			if ( $total - $paid > 0 ) {
				if ( ! openprint::Invoice_Interest->find(invoice_id=>$Invoice->id(), 'compounded_on'=>$date_string ) ) {
					my $I = new openprint::Invoice_Interest();
					$_ = $I->save({
							invoice_id		=>	$Invoice->id(),
							amount			=>	Math::Round::nearest( .01, ($total - $paid) * $Invoice->monthly_interest()/100),
							compounded_on	=>	sprintf('%.4d-%.2d-%.2d', $year, $month, $day ),
							});
					if ( ! $_ ) {
						$Invoice->add_to_log(sprintf('Added %s%.2f interest for %s', 
									$Invoice->Currency()->symbol(), 
									$I->amount(),
									$date_string,
									));
					} else {
						$variable{error} .= $_;
						last;
					} # end if
					$changed = 1;
				} # end if No interest for this date.
			} else {
				last;
			} # end if No interest for this date.
			$last_period = $date_string;
			($year,$month,$day) = Date::Calc::Add_Delta_Days( $year, $month, $day, Date::Calc::Days_in_Month( $year, $month ) );
		} # end while

		if ( $changed ) {
			delete $$Invoice{interest};
			$Invoice->interest();
			$Invoice->save();
		} # e,nd if
	} elsif ( $param{btnFunction} eq 'Delete' ) {
		if ( ! ( $variable{error} .= $Invoice->delete() ) ) {
			$variable{information} .= 'Invoice ' . $Invoice->id() . ' deleted.<br/>';
			$variable{ExternalRedirect} = '/invoice/history.html';
		} # end if
	} elsif ( $param{btnFunction} eq 'Destroy' ) {
		if ( ! ( $variable{error} .= $Invoice->destroy() ) ) {
			$variable{information} .= 'Invoice ' . $Invoice->id() . ' destroyed.<br/>';
			$variable{ExternalRedirect} = '/invoice/history.html';
		} # end if
	} elsif ( $param{btnFunction} eq 'Send' ) {
		$variable{error} .= $Invoice->send();
		$variable{information} .= 'Invoice ' . $Invoice->id() . ' sent.<br/>';
		$variable{ExternalRedirect} = $Invoice->url_to();
		return;
	} elsif ( $param{btnFunction} eq 'Send To Me' ) {
		$variable{error} .= $Invoice->send( new openprint::User( $session{user_id} ) );
		$variable{information} .= 'Invoice ' . $Invoice->id() . ' sent.<br/>';
		$variable{ExternalRedirect} = $Invoice->url_to();
		return;
	} # end if
} # end sub view
sub _timetracks {
	my $Invoice = $variable{Invoice} = new openprint::Invoice( $param{invoice_id} );
	if ( $param{timetrack_id} ) {
		my $Timetrack = new openprint::Timetrack( $param{timetrack_id} );
		if ( $param{action} eq 'add' ) {
			$Timetrack->invoice_id( $variable{Invoice}->id() );
		} elsif ( $param{action} eq 'remove' ) {
			$Timetrack->invoice_id( undef );
		} # en dif
		$variable{error} .= $Timetrack->save();
	} # end if
	if ( $param{invoicee_id} and $param{invoicee_id} != $Invoice->invoicee_id() ) {
		$Invoice->invoicee_id( $param{invoicee_id} );
	} # end if
} # end sub _timetracks
sub _invoiced_products {
	$variable{Invoice} = new openprint::Invoice( $param{invoice_id} );

	# Save any changes to the products
	foreach my $Product ( $variable{Invoice}->Products() ) {
		$variable{error} .= $Product->save({
			'description'	=>	$param{'product-description-'.$Product->id()},
			'price'			=>	$param{'product-price-'.$Product->id()},
			'quantity'		=>	$param{'product-quantity-'.$Product->id()},
			'po'			=>	$param{'product-po-'.$Product->id()},
			});
	} # end foreach

	if ( $param{action} eq 'new' ) {
		my $IP = new openprint::Invoiced_Product( );
		$variable{error} .= $IP->save({
				'invoice_id'=>$variable{Invoice}->id(),
				'quantity'	=> 1
				});
	} elsif ( $param{action} eq 'add' ) {
		my $IP = new openprint::Invoiced_Product( );
		$variable{error} .= $IP->save({
				'product_id'	=>	$param{'product-id-'},
				'invoice_id'	=>	$variable{Invoice}->id(),
				'quantity'		=>	$param{'product-quantity-'} ? $param{'product-quantity-'} : 1,
				'po'			=>	$param{'product-po-'},
				});
	} elsif ( $param{action} eq 'remove' ) {
		my $IP = new openprint::Invoiced_Product( $param{product_id} );
		if ( $IP->id() ) {
			$variable{error} .= $IP->delete();
		} else {
			$variable{error} .= "Product $param{product_id} does not exist.<br/>";
		} # end if
	} # end if
} # end sub _invoiced_products

sub _interests {

	if ( $param{action} eq 'delete' ) {
		my $Interest = new openprint::Invoice_Interest( $param{interest_id} );
		$variable{Invoice} = $Interest->Invoice();
		$variable{error} .= $Interest->delete();	
		$variable{Invoice}->interest(undef);
		$variable{error} = $variable{Invoice}->save();
	} # end if
} # end sub _interests

sub _invoicee_onchange {
} # end sub _invoicee_onchange

sub _invoiced_orders {
	my $Invoice = $variable{Invoice} = new openprint::Invoice( $param{invoice_id} );
$log->debug("here");
	if ( $param{action} eq 'add' ) {
$log->debug("Adding");
		my $Order = openprint::Order->find_one( id => $param{order_id} );
		if ( ! $Order ) {
			$variable{error} .= 'Order ' . $param{order_id} . ' not found.<br/>';
			return;
		}
		my $OI = new openprint::Order_Invoice();
		$variable{error} .= $OI->save({
			order_id	=> $$Order{id},
			invoice_id	=>	$$Invoice{id},
		});	
		foreach my $Product ( $Order->Products() ) {
			my $IP = new openprint::Invoiced_Product();
			$variable{error} .= $IP->save({
				invoice_id	=>	$$Invoice{id},
				product_id	=>	$$Product{product_id},
				quantity	=>	$$Product{quantity},
				price		=>	$$Product{price},
			});
		}
	} elsif ( $param{action} eq 'remove' ) {
		my $OI = openprint::Order_Invoice->find_one( order_id=>$param{order_id}, invoice_id=>$param{invoice_id} );
		$OI->delete();
	} # end if param add

} # end sub _invoiced_orders

1;
__END__
