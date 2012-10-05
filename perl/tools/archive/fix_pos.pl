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
my $old_dbh = sql::open_sql( $log, ('database'=>'isaac', 'driver'=>'Pg','login'=>'point-one', 'password'=>'point-one', 'host'=>'localhost') );
if ( ! $old_dbh ) {
die "Can't connect to old db";
}
	
my $ac = sql::start_transaction( $dbh );

my @data = sql::execute( $log, $old_dbh, 'SELECT id,authorized_by,authorized_on FROM purchaseorders WHERE authorized_by!=6709' );
$log->debug("Records: " . ( @data/3) );
while ( @data ) {
	my ( $id,$by,$on) = splice @data, 0, 3;

	my $PO = new openprint::PurchaseOrder( $id );
$log->debug("Po $id $by $on => $$PO{authorized_by} $$PO{authorized_on}");
	if ( ($PO->authorized_by() != $by) or ( $PO->authorized_on() ne $on ) ) {
		$_ = $PO->save({'authorized_by'=>$by,'authorized_on'=>$on});
		if ( $_ ) {
			$dbh->rollback();
			die $_;
		} # end if
	} # end if
	
} # end foreach PI
sql::end_transaction( $dbh, $ac );
$dbh->disconnect();
$old_dbh->disconnect();
1;
__END__
