#!/usr/bin/perl
use strict;
use lib '/var/www/testing/perl';
require sql;
require logger;
require openprint::Object;
require openprint::Project;
require openprint::service;
require openprint::ServiceType;
require openprint::ServiceType_Default;
require openprint::ProjectType_Default;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'database'} = 'topknotch' if ! $sql_server{'database'};
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'login'} = $sql_server{'database'} if ! $sql_server{'login'};
$sql_server{'password'} = $ARGV[2];
$sql_server{'password'} = $sql_server{'login'} if ! $sql_server{'password'};

$openprint::Object::no_cache = 1;
my $projects_count = 100;
my $project_id = 0;
my $company_id = 1;

$dbh = sql::open_sql( $log, %sql_server );

my $ServiceType = openprint::ServiceType->find_one('name'=>'Signature');

foreach my $PTD ( openprint::ProjectType_Default->find( name=> ['BleedBottom','BleedTop','BleedLeft','BleedRight','rdbColourBar','dutch1','dutch2','dutch3','txtCropMarkSpace'] ) ) {
    if ( openprint::ServiceType_Default->find_one( name=>$PTD->name(), projecttype_id=>$PTD->projecttype_id() ) ) {
		$PTD->delete();
		next;
    } elsif ( openprint::ServiceType_Default->find_one( name=>$PTD->name(), projecttype_id=>undef ) ) {
		$PTD->delete();
		next;
	} else {
    my $STD = new openprint::ServiceType_Default();
    $STD->save({ servicetype_id=>$ServiceType->id(), name=>$PTD->name(), projecttype_id=>$PTD->projecttype_id(), value => $PTD->value() });
	$PTD->delete();
	} # end if
}

$dbh->disconnect();
	
1;
__END__
