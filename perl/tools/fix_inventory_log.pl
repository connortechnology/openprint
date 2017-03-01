#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::PaperInventory;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
	
my $ac = sql::start_transaction($dbh);
my @PIS = openprint::PaperInventory->find( docket=>undef, 'comment like'=>'Updated from Inven%', user_id=>1085, 'updated_on >'=>'2016-12-20', 'updated_on <' => '2016-12-21' );
foreach my $PI ( @PIS ) {

	if ( $$PI{skid_id} ) {
		my @SC = openprint::SkidContent->find(skid_id=>$$PI{skid_id}, 'deleted in'=> [0,1] );
		if ( @SC == 1 ) {
			if ( $SC[0]{paper_id} ) {
				$SC[0]->save({quantity=>-1*$$PI{delta}});
				$PI->delete();
			} # end if
		} else {
			foreach my $SC ( @SC ) {
$log->debug($SC->to_string());
			} # end foreach
		} # end if
	} # end if
} # end foreach PI
#$dbh->rollback();
sql::end_transaction( $dbh, $ac );
$dbh->disconnect();
1;
__END__
