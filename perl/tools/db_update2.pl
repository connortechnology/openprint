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

foreach my $Invoice ( openprint::Invoice::find() ) {
} # end foreach Invoice

$dbh->commit();
$dbh->disconnect();
1;
__END__
