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
$sql_server{'database'} = 'topknotch';
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'topknotch';
$sql_server{'password'} = 'topknotch';

$dbh = sql::open_sql( $log, %sql_server );

$openprint::Object::no_cache = 1;
foreach my $Project ( openprint::Project->find('created_on_start'=>sprintf('%.4d-%.2d-%.2d 00:00:00', Date::Calc::Add_Delta_Days(Date::Calc::Today(), -31)),'order'=>'index DESC' ) ) {
	my $services = $Project->services();
	if ( $$services{'UVCoating'} ) {
		my $varnish_specs = openprint::service::get_specs_ref( $Project, $$services{'UVCoating'}[0] );
		foreach my $ss_id ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
			
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, 'SideOneUVCoatingType', $$varnish_specs{'SideOneCoatingType-'.$$sig_specs{'SignatureIndex'}} );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, 'SideTwoUVCoatingType', $$varnish_specs{'SideTwoCoatingType-'.$$sig_specs{'SignatureIndex'}} );
		} # end foreach
	} # end if
} # end foreach
