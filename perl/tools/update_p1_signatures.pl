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
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'point-one';
$sql_server{'password'} = 'point-one';

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;

sql::update( undef, undef, 'tbl_Equipment_SPecifications', ['strvalue=?',9.488], 'strvalue',37.952);
sql::update( undef, undef, 'tbl_Equipment_SPecifications', ['strvalue=?',9.528], 'strvalue',37.952);
sql::update( undef, undef, 'tbl_Equipment_SPecifications', ['strvalue=?',4.724], 'strvalue',18.896);
sql::update( undef, undef, 'tbl_Equipment_SPecifications', ['strvalue=?',7.598], 'strvalue',37.990);
sql::update( undef, undef, 'tbl_Equipment_SPecifications', ['strvalue=?',7.598], 'strvalue',37.990);

foreach my $Project ( openprint::Project::find('id_start'=>300000) ) {
	foreach my $sig_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		foreach my $side ( 'SideOne','SideTwo' ) {
			if ( $$sig_specs{'rdbAqueous'.$side} ) {
				my $index;
				foreach $index ( 1 .. 8 ) {
					last if ! $$sig_specs{'ColourCoatingColour'.$side.$index};
				} # end foreach
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$side.$index $$sig_specs{'rdbAqueous'.$side} );
			} # end if
		} # end foreach side
	} # end foreach sig_id
} # end foreach
