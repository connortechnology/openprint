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
use configuration ();

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
$sql_server{'password'} = $sql_server{'login'} if ! $sql_server{'password'};

$openprint::Object::config{"db_name"} = $sql_server{'database'};

$openprint::Object::no_cache = 1;
my $projects_count = 0;
my $project_id = $ARGV[3];
die if ! $project_id;

#
#my $project_id = 407192;
my $company_id = 0;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;

foreach my $Project ( openprint::Project->find( 'order'=>'id desc',
			'type !='	=>	'MultiPage',
			#'status not in'	=>	['uncalculated','Deleted'],
			( $project_id ? ( 'id'=>$project_id) : () ),
			( $company_id ? ( 'company_id'=>$company_id ) : () ),
			limit=>$projects_count  ) ) {
# Skip multipage projects
	next if sets::isin( $Project->Type()->name(), [ 'MultiPage', 'Magazines','Calendars' ] );
	my $services = $Project->services();
	next if ! $$services{''};
	next if ! $$services{''}[0];

	my @sigs = $Project->signatures();
	my $dead = 0;
	foreach my $sig ( @sigs ) {
		my $PService = $Project->Service( $sig );
		my $sig_specs = $PService->specs();
		if ( ! ( $$sig_specs{txtWidth} or $$sig_specs{txtHeight} or $$sig_specs{txtFinalWidth} or $$sig_specs{txtFinalHeight} ) ) {
			$dead += 1;

		} # end if
	} # end foreach sig
	next if $dead != @sigs;

	print $Project->id() . " hit enter to do it\n";
	my $input = <STDIN>;
	last if $input eq 'q';
	next if $input eq 'n';

	my $ac = sql::start_transaction( $dbh );
	my $print_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	$log->debug("Sigs: @sigs ");
	foreach my $sig ( @sigs ) {
		my $PService = $Project->Service( $sig );
		my $sig_specs = $PService->specs();
		if ( ! ( $$sig_specs{txtWidth} or $$sig_specs{txtHeight} or $$sig_specs{txtFinalWidth} or $$sig_specs{txtFinalHeight} ) ) {
			$PService->delete();
		} # end if
	} # end foreach sig
	@sigs = $Project->signatures();
	$log->debug("Sigs after deleting: @sigs ");
	if ( ! @sigs ) {
		my $new_signature = $Project->copy_signature( $print_specs, {}, openprint::service::status( $Project->id(), $$services{''}[0] ) );
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $$services{''}[0], 'txtPrice'.$qty_index, undef );
		} # end foreach
	} elsif ( @sigs == 1 ) {
		my $PService = $Project->Service( $sigs[0] );
		my $sig_specs = $PService->specs();
		if ( ! ( $$sig_specs{txtWidth} and $$sig_specs{txtHeight} ) ) {
			$PService->delete();
		} else {
			$log->debug("Not changing $$Project{id}");
		} # end if
	} # end if
	if ( $_ = $dbh->errstr() ) {
		$dbh->rollback();
		die $_;
	} # end if
	sql::end_transaction( $dbh, $ac );

} # end foreach Project

$dbh->disconnect();

1;
__END__
