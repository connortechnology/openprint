#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::PurchaseOrder;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>'point-one', 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one', 'host'=>'database') );
	
my $ac = sql::start_transaction( $dbh );

foreach my $PO ( openprint::PurchaseOrder->find('created_on >=' => '2012-09-01 00:00:00', 'vendor_state'=>'ON', 'vendor_country' => 'CA' ) ) {
	if ( sets::isin( 'GST', map { $_->name } $PO->Taxes() ) ) {
$log->debug("PO $$PO{id} needs updating: C$$PO{vendor_country} S$$PO{vendor_state}");
		$PO->save();
	} # end if
} # end foreach PO
sql::end_transaction( $dbh, $ac );
$dbh->disconnect();
1;
__END__
