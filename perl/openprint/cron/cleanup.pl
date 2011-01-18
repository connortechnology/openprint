#!/usr/bin/perl 
use lib '/etc/apache2/lib/perl';
use strict;
use warnings;

require sql;
require ssi;
require logger;
require misc;
require configuration;
require openprint::Object;
require openprint::Quote;
require openprint::Order;
require openprint::Project;
require openprint::PaperInventory;
require openprint::CIP3_PPF;
require openprint::Host;
require openprint::Log;
use Date::Calc;
use Apache::Session::Postgres;

use openprint ();
use vars qw($log $dbh %config);
*dbh = \$openprint::dbh;
*log = \$openprint::log;
*config = \%openprint::config;

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

configuration::init_cache( $log, $dbh );

# Clear out old sessions
my @session_ids = sql::execute( $log, $dbh, q{SELECT id FROM sessions} );
$log->warn("Cleaning out sessions: " . @session_ids . " sessionsn in system");
my $deleted_session_count = 0;
foreach my $session ( @session_ids ) {
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
		tied(%session)->delete;
		$deleted_session_count += 1;
    } elsif ( ( time - $session{'lastupdated'} > ( 60*60*24*1 ) ) and ! $session{'user_id'} ) {
		tied(%session)->delete;
		$deleted_session_count += 1;
	} else {
		undef %session;
	} # end if
} # end foreach
@session_ids = ();
$log->warn("Deleted $deleted_session_count sessions");

if ( 0 ) {
# Clean out uncalculated projects
	my @Projects = openprint::Project->find(
			'status'=>'uncalculated',
			'order'=>'id desc',
			'created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ),
			'updated_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ),
			'limit'		=>	100,
			);
	if ( @Projects ) {
		my $ac = sql::start_transaction( $dbh );
		$log->warn("# of uncalculated projects to delete: ".@Projects . ' ids ' . $Projects[0]->id() . ' to ' . $Projects[@Projects-1]->id() );
		foreach my $Project ( @Projects ) {
			if ( $Project->status() ne 'uncalculated' ) {
				$log->error('WTF! status was supposed to be uncalculated');
				next;
			} # end if
			if ( sql::execute( undef, undef, q{SELECT * FROM tbl_Quote_Details WHERE project_id=?}, $Project->id() ) ) {
				#$log->error('Quoted!' . $Project->id());
				next;
			} # end if
			next if $Project->order_id();
			next if $Project->docket();
			$Project->delete();
			last if $dbh->errstr();
		} # end foreach
		sql::end_transaction( $dbh, $ac );
	} # end if

	@Projects = openprint::Project->find(
			'status'=>'Unordered',
			'order'=>'id desc',
			'created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ),
			'updated_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ),
			'limit'		=>	100,
			);
	if ( @Projects ) {
		$log->warn("# of Unordered projects to delete: ".@Projects . ' ids ' . $Projects[0]->id() . ' to ' . $Projects[@Projects-1]->id() );
		my $ac = sql::start_transaction( $dbh );
		foreach my $Project ( @Projects ) {
			if ( sql::execute( undef, undef, q{SELECT * FROM tbl_Quote_Details WHERE project_id=?}, $Project->id() ) ) {
				#$log->debug('Quoted!' . $Project->id());
				next;
			} # end if
			if ( $Project->status() ne 'Unordered' ) {
				$log->error('WTF! Was supposed to be Unordered' . $Project->id());
				next;
			} # end if
			if ( $Project->order_id() ) {
				$log->error('WTF! Project has an order_id bu is Unordered'.$Project->id().') docket (' . $Project->docket() . ')');
				next;
			} # end if
			if ( $Project->docket() ) {
				$log->error('WTF! has docket, but is not ordered ('.$Project->id().') docket (' . $Project->docket() . ')');
				next;
			} # end if
			$Project->delete();
			last if $dbh->errstr();
		} # end foreach
		sql::end_transaction( $dbh, $ac );
	} # end if
	@Projects = openprint::Project->find(
			'status'=>'Deleted','order'=>'id desc',
			'created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ),
			'updated_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ),
			'limit'		=>	100,
			);
	if ( @Projects ) {
		my $ac = sql::start_transaction( $dbh );
		$log->warn("# of Deleted projects to delete: ".@Projects . ' ids ' . $Projects[0]->id() . ' to ' . $Projects[@Projects-1]->id() );
		foreach my $Project ( @Projects ) {
			if ( $Project->status() ne 'Deleted' ) {
				$log->error('WTF!');
				next;
			} # end if
			next if $Project->docket();
			if ( sql::execute( undef, undef, q{SELECT * FROM tbl_Quote_Details WHERE project_id=?}, $Project->id() ) ) {
				#$log->debug('Quoted!' . $Project->id());
				next;
			} # end if
			$Project->destroy();
			last if $dbh->errstr();
		} # end foreach
		sql::end_transaction( $dbh, $ac );
	} # end if Projects
} # end if 1
if ( 1 ) {
	# THis sucks RAM like a MOFO
		my @CIPS = openprint::CIP3_PPF->find('data_null'=>0,'limit'=>100);
		$log->warn(@CIPS . " cip files to clear the data from" );
		foreach my $CIP ( @CIPS ) {
			my @Projects = openprint::Project->find('docket'=>$CIP->docket());
			next if @Projects and ! sets::isin( $Projects[0]->status(), ['Complete','Waiting For Pickup','Shipped'] );
			$_ = $CIP->save({'data'=>undef,'data_length'=>0});
			$log->error($_) if $_;
		} # end foreach CIP
}

