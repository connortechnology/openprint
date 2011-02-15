#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require misc;
require logger;
require configuration;
require openprint::Object;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

$openprint::Object::no_cache = 1;

$log = new logger( 'debug' );

$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[0] if ! $ARGV[2];

$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
configuration::init_cache( $log, $dbh );

my @tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
my @sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);

my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='articles'", 'column_name');
if ( ! exists $$data{'source'} ) {
		$dbh->do('ALTER TABLE articles ADD source TEXT');
} # end if
if ( ! exists $$data{'source_content'} ) {
		$dbh->do('ALTER TABLE articles ADD source_content TEXT');
} # end if
if ( ! exists $$data{'category_id'} ) {
		$dbh->do('ALTER TABLE articles ADD category_id INTEGER');
} # end if
if ( sets::isin( 'article_categories', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='article_categories'", 'column_name');
	if ( ! exists $$data{'image_filename'} ) {
		$dbh->do('ALTER TABLE article_categories ADD image_filename TEXT');
	} # end if
	if ( ! exists $$data{'description'} ) {
		$dbh->do('ALTER TABLE article_categories ADD description TEXT');
	} # end if
} else {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Article_Categories.sql' ) );
}
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='users'", 'column_name');
if ( ! exists $$data{'asset_id'} ) {
	$dbh->do('ALTER TABLE users add asset_id INTEGER');
} # end if
if ( ! sets::isin( 'assets', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Assets.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} # end if

if ( ! sets::isin( 'expense_accounts', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Expense_Accounts.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
}
if ( ! sets::isin( 'expenses', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Expenses.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
}

my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='expenses'", 'column_name');
if ( ! exists $$data{'amount_locked'} ) {
	$dbh->do('ALTER TABLE expenses add amount_locked BOOLEAN NOT NULL default false');
}
if ( ! exists $$data{'total_locked'} ) {
	$dbh->do('ALTER TABLE expenses add total_locked BOOLEAN NOT NULL default false');
}
if ( ! exists $$data{'account_id'} ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Expense_Accounts.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
	$dbh->do('ALTER TABLE expenses add account_id INTEGER');
	$dbh->do('ALTER TABLE expenses add FOREIGN KEY (account_id) REFERENCES Expense_Accounts (id)');
}

my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='hosts'", 'column_name');
if ( ! exists $$data{'count'} ) {
	$dbh->do('ALTER TABLE hosts add count integer');
	$dbh->do('UPDATE hosts set count=(SELECT count FROM blacklist WHERE blacklist.ip=hosts.ip)');
}
if ( ! exists $$data{'blacklist'} ) {
	$dbh->do('ALTER TABLE hosts add blacklist BOOLEAN NOT NULL default false');
} # end if
if ( ! exists $$data{'whitelist'} ) {
	$dbh->do('ALTER TABLE hosts add whitelist BOOLEAN NOT NULL default false');
} # end if
if ( ! exists $$data{'created_on'} ) {
	$dbh->do('ALTER TABLE hosts add created_on TIMESTAMP WITH TIME ZONE NOT NULL default NOW()');
} # end if
if ( ! exists $$data{'updated_on'} ) {
	$dbh->do('ALTER TABLE hosts add updated_on TIMESTAMP WITH TIME ZONE NOT NULL default NOW()');
} # end if

my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='paper_prices'", 'column_name');
if ( ! exists $$data{'equipment_id'} ) {
	$dbh->do('ALTER TABLE paper_prices add equipment_id INTEGER');
	$dbh->do('ALTER TABLE paper_prices add FOREIGN KEY(equipment_id) REFERENCES tbl_Equipment (id)');
} # end if
if ( ! exists $$data{'service'} ) {
	$dbh->do('ALTER TABLE paper_prices ADD service TEXT');
	$dbh->do("UPDATE paper_prices set service='Material'" );
} # end if

if ( ! sets::isin( 'user_profile_fields', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/User_Profile_Fields.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'user_profiles', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/User_Profiles.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'company_profile_fields', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Company_Profile_Fields.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'company_profiles', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Company_Profiles.sql' ) );
	die $dbh->errstr() if $dbh->errstr();
} # end if
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='shifts'", 'column_name');
if ( ! exists $$data{'updated_on'} ) {
	$dbh->do('ALTER TABLE shifts add updated_on TIMESTAMP WITH TIME ZONE NOT NULL default nOW()');
} # end if
if ( ! exists $$data{'created_on'} ) {
	$dbh->do('ALTER TABLE shifts add created_on TIMESTAMP WITH TIME ZONE NOT NULL default nOW()');
} # end if
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_equipment'", 'column_name');
if ( ! exists $$data{'sorting'} ) {
	$dbh->do('ALTER TABLE tbl_equipment ADD sorting integer');
} # end if
if ( ! exists $$data{'message'} ) {
	$dbh->do('ALTER TABLE tbl_equipment ADD message text');
} # end if
if ( ! exists $$data{'servicetype_id'} ) {
	$dbh->do('ALTER TABLE tbl_equipment ADD servicetype_id INTEGER[]');
} # end if
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='equipment_shifts'", 'column_name');
if ( ! exists $$data{'operator_id'} ) {
	$dbh->do('ALTER TABLE equipment_shifts ADD operator_id INTEGER');
	$dbh->do('ALTER TABLE equipment_shifts ADD FOREIGN KEY (operator_id) REFERENCES Users (id)');
} # end if
if ( ! sets::isin( 'par', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/PAR.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'cars', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/CAR.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'event_categories', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Event_Categories.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if
if ( ! sets::isin( 'events', \@tables ) ) {
    $dbh->do( misc::load_file( $log, '../openprint/sql/Events.sql' ) );
    die $dbh->errstr() if $dbh->errstr();
} # end if

$dbh->disconnect();
1;
__END__
