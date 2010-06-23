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

$log = new logger( 'debug' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'password'} = $ARGV[2];

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );

my $ac = sql::start_transaction( $dbh );
foreach my $FS ( openprint::FoldSpecification->find() ) {
	if ( $$FS{'weight_units'} eq 'gsm' ) {
		$log->debug("Converting $$FS{min_weight} to $$FS{max_weight} gsm to " . openprint::Paper::gsm_to_weight( $$FS{min_weight} ) . ' to ' . openprint::Paper::gsm_to_weight( $$FS{max_weight} ) . 'lbs' );
		$$FS{min_weight} = openprint::Paper::gsm_to_weight( $$FS{min_weight} );
		$$FS{max_weight} = openprint::Paper::gsm_to_weight( $$FS{max_weight} );
		$$FS{'weight_units'} = 'lbs';
		$FS->save();
	} else {
		$log->debug("Not Converting $$FS{min_weight} to $$FS{max_weight} $$FS{weight_units}" );
		if ( $$FS{min_weight} =~ /(\d\d)(\d\d)/ ) {
			$$FS{min_weight} = "$1.$2";
		} # end if
		if ( $$FS{max_weight} =~ /(\d\d)(\d\d)/ ) {
			$$FS{max_weight} = "$1.$2";
		} # end if
		$FS->save();
	} # end fi
} # end foraech my $FS
sql::end_transaction( $dbh, $ac );
$dbh->disconnect();
