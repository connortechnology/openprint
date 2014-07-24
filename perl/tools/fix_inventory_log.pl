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
	
my @PIS = openprint::PaperInventory->find( docket=>undef, 'comment like'=>'Checked out for docket %' );
foreach my $PI ( @PIS ) {
	my ( $docket ) = $PI->comment() =~ /^Checked out for docket (\d+)/;
	if ( $docket ) {
		if ( ! $$PI{docket} ) {
			$log->debug($PI->to_string() );
			$PI->save({docket=>$docket});
		} else {
$log->debug("Has docket? " . $PI->to_string() );
			
		}
	} else {
$log->debug("No docket? " . $PI->to_string() );
	} # end if
if ( 0 ) {
	if ( $PI->comment() =~ /Inventory adjusted from manifest <a href="\/employee\/inventory\/manifest.html\?manifest_id=(.+)">.+<\/a>/ ) {
		$PI->comment( qq`Inventory adjusted from manifest $1` );
	} elsif ( $PI->comment() =~ /^Checked out for docket <a href="\/employee\/project\/view\.html\?ProjectIndex=(\d+)">(\d+)<\/a> by (.+)$/ ) {
		$PI->comment( qq`Checked out for docket $2 by $3` );
	} # end if
	$PI->instock(undef);
	$_ = $PI->save();
	$log->error( $_ ) if $_;

	if ( $$PI{skid_id} ) {
		my @SC = openprint::SkidContent->find(skid_id=>$$PI{skid_id}, 'deleted in'=> [0,1] );
		if ( @SC == 1 ) {
			if ( $SC[0]{paper_id} ) {
				$PI->save({paper_id=>$SC[0]{paper_id}});
			} # end if
		} else {
			foreach my $SC ( @SC ) {
$log->debug($SC->to_string());
			} # end foreach
		} # end if
	} # end if
}
} # end foreach PI
$dbh->disconnect();
1;
__END__
