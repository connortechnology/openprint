#!/usr/bin/perl 
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require ssi;
require logger;
require misc;
require configuration;
require openprint::Object;
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
	'host'		=> $ARGV[0],
	'database'	=> $ARGV[1],
	'driver'	=> 'Pg',
	'login'		=> $ARGV[2],
	'password'	=> $ARGV[3],
);
die 'Error opening db' if ! $dbh;
$openprint::Object::no_cache = 1;


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
	my @Projects = openprint::Project::find(
'status'=>'uncalculated',
'order'=>'index desc',
'created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ),
'updated_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ),
 );
	if ( @Projects ) {
		my $ac = sql::start_transaction( $dbh );
		$log->warn("# of uncalculated projects to delete: ".@Projects . ' ids ' . $Projects[0]->id() . ' to ' . $Projects[@Projects-1]->id() );
		foreach my $Project ( @Projects ) {
			if ( $Project->status() ne 'uncalculated' ) {
				$log->error('WTF! status was supposed to be uncalculated');
				next;
			} # end if
			if ( sql::execute( undef, undef, q{SELECT * FROM tbl_Quote_Details WHERE ProjectIndex=?}, $Project->id() ) ) {
				$log->error('Quoted!' . $Project->id());
				next;
			} # end if
			$Project->delete();
		} # end foreach
		sql::end_transaction( $dbh, $ac );
	} # end if

	@Projects = openprint::Project::find(
'status'=>'Unordered',
'order'=>'index desc',
'created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -365 ) ),
'updated_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -365 ) ),
 );
	if ( @Projects ) {
		$log->warn("# of Unordered projects to delete: ".@Projects . ' ids ' . $Projects[0]->id() . ' to ' . $Projects[@Projects-1]->id() );
		my $ac = sql::start_transaction( $dbh );
		foreach my $Project ( @Projects ) {
			if ( sql::execute( undef, undef, q{SELECT * FROM tbl_Quote_Details WHERE ProjectIndex=?}, $Project->id() ) ) {
				$log->debug('Quoted!' . $Project->id());
				next;
			} # end if
			if ( $Project->status() ne 'Unordered' ) {
				$log->error('WTF! Was supposed to be Unordered' . $Project->id());
				next;
			} # end if
			if ( $Project->order_id() ) {
				$log->error('WTF! Project has an order_id bu is Unordered');
				next;
			} # end if
			if ( $Project->docket() ) {
				$log->error('WTF! has docket, but is not ordered');
				next;
			} # end if
			$Project->delete();
		} # end foreach
		sql::end_transaction( $dbh, $ac );
	} # end if
	@Projects = openprint::Project::find(
'status'=>'Deleted','order'=>'index desc',
'created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -30 ) ),
'updated_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -30 ) ),
 );
	if ( @Projects ) {
		my $ac = sql::start_transaction( $dbh );
		$log->warn("# of Deleted projects to delete: ".@Projects . ' ids ' . $Projects[0]->id() . ' to ' . $Projects[@Projects-1]->id() );
		foreach my $Project ( @Projects ) {
			if ( $Project->status() ne 'Deleted' ) {
				$log->error('WTF!');
				next;
			} # end if
			if ( sql::execute( undef, undef, q{SELECT * FROM tbl_Quote_Details WHERE ProjectIndex=?}, $Project->id() ) ) {
				$log->debug('Quoted!' . $Project->id());
				next;
			} # end if
			$Project->delete();
		} # end foreach
		sql::end_transaction( $dbh, $ac );
	} # end if

	my $ac = sql::start_transaction( $dbh );
# Clean out unfinished Orders
	my @Orders = openprint::Order::find('status'=>'Incomplete','created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ) );
	$log->warn('Cleaning out ' . @Orders . ' incomplete orders');
	foreach my $Order ( @Orders ) {
		$Order->delete();
	} # end foreach
	sql::end_transaction( $dbh, $ac );

	$ac = sql::start_transaction( $dbh );
	my @Quotes = openprint::Quote::find('status'=>'Incomplete','created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ) );
	$log->warn('Cleaning out ' . @Quotes . ' incomplete quotes ');
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
	my @companies = sql::execute( undef, undef, q{SELECT index FROM company WHERE (SELECT count(users.index) FROM users WHERE companyindex=Company.Index)=0} );
	foreach my $id ( @companies ) {
		new openprint::Company($id)->delete();
	} 
	sql::end_transaction( $dbh, $ac );
} # end if

$dbh->disconnect();

1;
__END__
