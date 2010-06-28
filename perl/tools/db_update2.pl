#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Paper;
require openprint::PaperPrice;
require openprint::Equipment;
require openprint::EquipmentSpecification;
require openprint::ServicePrice;
require openprint::ServiceType;
require openprint::Service;
require openprint::ServiceCategory;
require openprint::Project;
require openprint::service;
require openprint::Material;
require openprint::MaterialCategory;
require openprint::PaperInventory;
require openprint::Log;
require openprint::Host;
require openprint::Invoice;

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

if ( ! sets::isin( 'quote_log', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Quote_Log.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

if ( sets::isin( 'quotes', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM quotes LIMIT 1', {} );
	if ( $data ) {
		$dbh->do('ALTER TABLE quotes add reference text') if ! exists $$data{'reference'};
		$dbh->do('ALTER TABLE quotes add comments text') if ! exists $$data{'comments'};
		$dbh->do('ALTER TABLE quotes add deleted boolean default false') if ! exists $$data{'deleted'};
	} # end if
} # end if
if ( sets::isin( 'pricelists', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM pricelists LIMIT 1', {} );
	if ( $data ) {
		$dbh->do('ALTER TABLE pricelists add deleted boolean default false') if ! exists $$data{'deleted'};
	} # end if
} # end if
if ( sets::isin( 'invoiced_products', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM invoiced_products LIMIT 1', {} );
	if ( $data ) {
		$dbh->do('ALTER TABLE invoiced_products add po text') if ! exists $$data{'po'};
	} # end if
} # end if
if ( sets::isin( 'hosts', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM hosts LIMIT 1', {} );
	if ( $data ) {
		$dbh->do('ALTER TABLE hosts add block boolean') if ! exists $$data{'block'};
		$dbh->do('ALTER TABLE hosts add monitor boolean') if ! exists $$data{'monitor'};
	} # end if
} # end if

foreach my $Invoice ( openprint::Invoice->find() ) {
} # end foreach Invoice

if ( sets::isin( 'taxes', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM taxes LIMIT 1', {} );
	if ( $data ) {
		if ( ! exists $$data{'name'} ) {
			$dbh->do('ALTER TABLE taxes add name text');
		} # end if
		if ( ! exists $$data{'rate'} ) {
			$dbh->do('ALTER TABLE taxes add rate float');
			$dbh->do('UPDATE Taxes set rate=federaltax where federaltax IS NOT NULL');
			$dbh->do('UPDATE Taxes set rate=statetax where statetax IS NOT NULL');
		} # end if
		if ( ! exists $$data{'period_start'} ) {
			$dbh->do('ALTER TABLE taxes add period_start date');
		} # end if
		if ( ! exists $$data{'period_end'} ) {
			$dbh->do('ALTER TABLE taxes add period_end date');
		} # end if
		if ( exists $$data{'federaltax'} ) {
			$dbh->do('ALTER TABLE taxes DROP column federaltax');
		}
		if ( exists $$data{'statetax'} ) {
			$dbh->do('ALTER TABLE taxes DROP column statetax');
		}
		if ( exists $$data{'harmonisedtax'} ) {
			$dbh->do('ALTER TABLE taxes DROP column harmonisedtax');
		}
	} # end if data
} # end if
$dbh->commit();
$dbh->disconnect();
1;
__END__
