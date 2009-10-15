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
	
my @PIS = openprint::PaperInventory::find();
foreach my $PI ( @PIS ) {
	if ( $PI->comment() =~ /Inventory adjusted from manifest <a href="\/employee\/inventory\/manifest.html\?manifest_id=(.+)">.+<\/a>/ ) {
		$PI->comment( qq`Inventory adjusted from manifest $1` );
	} elsif ( $PI->comment() =~ /^Checked out for docket <a href="\/employee\/project\/view\.html\?ProjectIndex=(\d+)">(\d+)<\/a> by (.+)$/ ) {
		$PI->comment( qq`Checked out for docket $2 by $3` );
	} # end if
	$PI->instock(undef);
	$_ = $PI->save();
	$log->error( $_ ) if $_;
} # end foreach PI
$dbh->disconnect();
1;
__END__
