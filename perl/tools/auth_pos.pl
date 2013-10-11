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

my $Dennis = openprint::User->find_one( email=>'dennis@point-one.com' );

my $ac = sql::start_transaction( $dbh );
foreach my $PO ( openprint::PurchaseOrder->find( authorized =>undef, order => 'id' ) ) {
	$log->debug('PO ' . $PO->id() );
	if ( $PO->can_authorize( $PO->Creator() ) ) {
		$_ = $PO->save({authorized=>1});
		if ( $_ ) {
			$dbh->rollback();
			die $_;
		} # end if
	} 
	$_ = $PO->save({authorized=>1, authorized_by=>$Dennis->id(), authorized_on=>'NOW()'});
		if ( $_ ) {
			$dbh->rollback();
			die $_;
		} # end if
} # end foreach PO
#$dbh->rollback();
sql::end_transaction( $dbh, $ac );

$dbh->disconnect();
1;
__END__
