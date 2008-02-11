#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Paper;
require openprint::FoldSpecification;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'password'} = $ARGV[2];

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );

my $ac = sql::start_transaction( $dbh );
foreach my $Fold ( openprint::Fold::find() ) {
	foreach my $FS ( openprint::FoldSpecification::find('Fold'=>$Fold) ) {
		if ( $$FS{'interpolate'} and ( $$FS{min_weight} != $$FS{max_weight} ) ) {
			$log->error( sprintf('Fold %s on %s has invalid interpolate/min_weight/max_weight settings', $Fold->name(), $Fold->Equipment()->name() ) );
			last;
		} # end if
	} # end foraech my $FS
} # end foraech my $Folf
sql::end_transaction( $dbh, $ac );
$dbh->disconnect();