if ( 1 ) {
# Clean out unfinished Orders
	my @Orders = openprint::Order->find('status'=>'Incomplete','created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -180 ) ) );
	$log->warn('Cleaning out ' . @Orders . ' incomplete orders');
	foreach my $Order ( @Orders ) {
		$Order->delete();
	} # end foreach

	my @Quotes = openprint::Quote->find('status'=>'Incomplete','created_on_end' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -365 ) ) );
	$log->warn('Cleaning out ' . @Quotes . ' incomplete quotes ');
	foreach my $Quote ( @Quotes ) {
		$Quote->delete();
	} # end foreach
}

if ( 0 ) {
	my $ac = sql::start_transaction( $dbh );
	my @users = sql::execute( undef, undef, q{SELECT Index FROM Users WHERE CompanyIndex NOT IN (SELECT Index FROM Company)} );
	foreach my $user_id ( @users ) {
		new openprint::User( $user_id)->delete();
	} 
	sql::end_transaction( $dbh, $ac );
} # end if
if ( 0 ) {
	my $ac = sql::start_transaction( $dbh );
	my @companies = sql::execute( undef, undef, q{SELECT index FROM company WHERE (SELECT count(users.index) FROM users WHERE companyindex=Company.Index)=0} );
	foreach my $id ( @companies ) {
		new openprint::Company($id)->delete();
	} # end foreach empty company
	sql::end_transaction( $dbh, $ac );
} # end if

