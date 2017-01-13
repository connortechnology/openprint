#!/usr/bin/perl
use lib '/var/www/point-one/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::PurchaseOrder;
require openprint::PurchaseOrder_Tax;
require openprint::Claim;
require openprint::Claim_Tax;
require openprint::Tax;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
@session{'company_id','user_id'} = ( 6, 1085 );

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );

my $GST_Tax = openprint::Tax->find_one('state'=>undef,'country'=>undef,'rate'=>5);
my $PST_Tax = openprint::Tax->find_one('state'=>undef,'country'=>undef,'rate'=>8);
	
foreach my $PO ( openprint::PurchaseOrder->find('created_on_end'=>'2010-06-30') ) {
	if ( ! openprint::PurchaseOrder_Tax->find('purchaseorder_id'=>$PO->id() ) ) {
		my $GST = new openprint::PurchaseOrder_Tax();
		$GST->save({
			'purchaseorder_id'	=>	$PO->id(),
			'rate'				=>	5,
			'amount'			=>	$PO->federaltax(),
			'charge'			=>	$PO->federaltax_charge(),
			'tax_id'			=>	$GST_Tax->id(),
		});

		my $PST = new openprint::PurchaseOrder_Tax();
		$PST->save({
			'purchaseorder_id'	=>	$PO->id(),
			'rate'				=>	8,
			'amount'			=>	$PO->statetax(),
			'charge'			=>	$PO->statetax_charge(),
			'tax_id'			=>	$PST_Tax->id(),
		});
	} # end if
} # end foreach PO
foreach my $Claim ( openprint::Claim->find('created_on_end'=>'2010-06-30') ) {
	if ( ! openprint::Claim_Tax->find('claim_id'=>$Claim->id() ) ) {
		my $GST = new openprint::Claim_Tax();
		$GST->save({
			'claim_id'	=>	$Claim->id(),
			'rate'				=>	5,
			'amount'			=>	$Claim->federaltax(),
			'charge'			=>	$Claim->federaltax_charge(),
			'tax_id'			=>	$GST_Tax->id(),
		});

		my $PST = new openprint::Claim_Tax();
		$PST->save({
			'claim_id'	=>	$Claim->id(),
			'rate'				=>	8,
			'amount'			=>	$Claim->statetax(),
			'charge'			=>	$Claim->statetax_charge(),
			'tax_id'			=>	$PST_Tax->id(),
		});
	} # end if
} # end foreach Claim
$dbh->disconnect();
1;
__END__
