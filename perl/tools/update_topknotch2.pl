use strict;
#!/usr/bin/perl
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

my $BrochureType = openprint::ProjectType->find_one('name'=>'Brochures');
if ( $BrochureType ) {
    foreach my $PT ( openprint::ProjectType_Template->find( 'projecttype_id'=>$BrochureType->id(), 'type'=>'8PageSignatureFold') ) {
        $_ = $PT->save({'type'=>'8 Page Fold'});
        $log->error($_) if $_;
    }
    sql::update( undef, undef, 'tbl_service_specifications', [ 'strname=?', '8PageSignatureFold' ], 'strvalue', '8 Page Fold' );

    my %templates = (
        'NoFold' => 'No Fold',
        '2PanelFold' => '2 Panel Fold',
        '3PanelFold' => '3 Panel Fold',
        '3PanelZFold' => '3 Panel Z Fold',
        '4PanelFold' => '4 Panel Fold',
        '4PanelZFold' => '4 Panel Z Fold',
		'4PanelRollFold' => '4 Panel Roll Fold',
        '5PanelFold' => '5 Panel Fold',
        '5PanelZFold' => '5 Panel Z Fold',
        '6PanelFold' => '6 Panel Fold',
        '6PanelZFold' => '6 Panel Z Fold',
        '8PageFold' => '8 Page Fold',
        '12pg3PanelRollFold' => '12pg 3 Panel Roll',
        '12pg3PanelZFold' => '12pg 3 Panel Z',
        'DoubleGateFold' => 'Double Gate Fold',
        'SingleGateFold' => 'Single Gate Fold',
        'AdditionalFoldTypes'   =>  'Additional Fold Types',
    );
    foreach my $key ( keys %templates ) {
        sql::update( $log, undef, 'projecttemplate', [ 'type=?', $key ], 'name', $templates{$key} );
    }

} else {
    $log->error("No Brochures");
    die;
}

$dbh->disconnect();
	
1;
__END__