if ( 0 ) {
foreach my $Skid ( openprint::Skid->find() ) {

	my @Paper_Inventory = openprint::PaperInventory->find(
			#'updated_on_start'=>sprintf('%.4d-%.2d-%.2d 00:00:00', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -7 ) ),
			#'updated_on_end'=>sprintf('%.4d-%.2d-%.2d 23:59:59', Date::Calc::Today() ),
			'skid_id'=>$Skid->id(),
			'order'=>'updated_on',
	);
	$log->warn("Paper Inventory: " . @Paper_Inventory . ' entries');
	my $in_stock = 0;
	for ( my $i = 0; $i < @Paper_Inventory; $i += 1 ) {
		
		my $PI = $Paper_Inventory[$i];
		$in_stock += $PI->delta();
		$log->warn("Old instock: " . $PI->instock() . ' new instock: ' . $in_stock);
		$PI->instock( $in_stock );
		my $error = $PI->save();
		$log->error($error) if $error;
		if ( defined $PI->comment() and ($PI->comment() eq 'Skid checked out') ) {
			for ( my $j = $i+1; $j < @Paper_Inventory; $j += 1 ) {
				if ( ( $PI->skid_id() == $Paper_Inventory[$j]->skid_id() ) and ( $Paper_Inventory[$j]->comment() eq 'Skid checked out' ) ) {
					$Paper_Inventory[$j]->delete();
					splice @Paper_Inventory, $j, 1;
					$j -= 1;
				} # end if
			} # end for
		} elsif ( defined $PI->comment() and ($PI->comment() eq 'Removed' ) ) {
			for ( my $j = $i+1; $j < @Paper_Inventory; $j += 1 ) {
				if ( ( $PI->skid_id() == $Paper_Inventory[$j]->skid_id() ) and ( $Paper_Inventory[$j]->comment() eq 'Removed' ) and ! $Paper_Inventory[$j]->delta() ) {
					$Paper_Inventory[$j]->delete();
					splice @Paper_Inventory, $j, 1;
					$j -= 1;
				} # end if
			} # end for
		} # end if
	} # end for PI
} # end foreach Skid
	
}

if ( 0 ) {
	require openprint::PaperInventory;
	foreach my $PI ( openprint::PaperInventory->find('comment_like'=>'Removed%' ) ) {
		$PI->comment() =~ /Removed (.*)/;
		$PI->comment( "Checked out $1" );
		$PI->save();
	} # end foreach
	foreach my $PI ( openprint::PaperInventory->find('comment_like'=>'Skid checked%' ) ) {
		$PI->comment() =~ /Skid checked (.*)/;
		$PI->comment( "Checked $1" );
		$PI->save();
	} # end foreach
} # end if 1

if ( ( exists $config{'RFID'} ) and $config{'RFID'} ) {
	require openprint::RFIDTag;
	require openprint::RFIDTagHistory;
	require openprint::RFIDScannerHistory;
	my @Hs = openprint::RFIDScannerHistory->find(
			'updated_on_<'=>sprintf('%.4d-%.2d-%.2d 23:59:59', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -31 ) ),
			'updated_on_>'=>sprintf('%.4d-%.2d-%.2d 23:59:59', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -62 ) ),
			);
	$log->warn( "Scanner History Entries: " . @Hs );
	foreach my $H ( @Hs ) {
		$H->delete();
	} # end foreach H
	@Hs = openprint::RFIDTagHistory->find(
			'updated_on_<'=>sprintf('%.4d-%.2d-%.2d 23:59:59', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -31 ) ),
			'updated_on_>'=>sprintf('%.4d-%.2d-%.2d 23:59:59', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -62 ) ),
			);
	$log->warn( "Tag History Entries: " . @Hs );
	foreach my $H ( @Hs ) {
		$H->delete();
	} # end foreach H
	my @old_unassigned_tags = openprint::RFIDTag->find(
			'updated_on_<'=>sprintf('%.4d-%.2d-%.2d 23:59:59', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -60 ) ),
			'type'			=>	'Skid',
			);
	$log->warn( "Tag History Entries (unassigned and old): " . @old_unassigned_tags );
	foreach my $H ( @old_unassigned_tags ) {
		next if $H->skid_id();
		$H->delete();
	} # end foreach H
} # end if

# Resolve any unresolved IP's
foreach my $Host ( openprint::Host->find('hostname'=>undef) ) {
	$Host->resolve() if $Host->ip();
	$Host->save() if $Host->hostname();
} # end foreach

# Paper maintenance
foreach my $Paper ( openprint::Paper->find() ) {
	if ( ! $Paper->wpsi() != $Paper->wpsi(undef) ) {
		$Paper->save();
	} # end if
} # end foreach my Paper
my $log_count = 0;
foreach my $Log ( openprint::Log->find('date_time_<'=>sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -365 ) ) ) ) {
	$Log->delete();
	$log_count += 1;
} # end foreach Log
$log->warn("Deleted $log_count log entries");

$dbh->disconnect();
1;
__END__
