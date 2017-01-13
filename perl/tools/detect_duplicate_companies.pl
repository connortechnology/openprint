#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use utf8;
use strict;
use Encode;

require sql;
require logger;
require openprint::Object;
require openprint::Company;
require openprint::User;
require openprint::Project;
require openprint::Quote;
require openprint::Order;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
my %company_names;
$log->warn("Checking for accented names");
foreach my $C ( openprint::Company->find() ) {
	my $unaccented = Encode::encode('utf-8',Text::Unaccent::unac_string('LATIN1', $C->name() ) );
	if ( $unaccented ne $C->name() ) {
$log->error('Unaccenting ' . $C->name() . ' to ' . $unaccented );
		#$C->name( $unaccented );
		#$C->save();
	} # end i
	$company_names{$C->name()} = $C->postalcode();
#$log->error('Company ' . $C::name() . ' to ' . $unaccented );
} # end foreach C

foreach my $name ( sort keys %company_names ) {
	#next if ! $name;
	my @dups = openprint::Company->find('name'=>$name,'postalcode'=>$company_names{$name} );
	if ( @dups > 1 ) {
		$log->error('Duplicate company found: (' . $name . ') ' . @dups . ' dups found' );
		my $count = 1;
		foreach my $C ( @dups ) {
			my @users = openprint::User->find('company_id'=>$C->id());
			my @projects = openprint::Project->find('company_id'=>$C->id());
			my @orders = openprint::Order->find('company_id'=>$C->id());
			my @quotes = openprint::Quote->find('company_id'=>$C->id());
			if ( (@projects < 5 ) and (@orders == 0 ) and (@quotes == 0) ) {
				$log->error('Deleting');
				#$C->delete();
				next;
			} # end if
			$log->error("COMPANY #".$C->id() . ' ' . $C->name() . " Projects: " . scalar @projects . " Quotes: " . scalar @quotes . ' Orders: ' . scalar @orders . " Users in dup #$count");
			foreach my $U ( @users ) {
				$log->error( join(' ', $U->name(), $U->email(), $U->phone(), $U->extension() ) );
			} # end foreach
			$count += 1;
		} # end foreach
	} # end if
	
} # end foreach Company
$dbh->disconnect();
1;
__END__
