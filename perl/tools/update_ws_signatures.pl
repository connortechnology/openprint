#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Project;
require openprint::service;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'debug' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'database'} = 'point-one' if ! $sql_server{'database'};
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'login'} = $sql_server{'database'} if ! $sql_server{'login'};
$sql_server{'password'} = $ARGV[2];
$sql_server{'password'} = $sql_server{'database'} if ! $sql_server{'password'};

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );

foreach my $Project ( openprint::Project::find() ) {
	my $services = $Project->services();

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] ) if $$services{''};

	foreach my $sig_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		foreach my $bleed ( 'Left','Right','Top','Bottom' ) {
			if ( $$sig_specs{'chkBleed'.$bleed} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Bleed'.$bleed, $$sig_specs{'chkBleed'.$bleed} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkBleed'.$bleed, '' );
			} # end if
		} # end foreach
	} # end foreach sig_id
} # end foreach Project
