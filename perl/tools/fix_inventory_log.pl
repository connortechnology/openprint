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

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>'www4') );
	
my @PIS = openprint::PaperInventory::find('comment_like'=>'Inventory adjusted from manifest <a href="/employee/inventory/manifest_id%');
$log->warn(@PIS . " records found.");
foreach my $PI ( @PIS ) {
	$PI->comment() =~ /Inventory adjusted from manifest <a href="\/employee\/inventory\/manifest_id=(.*)">.*<\/a>/;
	$PI->comment( qq`Inventory adjusted from manifest <a href="/employee/inventory/manifest.html?manifest_id=$1">$1</a>` );
	$_ = $PI->save();
	$log->error( $_ ) if $_;
} # end foreach PI
$dbh->disconnect();
1;
__END__
