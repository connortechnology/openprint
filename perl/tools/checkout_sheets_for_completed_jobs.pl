#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Company;
require openprint::User;
require openprint::Project;
require openprint::Quote;
require openprint::Order;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
@session{'company_id','user_id'} = ( 6, 1085 );

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
	
my $ac = sql::start_transaction( $dbh );
foreach my $Skid ( openprint::Skid->find( type=>'Sheet', 'quantity >=' => 1 ) ) {
		my @dockets = $Skid->dockets();
		if ( ! @dockets ) {
			print "No dockets for $$Skid{id}\n";
			next;
		} else {
			print "dockets for $$Skid{id} @dockets\n";
			next if @dockets > 1;
		}
		foreach my $Order ( openprint::Order->find( docket=>\@dockets ) ) {
			if ( sets::isin( $Order->status(), [  'Printed', 'Complete','Waiting For Pickup', 'Picked Up', 'Shipped' ] ) ) {
				print "Checkout skid $$Skid{id} for docket $$Order{docket}\n";
				$Skid->checkout( $Order->docket(), 'automatically because job is complete.' );
			}
		}
} # end foreach Skid
#$dbh->rollback();
sql::end_transaction( $dbh, $ac );
$dbh->disconnect();
1;
__END__
