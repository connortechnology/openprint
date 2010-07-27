#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Paper;
require openprint::PaperPrice;
require openprint::Equipment;
require openprint::EquipmentSpecification;
require openprint::ServicePrice;
require openprint::ServiceType;
require openprint::Service;
require openprint::ServiceCategory;
require openprint::Project;
require openprint::service;
require openprint::Material;
require openprint::MaterialCategory;
require openprint::PaperInventory;
require openprint::Log;
require openprint::Host;
require openprint::Invoice;
require openprint::Order;
require openprint::Order_Tax;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

$openprint::Object::no_cache = 1;

$log = new logger( 'debug' );

$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[0] if ! $ARGV[2];

$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
configuration::init_cache( $log, $dbh );

my @tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
my @sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);

if ( ! sets::isin( 'quote_log', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Quote_Log.sql}) );
} # end if
if ( ! sets::isin( 'quoted_products', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Quoted_Products.sql}) );
} # end if

if ( sets::isin( 'quotes', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM quotes LIMIT 1', {} );
	if ( $data ) {
		$dbh->do('ALTER TABLE quotes add reference text') if ! exists $$data{'reference'};
		$dbh->do('ALTER TABLE quotes add comments text') if ! exists $$data{'comments'};
		$dbh->do('ALTER TABLE quotes add deleted boolean default false') if ! exists $$data{'deleted'};
	} # end if
} # end if
if ( sets::isin( 'pricelists', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM pricelists LIMIT 1', {} );
	if ( $data ) {
		$dbh->do('ALTER TABLE pricelists add deleted boolean default false') if ! exists $$data{'deleted'};
	} # end if
} # end if
if ( sets::isin( 'invoiced_products', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM invoiced_products LIMIT 1', {} );
	if ( $data ) {
		$dbh->do('ALTER TABLE invoiced_products add po text') if ! exists $$data{'po'};
	} # end if
} # end if
if ( sets::isin( 'hosts', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='hosts'", 'column_name');
	$dbh->do('ALTER TABLE hosts add block boolean') if ! exists $$data{'block'};
	$dbh->do('ALTER TABLE hosts add monitor boolean') if ! exists $$data{'monitor'};
} # end if
my $data = 0;
if ( sets::isin( 'emailcampaigns', \@tables ) ) {
	$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM emailcampaigns LIMIT 1', {} );
} else {
	$_ = misc::load_file( $log, q{../openprint/sql/EmailCampaigns.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

my $data = 0;
if ( sets::isin( 'ordered_products', \@tables ) ) {
	$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM ordered_products LIMIT 1', {} );
} # end if
if ( $data ) {
	$dbh->do('ALTER TABLE Ordered_products drop column gst') if ( exists $$data{'gst'} );
	$dbh->do('ALTER TABLE Ordered_products drop column pst') if ( exists $$data{'pst'} );
	$dbh->do('ALTER TABLE Ordered_products drop column hst') if ( exists $$data{'hst'} );
}


if ( sets::isin( 'taxes', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM taxes LIMIT 1', {} );
	if ( $data ) {
		if ( ! exists $$data{'name'} ) {
			$dbh->do('ALTER TABLE taxes add name text');
		} # end if
		if ( ! exists $$data{'rate'} ) {
			$dbh->do('ALTER TABLE taxes add rate float');
			$dbh->do('UPDATE Taxes set rate=federaltax where federaltax IS NOT NULL');
			$dbh->do('UPDATE Taxes set rate=statetax where statetax IS NOT NULL');
			$dbh->do('UPDATE Taxes set rate=harmonizedtax where harmonizedtax IS NOT NULL');
		} # end if
		if ( ! exists $$data{'period_start'} ) {
			$dbh->do('ALTER TABLE taxes add period_start date');
		} # end if
		if ( ! exists $$data{'period_end'} ) {
			$dbh->do('ALTER TABLE taxes add period_end date');
		} # end if
		if ( exists $$data{'federaltax'} ) {
			$dbh->do('ALTER TABLE taxes DROP column federaltax');
		}
		if ( exists $$data{'statetax'} ) {
			$dbh->do('ALTER TABLE taxes DROP column statetax');
		}
		if ( exists $$data{'harmonizedtax'} ) {
			$dbh->do('ALTER TABLE taxes DROP column harmonizedtax');
		}
	} # end if data
} # end if
if ( ! sets::isin( 'invoice_taxes', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Invoice_Taxes.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

$dbh->do("UPDATE companies set country='CA' WHERE country='Canada'");
$dbh->do("UPDATE companies set state='ON' WHERE state='Ontario'");
$dbh->do("UPDATE taxes set country='CA' WHERE country='Canada'");
$dbh->do("UPDATE taxes set state='ON' WHERE state='Ontario'");
if ( ! openprint::Invoice_Tax->find() ) {
	my $ac = sql::start_transaction( $dbh );
	foreach my $Invoice ( openprint::Invoice->find() ) {
		my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM invoices WHERE id=? LIMIT 1', {}, $Invoice->id() );
		foreach my $Tax ( openprint::Tax->find(
					'country'			=>	$Invoice->Invoicee()->country(), 
					'state'				=>	$Invoice->Invoicee()->state(), 
					'period_start_null_or_<='	=>	$Invoice->created_on(),
					'period_end_null_or_>='		=>	$Invoice->created_on(),
			) ) {
			my $new_amount;

			if ( ( $Tax->name() eq 'GST' ) and ( $new_amount != $$data{'federaltax'} ) ) {
				$new_amount = $$data{'federaltax'};
			} elsif ( $Tax->name() eq 'PST' ) {
				if ( new openprint::Company( $config{'owner'} )->pst_number() and ( $new_amount != $$data{'statetax'} ) ) {
				$new_amount = $$data{'statetax'};
				} # end if
			} else {
				$new_amount = sprintf('%.2f', $Invoice->subtotal() * ( $Tax->rate()/100 ) );
			} # end if
				
			my $Invoice_Tax = new openprint::Invoice_Tax();
			$_ = $Invoice_Tax->save({
				'invoice_id'	=>	$Invoice->id(),
				'tax_id'		=>	$Tax->id(),
				'rate'			=>	$Tax->rate(),
				'amount'		=>	$new_amount,
			});
			$log->warn( $_ ) if $_;
		} # end foreach tax
	} # end foreach Invoice
	sql::end_transaction( $dbh, $ac );
} # end if

if ( ! sets::isin('order_taxes', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Order_Taxes.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

if ( ! openprint::Order_Tax->find() ) {
	my $ac = sql::start_transaction( $dbh );
	foreach my $Order ( openprint::Order->find() ) {
		my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Orders WHERE index=? LIMIT 1', {}, $Order->id() );
		if ( ! $data ) {
			die 'Error loading order ' . $Order->id() . ' : ' . $openprint::dbh->errstr();
		} # end if
		foreach my $Tax ( openprint::Tax->find(
					'country'			=>	$Order->country(), 
					'state'				=>	$Order->state(), 
					'period_start_null_or_<='	=>	$Order->created_on(),
					'period_end_null_or_>='		=>	$Order->created_on(),
			) ) {
			my $new_amount;

			if ( ( $Tax->name() eq 'GST' ) and ( $new_amount != $$data{'curfedtax'} ) ) {
				$new_amount = $$data{'curfedtax'};
			} elsif ( $Tax->name() eq 'PST' ) {
				if ( new openprint::Company( $config{'owner'} )->pst_number() and ( $new_amount != $$data{'curprovtax'} ) ) {
				$new_amount = $$data{'curprovtax'};
				} # end if
			} else {
				$new_amount = sprintf('%.2f', $Order->subtotal() * ( $Tax->rate()/100 ) );
			} # end if
				
			my $Order_Tax = new openprint::Order_Tax();
			$_ = $Order_Tax->save({
				'order_id'	=>	$Order->id(),
				'tax_id'		=>	$Tax->id(),
				'rate'			=>	$Tax->rate(),
				'amount'		=>	$new_amount,
			});
			$log->warn( $_ ) if $_;
		} # end foreach tax
	} # end foreachOrder 
	sql::end_transaction( $dbh, $ac );
} # end if
my $data = 0;
if ( sets::isin( 'orders', \@tables ) ) {
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='orders'", 'column_name');
} # end if
if ( $data ) {
	if ( ! exists $$data{'id'} ) {
		$dbh->do('ALTER TABLE orders rename column index to id');
	} # end if
	$dbh->do('ALTER TABLE Orders ADD paid NUMERIC(10,2)') if ( ! exists $$data{'paid'} );
	$dbh->do('UPDATE Orders set paid=(SELECT SUM(amount) From Payments WHERE payments.order_id=orders.id)');
	$dbh->do('ALTER TABLE Orders ADD owing NUMERIC(10,2)') if ( ! exists $$data{'owing'} );
	$dbh->do('UPDATE orders SET owing=curtotalsale-paid');
}
if ( sets::isin('purchaseorders', \@tables ) ) {
	$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM purchaseorders LIMIT 1', {} );
	if ( $data ) {
		if ( ! exists $$data{'manifest_id'} ) {
			$dbh->do('ALTER TABLE purchaseorders add manifest_id integer');
			$dbh->do('ALTER TABLE purchaseorders add FOREIGN KEY (manifest_id) REFERENCES Manifests (id)');
		} # end if
		$dbh->do('ALTER TABLE purchaseorders add authorized boolean default false') if ! exists $$data{'authorized'};
		$dbh->do('ALTER TABLE purchaseorders add cancelled boolean default false') if ! exists $$data{'cancelled'};
		$dbh->do('ALTER TABLE purchaseorders add vendor_contact text') if ! exists $$data{'vendor_contact'};
		$dbh->do('ALTER TABLE purchaseorders add vendor_sms text') if ! exists $$data{'vendor_sms'};
		$dbh->do('ALTER TABLE purchaseorders add shipto_contact text') if ! exists $$data{'shipto_contact'};
		$dbh->do('ALTER TABLE purchaseorders add shipto_mobile text') if ! exists $$data{'shipto_mobile'};
		$dbh->do('ALTER TABLE purchaseorders add shipto_sms text') if ! exists $$data{'shipto_sms'};
		$dbh->do('ALTER TABLE purchaseorders add delivered_on_switch text') if ! exists $$data{'delivered_on_switch'};
	} # end if
} else {
	$_ = misc::load_file( $log, q{../openprint/sql/PurchaseOrders.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
if ( ! sets::isin('purchaseorder_taxes', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/PurchaseOrder_Taxes.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

if ( ! openprint::PurchaseOrder_ContentType->find_one('name'=>'Other') ) {
	my $PO_CT = new openprint::PurchaseOrder_ContentType();
	$PO_CT->save({'name'=>'Other'});
} # end if
if ( $config{'Default State Tax'} ) {
	$dbh->do("DELETE FROM Configuration WHERE name='Default State Tax'");
}
if ( $config{'Default Federal Tax'} ) {
	$dbh->do("DELETE FROM Configuration WHERE name='Default Federal Tax'");
}
	
$dbh->disconnect();
1;
__END__
