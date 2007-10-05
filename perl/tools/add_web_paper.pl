#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Paper;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'point-one';
$sql_server{'password'} = 'point-1';

$dbh = sql::open_sql( $log, %sql_server );
my %papers;
foreach my $Paper (openprint::Paper::find()) {
	next if ! ( $Paper->name() =~ /Point/ );
	next if ( $papers{join('-', ($Paper->name(), $Paper->finish(), $Paper->colour(), $Paper->weight()) )} );
	next if ! $Paper->recommendations();
	next if $Paper->type() eq 'Roll';

	my $P = $Paper->copy();
	$P->basis_width( 25 );
	$P->basis_height( 38 );
	$P->wpsi( ($P->mweight()/1000)/($P->width()*$P->height())) if $P->width() and $P->height();;
$log->warn(sprintf( '%sx%s  %s   %s', $P->width(), $P->height(), $P->mweight(), $P->wpsi() ) );
	$P->gsm( int $P->wpsi()*703069 );
	$P->mweight( 0 );
	$P->width( '' );
	$P->height( '' );
	$P->type('Roll');
	$P->save();

	$papers{join('-', ($Paper->name(), $Paper->finish(), $Paper->colour(), $Paper->weight()) )} = 1;
	
} # end foireach
$dbh->disconnect();
