#!/usr/bin/perl -w
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
$sql_server{host} = 'database';

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );

foreach my $Project ( openprint::Project->find( 
	$ARGV[3] ? ( id=>$ARGV[3] ) : (
		#'created_on_start'=>sprintf('%.4d-%.2d-%.2d 00:00:00', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -90 ) ),
 'order'=>'id desc' )
) ) {

	$log->debug("Doing $$Project{id}");
	my $services = $Project->services();
	if ( ! $$services{Paper} ) {
		$log->warn("Project $$Project{id} doesn't have a paper service");
		next;
	}

	my $paper_specs = openprint::service::get_specs_ref( $Project, $$services{Paper}[0] );
	my @Stocks = openprint::Estimating::Paper::get_stocks( $Project );

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		foreach my $sig_id ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
			my $form = $$sig_specs{SignatureIndex};

			foreach my $Stock_Entry ( @Stocks ) {
				$log->debug("Checking $$Stock_Entry{key}");
				foreach my $spec ( 'qty', 'overrideqty','sheets' ) {
					if ( $$paper_specs{"$spec-$form-$$Stock_Entry{index}-$qty_index"} ) {
						if ( ! $$paper_specs{"$spec-form$form-$qty_index"} ) {
							$log->debug("Setting value for $spec-$form-$$Stock_Entry{index}-$qty_index");
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $$services{Paper}[0], 
									"$spec-form$form-$qty_index", 
									$$paper_specs{"$spec-$form-$$Stock_Entry{index}-$qty_index"} );
						} else {
							$log->debug("Already set value for $spec-$form-$$Stock_Entry{index}-$qty_index");
						}
					} else {
						$log->debug("No value for $spec-$form-$$Stock_Entry{index}-$qty_index");
					}
				} # end foreach spec
			} # end if
		} # end foreach sig
	} # end foreach qty
} # end foreach Project
1;
__END__
