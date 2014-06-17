#!/usr/bin/perl 
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Order;
require openprint::Invoice;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

$openprint::Object::no_cache = 1;

$log = new logger( 'debug' );

$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[1] if ! $ARGV[2];

$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );

if ( 1 ) {
my $ac = sql::start_transaction( $dbh );

foreach my $Order ( openprint::Order->find( 'invoice_id is null'=>0 ) ) {
	next if ! $Order->invoice_id();

	next if openprint::Invoice->find_one(num=>$Order->invoice_id(), invoicee_id => $Order->company_id() );
	next if openprint::Invoice->find_one(id=>$Order->invoice_id(), invoicee_id => $Order->company_id() );

	my ( $invoiced_on ) = sql::execute( undef, undef, 'SELECT invoiced_on FROM Orders where id=?', $Order->id() );
	if ( ! $invoiced_on ) {
		$log->warn( "No invoiced_on for $$Order{id}" );
		next;
	} # end if

	my $Invoice = new openprint::Invoice();
	$_ = $Invoice->save({
		num=>$Order->invoice_id(),
		invoicer_id=>6,
		invoicee_id=>$Order->company_id(),
		 });
	if ( $_ ) {
		$dbh->rollback();
		die $_;
	} # end if
	if ( $dbh->errstr() ) {
		$dbh->rollback();
		die $$dbh->errstr();
	} # end if
	$$Order{invoice_id} = $Invoice->id();
	sql::update( undef, undef, 'invoices', [ 'id=?', $Invoice->id() ], 'created_on', $invoiced_on ) if $invoiced_on;
	sql::update( undef, undef, 'orders', [ 'id=?', $Order->id() ], 'invoice_id', $Invoice->id() );
} # end foreach Order
sql::end_transaction( $dbh, $ac );
}

if ( 0 ) {
my $ac = sql::start_transaction( $dbh );
foreach my $Order ( openprint::Order->find( 'invoice_id is null'=>0 ) ) {
	next if ! $Order->invoice_id();
	if ( $Order->invoice_id() =~ /\D/ ) {
		$log->warn("Bad invoice_id on Order $$Order{id} : $$Order{invoice_id} ");
		next;
	} # end if

	next if $Order->Invoices();
	if ( ! openprint::Invoice->find_one(id=>$Order->invoice_id()) ) {
		$log->warn("No invoice found for Order $$Order{id} : $$Order{invoice_id} ");
		next;
	} # end if
	my $OI = new openprint::Order_Invoice();
	$_ = $OI->save({order_id=>$$Order{id}, invoice_id=>$$Order{invoice_id} });

	if ( $_ ) {
		$dbh->rollback();
		die $_;
	} # end if
	if ( $dbh->errstr() ) {
		$dbh->rollback();
		die $dbh->errstr();
	} # end if
} # end foreach Order
sql::end_transaction( $dbh, $ac );
}
	

	

