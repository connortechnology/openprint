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
my $project_id_start = $ARGV[3];
my $project_id_end = $ARGV[4];

#
#my $project_id = 407192;
my $company_id = 0;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;

my $PaperService = openprint::ServiceType->find_one(name=>'Paper');
die 'No paper service' if ! $PaperService;

my $ac = sql::start_transaction( $dbh );
PROJECT: foreach my $Project ( openprint::Project->find( order=>'id', 
			'servicetype_id any'	=>	$PaperService->id(),
			( $project_id_end ? ( 'id <='=>$project_id_end) : () ),
			( $project_id_start ? ( 'id >='=>$project_id_start) : () ),
			( $company_id ? ( company_id=>$company_id ) : () ),
			limit=>$projects_count ) ) {
# Skip multipage projects
	
	my $services = $Project->services();
	my $paper_specs = openprint::service::get_specs_ref( $Project, $$services{Paper}[0] );

	my @sigs = $Project->signatures();
	foreach my $ss_id ( @sigs ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		my $form = $$sig_specs{SignatureIndex};
	
		foreach my $field ( 'qty','sheets','overrideqty','cost','overridecost','price' ) {
			foreach my $stock_index ( 1 .. 4 ) {
				foreach my $qty_index ( $Project->quantity_indexes() ) {
					my $old_field = join('-', $field, $ss_id, $stock_index, $qty_index );
					my $new_field = join('-', $field, $form, $stock_index, $qty_index );
					if ( $$paper_specs{$old_field} ) {
						if ( $$paper_specs{$new_field} ) {
							print "Already upgraded project $$Project{id}\n";
							openprint::service::delete_service_spec( $$Project{id}, $$services{Paper}[0], $old_field );
						} # end if
						openprint::service::insert_service_spec( $log, $dbh, $$Project{id}, $$services{Paper}[0], $new_field, $$paper_specs{$old_field} );
					} #ne dif
				} # end foreach qty_index
			} # end foreach stock_index
		} # end foreach field	

		foreach my $field ( 'cost', 'overridecost', 'price' ) {
			my $old_field = join('-', $field, $ss_id, $stock_index, $qty_index );
			my $new_field = join('-', $field, $stock_index, $qty_index );
			if ( $$paper_specs{$old_field} ) {
				if ( $$paper_specs{$new_field} ) {
					print "Already upgraded project $$Project{id} have $new_field => $$paper_specs{$new_field}\n";
					#openprint::service::delete_service_spec( $$Project{id}, $$services{Paper}[0], $old_field );
				} # end if
				openprint::service::insert_service_spec( $log, $dbh, $$Project{id}, $$services{Paper}[0], $new_field, $$paper_specs{$old_field} );
			} # end if
		} # end foreach field
	} # end foreach ss_id

} # end foreach Project
sql::end_transaction( $dbh, $ac );

$dbh->disconnect();

1;
__END__
