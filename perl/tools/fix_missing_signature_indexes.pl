#!/usr/bin/perl
use lib '/var/www/testing/perl';
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

foreach my $Project ( openprint::Project::find( 'created_on_start'=>sprintf('%.4d-%.2d-%.2d 00:00:00', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -90 ) ), 'order'=>'index desc' ) ) {
	foreach my $sig_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		if ( $$sig_specs{'SignatureIndex'} eq '' ) {
			$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
			my ( $sig_index ) = sql::execute( undef, undef, $_, $Project->id() );
			$sig_index += 1;
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'SignatureIndex', $sig_index );
		} # end if
	} # end foreach sig
} # end foreach Project
1;
__END__
