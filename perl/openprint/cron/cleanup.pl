#!/usr/bin/perl 
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require ssi;
require logger;
require misc;
require configuration;
require openprint::Quote;
require openprint::Order;
require openprint::Project;
use Date::Calc;
use Apache::Session::Postgres;

use openprint ();
use vars qw($log $dbh);
*dbh = \$openprint::dbh;
*log = \$openprint::log;

my $r;
$log = logger->new('warn');

$dbh = sql::open_sql( $log, 
'database' => $ARGV[0],
'driver'   => 'Pg',
'login'    => $ARGV[1],
'password' => $ARGV[2],
);
die 'Error opening db' if ! $dbh;


# Clear out old sessions
foreach my $session ( sql::execute( $log, $dbh, q{SELECT id FROM sessions} ) ) {
    $session =~ s/\s//g;
    my %session;
    if ( ! eval q`tie %session, 'Apache::Session::Postgres', $session, { Handle => $dbh, Commit => 0, IDLength => 8 }` ) {
        $log->debug("Error fetching Session: $session: $@");
        next;
    }
    if ( ! $session{'lastupdated'} ) {
    $log->debug("Updating time $session");
        $session{'lastupdated'} = time;
        untie %session;
    } elsif ( time - $session{'lastupdated'} > ( 60*60*24*7 ) ) {
        untie %session;
		sql::execute( $log, $dbh, q{DELETE FROM sessions where id=?}, $session );
	} else {
		untie %session;
	} # end if

} # end foreach

if ( 1 ) {
# Clean out uncalculated projects
	my $ac = sql::start_transaction( $dbh );
	my @Projects = openprint::Project::find('status'=>'uncalculated','created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ) );
	$log->debug("# of projects to delete: @Projects");
	foreach my $Project ( @Projects ) {
		$Project->delete();
	} # end foreach
	my @Projects = openprint::Project::find('status'=>'Unordered','created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ) );
	$log->debug("# of projects to delete: @Projects");
	foreach my $Project ( @Projects ) {
		$Project->delete();
	} # end foreach
	my @Projects = openprint::Project::find('status'=>'Deleted','created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -1 ) ) );
	$log->debug("# of projects to delete: @Projects");
	foreach my $Project ( @Projects ) {
		$Project->delete();
	} # end foreach
	sql::end_transaction( $dbh, $ac );

	$ac = sql::start_transaction( $dbh );
# Clean out unfinished Orders
	my @Orders = openprint::Order::find('status'=>'Incomplete','created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ) );
	$log->debug('Cleaning out ' . @Orders . ' incomplete orders');
	foreach my $Order ( @Orders ) {
		$Order->delete();
	} # end foreach
	sql::end_transaction( $dbh, $ac );

	$ac = sql::start_transaction( $dbh );
	my @Quotes = openprint::Quote::find('status'=>'Incomplete','created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ) );
	$log->debug('Cleaning out ' . @Quotes . ' incomplete quotes ');
	foreach my $Quote ( @Quotes ) {
		$Quote->delete();
	} # end foreach
	$ac = sql::start_transaction( $dbh );
	my @users = sql::execute( undef, undef, q{SELECT Index FROM Users WHERE CompanyIndex NOT IN (SELECT Index FROM Company)} );
	foreach my $user_id ( @users ) {
		new openprint::User( $user_id)->delete();
	} 
	sql::end_transaction( $dbh, $ac );
	$ac = sql::start_transaction( $dbh );
	my @companies = sql::execute( undef, undef, q{select index from company where (select count(users.index) from users where companyindex=Company.Index)=0} );
	foreach my $id ( @companies ) {
		new openprint::Company($id)->delete();
	} 
	sql::end_transaction( $dbh, $ac );
} # end if

$dbh->disconnect();

1;
__END__
