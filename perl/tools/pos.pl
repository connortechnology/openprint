#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::PurchaseOrder;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
$session{'user_id'} = 1085;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=> 'point-one', 'driver'=>'Pg',login=>'point-one', 'password'=>'point-one', host=>'database' ) );
die if ! $dbh;

my $testing_dbh = sql::open_sql( $log, ('database'=> 'point-one', 'driver'=>'Pg',login=>'point-one', 'password'=>'point-one', host=>'localhost' ) );
die if ! $testing_dbh;


my $ac = sql::start_transaction( $dbh );
foreach my $PO ( openprint::PurchaseOrder->find('id >=' => 15104, 'id <=' => 15136, dbh=>$testing_dbh ) ) {
	$log->debug('PO ' . $PO->id() );
	$_ = $PO->save({}, 1 );
	if ( $_ ) {
		$dbh->rollback();
		die $_;
	} # end if
	foreach my $C ( openprint::PurchaseOrder_Content->find( po_id=>$$PO{id}, dbh=>$testing_dbh ) ) {
		$log->debug( $C->to_string() );
		if ( $$C{item_id} ) {
			my $Item = openprint::PurchaseOrder_Item->find_one( id => $$C{item_id}, dbh => $testing_dbh );
			if ( ! openprint::PurchaseOrder_Item->find_one( id => $$C{item_id} ) ) {
				$_ = $Item->save({}, 1 );
				if ( $_ ) {
					$dbh->rollback();
					die $_;
				} # end if
			} # end if
		} # end if

		$_ = $C->save( {}, 1 );
		if ( $_ ) {
			$dbh->rollback();
			die $_;
		} # end if
	} # end foreach C
	foreach my $L ( openprint::PurchaseOrder_Log->find( po_id=>$$PO{id}, dbh=>$testing_dbh ) ) {
		$log->debug( $L->to_string() );
		$_ = $L->save( {}, 1 );
		if ( $_ ) {
			$dbh->rollback();
			die $_;
		} # end if
	} # end foreach L
	foreach my $T ( openprint::PurchaseOrder_Tax->find( purchaseorder_id=>$$PO{id}, dbh=>$testing_dbh ) ) {
		$log->debug( $T->to_string() );
		$_ = $T->save( {}, 1 );
		if ( $_ ) {
			$dbh->rollback();
			die $_;
		} # end if
	} # end foreach L
} # end foreach PO
#$dbh->rollback();
sql::end_transaction( $dbh, $ac );

$dbh->disconnect();
1;
__END__
