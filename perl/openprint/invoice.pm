package openprint::invoice;

use strict;
use openprint;
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

require openprint::Invoice;
require openprint::Invoice_Interest;
require openprint::Tax;

sub history {

	if ( $param{'btnFunction'} eq 'Save' ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );

		foreach my $Product ( $Invoice->Products() ) {
			$variable{'error'} .= $Product->save({
				'description'	=>	$param{'product-description-'.$Product->id()},
				'price'			=>	$param{'product-price-'.$Product->id()},
				'quantity'		=>	$param{'product-quantity-'.$Product->id()},
				'po'			=>	$param{'product-po-'.$Product->id()},
				});
		} # end foreach
		$param{'currency_id'} = openprint::Currency::get_current()->id() if ! $param{'currency_id'};
		$param{'due_on'} = sprintf('%.4d-%.2d-%.2d', @param{'due_on_year','due_on_month','due_on_day'} ) if ! $param{'due_on'};
		$param{'invoicer_id'} = $session{'company_id'} if ! $param{'invoicer_id'};
		if ( ! ( $variable{'error'} .= $Invoice->save(\%param) ) ) {
			$variable{'information'} .= 'Invoice saved.<br/>';
			%param = ();
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Post' ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );
		if ( ! ( $variable{'error'} .= $Invoice->save({'posted'=>1,'posted_on'=>'NOW()'}) ) ) {
			$Invoice->add_to_log( 'Invoice posted.' );
			$variable{'information'} .= 'Invoice posted.<br/>';
			delete $param{'invoice_id'};
		} # end if
	} elsif ( $param{'btnFunction'} eq 'UnPost' ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );
		if ( ! ( $variable{'error'} .= $Invoice->save({'posted'=>0}) ) ) {
			$Invoice->add_to_log( 'Invoice unposted.' );
			$variable{'information'} .= 'Invoice unposted.<br/>';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Send' ) {
		my $Invoice = openprint::Invoice->find_one( 'id'=>$param{'invoice_id'} );
		if ( ! $Invoice ) {
			$variable{'error'} .= "Invoice $param{'invoice_id'} not found";
		} else {
			$variable{'error'} .= $Invoice->send();
			$variable{'information'} .= 'Invoice sent.<br/>';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );
		if ( ! ( $variable{'error'} .= $Invoice->delete() ) ) {
			$variable{'information'} .= 'Invoice deleted.<br/>';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Destroy' ) {
		my $Invoice = new openprint::Invoice( $param{'invoice_id'} );
		if ( ! ( $variable{'error'} .= $Invoice->destroy() ) ) {
			$variable{'information'} .= 'Invoice destroy.<br/>';
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Download' ) {
		my @Header = ('ID','Due On','Company','SubTotal','GST Rate', 'GST','Total','Interest','Owing');
		my @Data;

		my ($subtotal, $interest_total, $total, $owing_total );

		foreach my $Invoice ( openprint::Invoice->find( 
					'created_on_start'  => sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'created_on_start_year','created_on_start_month','created_on_start_day'} ),
					'created_on_end'    => sprintf('%.4d-%.2d-%.2d 23:59:59', @param{'created_on_end_year','created_on_end_month','created_on_end_day'} ),
					'due_on_start'  => sprintf('%.4d-%.2d-%.2d 00:00:00', @param{'due_on_start_year','due_on_start_month','due_on_start_day'} ),
					'due_on_end'    => sprintf('%.4d-%.2d-%.2d 23:59:59', @param{'due_on_end_year','due_on_end_month','due_on_end_day'} ),
					'invoicee_id'       => $param{'company_id'},
					'invoicer_id'       => $session{'company_id'},
					'order'             => 'id',
					) ) {
			if ( $param{'paid'} ne '' ) {
				if ( $Invoice->is_paid() ) {
					next if $param{'paid'} == 0;
				} else {
					next if $param{'paid'} == 1;
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
			push @Data, $Invoice->id(), $Invoice->due_on(), $Invoice->Invoicee()->name(), $Invoice->subtotal(), $Invoice->total(), $Invoice->interest(), $Invoice->owing();
		} # end foreach Invoice
		push @Data, 'Totals:', '', '', $subtotal, '', $total, $interest_total, $owing_total;

		misc::export_csv( $r, $log, \%variable, 'invoices.csv', \@Header, \@Data );
	} elsif ( $param{'btnFunction'} eq 'Account Statement' ) {
		my %data;

		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		my @attachments;
		$data{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/account_statement.html' );
		$data{'ReplacementText'} = ssi::variable_substitution( \$data{'ReplacementText'}, \%data );
		push @attachments, '', MIME::QuotedPrint::encode_qp( ssi::variable_substitution( \$email_template, \%data ) ), 'text/html', 'quoted-printable';

		foreach my $Recipient ( new openprint::Company($param{'company_id'})->AccountingContacts() ) {
			my %mail = (
					SMTP    => $config{'Mail Server'},
					FROM    => $config{'AccountingEmail'},
					TO      => sprintf('"%s" <%s>', $Recipient->name(), $Recipient->email() ),
					BCC     => sprintf('"%s %s" <%s>', new openprint::User( $session{'user_id'} )->get('firstname','lastname','email') ),
					#TO		=>	sprintf('"%s %s" <%s>', new openprint::User( $session{'user_id'} )->get('firstname','lastname','email') ),
					SUBJECT => 'Account Statement from ' . ( new openprint::User( $session{'user_id'} )->Company()->name() ),
					);
			misc::send_email_with_attachment( $log, \%mail, @attachments );
			$variable{'information'} .= sprintf('Sent to &quot;%s %s&quot; &lt;%s&gt;<br/>',$Recipient->get('firstname','lastname','email') );
		} # end foreach Recipient
	} # end if
	ssi::save_params( '/invoice/history.html', ( 'created_on_start_year','created_on_start_month','created_on_start_day','created_on_end_year','created_on_end_month','created_on_end_day', 'due_on_start_year','due_on_start_month','due_on_start_day','due_on_end_year','due_on_end_month','due_on_end_day', 'paid','company_id','bad_debt') );
} # end sub history

sub _history {
	ssi::save_params( '/invoice/history.html', ( 'created_on_start_year','created_on_start_month','created_on_start_day','created_on_end_year','created_on_end_month','created_on_end_day', 'due_on_start_year','due_on_start_month','due_on_start_day','due_on_end_year','due_on_end_month','due_on_end_day', 'paid','company_id','bad_debt') );
} # end sub _history

sub edit {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'currency_id'} = openprint::Currency::get_current()->id() if ! $param{'currency_id'};
		$param{'due_on'} = sprintf('%.4d-%.2d-%.2d', @param{'due_on_year','due_on_month','due_on_day'} ) if ! $param{'due_on'};
		$param{'invoicer_id'} = $session{'company_id'} if ! $param{'invoicer_id'};
		$variable{'error'} .= $variable{'Invoice'}->save(\%param);
	} # end if
	if ( ! $variable{'Invoice'}->id() ) {
		$variable{'Invoice'}->due_on( join('-', Date::Calc::Add_Delta_Days( Date::Calc::Today(), 15 ) ) );
	} # end if
} # end sub edit

sub view {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );
	if ( $param{'btnFunction'} eq 'Calculate Interest' ) {
		if ( ! $variable{'Invoice'}->monthly_interest() ) {
			$variable{'error'} .= 'Invoice has no monthly interest rate!';
		} elsif ( ! $variable{'Invoice'}->due_on() ) {
			$variable{'error'} .= 'Invoice has no due date!';
		} # end if

		my $changed = 0;

		my ( $year, $month, $day ) = $variable{'Invoice'}->due_on() =~ /(\d\d\d\d)-(\d\d)-(\d\d)/;
		my $last_period;
		my $paid = 0;
		( $year, $month, $day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, Date::Calc::Days_in_Month( $year, $month ) );
		while ( Date::Calc::Date_to_Time( $year, $month, $day,0, 0, 0 ) <= time ) {

			my $date_string = sprintf('%4d-%.2d-%.2d', $year, $month, $day);

			# The point is to calculate howmuch has beenpaidby this point
			foreach my $P ( openprint::Invoice_Payment->find('invoice_id'=>$variable{'Invoice'}->id(), 'received_on_>'=>$last_period, 'received_on_end'=>$date_string )) {
				$paid += $P->amount();
			} # end foreach
$log->debug("Paid: $paid");
			# Includes tax
			my $total = $variable{'Invoice'}->total();
			foreach my $I ( openprint::Invoice_Interest->find('invoice_id'=>$variable{'Invoice'}->id(), 'compounded_on_<'=>$date_string )) {
				$total += $I->amount();
			} # end foreach InvoiceInterest
$log->debug("Total: $total");

			if ( $total - $paid > 0 ) {
				if ( ! openprint::Invoice_Interest->find('invoice_id'=>$variable{'Invoice'}->id(), 'compounded_on'=>$date_string ) ) {
					my $I = new openprint::Invoice_Interest();
					$_ = $I->save({
							'invoice_id'=>$variable{'Invoice'}->id(),
							'amount'	=>	sprintf('%.2f', ($total - $paid) * $variable{'Invoice'}->monthly_interest()/100),
							'compounded_on'	=>	sprintf('%.4d-%.2d-%.2d', $year, $month, $day ),
							});
					if ( ! $_ ) {
						$variable{'Invoice'}->add_to_log(sprintf('Added %s%.2f interest for %s', 
									$variable{'Invoice'}->Currency()->symbol(), 
									$I->amount(),
									$date_string,
									));
					} else {
						$variable{'error'} .= $_;
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
			delete $variable{'Invoice'}{'interest'};
			$variable{'Invoice'}->interest();
			$variable{'Invoice'}->save();
		} # end if
	} # end if
} # end sub view
sub _invoiced_timetracks {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );
	if ( $param{'timetrack_id'} ) {
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$Timetrack->invoice_id( $variable{'Invoice'}->id() );
		$Timetrack->save();
	} # end if
} # end sub _invoiced_timetracks
sub _available_timetracks {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );
	if ( $param{'timetrack_id'} ) {
		my $Timetrack = new openprint::Timetrack( $param{'timetrack_id'} );
		$Timetrack->invoice_id( undef );
		$Timetrack->save();
	} # end if
} # end sub _available_timetracks
sub _invoiced_products {
	$variable{'Invoice'} = new openprint::Invoice( $param{'invoice_id'} );

	# Save any changes to the products
	foreach my $Product ( $variable{'Invoice'}->Products() ) {
		$variable{'error'} .= $Product->save({
			'description'	=>	$param{'product-description-'.$Product->id()},
			'price'			=>	$param{'product-price-'.$Product->id()},
			'quantity'		=>	$param{'product-quantity-'.$Product->id()},
			'po'			=>	$param{'product-po-'.$Product->id()},
			});
	} # end foreach

	if ( $param{'action'} eq 'new' ) {
		my $IP = new openprint::Invoiced_Product( );
		$variable{'error'} .= $IP->save({
				'invoice_id'=>$variable{'Invoice'}->id(),
				'quantity'	=> 1
				});
	} elsif ( $param{'action'} eq 'add' ) {
		my $IP = new openprint::Invoiced_Product( );
		$variable{'error'} .= $IP->save({
				'product_id'	=>	$param{'product-id-'},
				'invoice_id'	=>	$variable{'Invoice'}->id(),
				'quantity'		=>	$param{'product-quantity-'} ? $param{'product-quantity-'} : 1,
				'po'			=>	$param{'product-po-'},
				});
	} elsif ( $param{'action'} eq 'remove' ) {
		my $IP = new openprint::Invoiced_Product( $param{'product_id'} );
		if ( $IP->id() ) {
			$variable{'error'} .= $IP->delete();
		} else {
			$variable{'error'} .= "Product $param{'product_id'} does not exist.<br/>";
		} # end if
	} # end if
} # end sub _invoiced_products

sub _interests {

	if ( $param{'action'} eq 'delete' ) {
		my $Interest = new openprint::Invoice_Interest( $param{'interest_id'} );
		$variable{'Invoice'} = $Interest->Invoice();
		$variable{'error'} .= $Interest->delete();	
		$variable{'Invoice'}->interest(undef);
		$variable{'error'} = $variable{'Invoice'}->save();
	} # end if
} # end sub _interests
