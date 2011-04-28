#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Location;
use countries;
use states;
use provinces;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
@session{'company_id','user_id'} = ( 6, 1085 );

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[1] if ! $ARGV[2];
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
die if ! $dbh;

for ( my $i = 0; $i < @countries::countries; $i += 2 ) {
	my $Country;
	if ( ! ( $Country = openprint::Location->find_one('name'=>$countries::countries[$i+1]) ) ) {
		$Country = new openprint::Location();
		$Country->save({'name'=>$countries::countries[$i+1], 'short'=>$countries::countries[$i], 'type'=>'country' });
	} else {
		if ( ! $Country->short() ) {
			$Country->save({'short'=>$countries::countries[$i]});
		} # end if
		if ( $Country->type() ne 'country' ) {
			$Country->save({'type'=>'country'});
		} # end if
	} # end if
} # end for

my $US = openprint::Location->find_one('short'=>'US');
die if ! $US;
foreach my $state ( keys %states::states ) {
	my $State;
	if ( ! ( $State = openprint::Location->find_one('short'=>$state,'type'=>'state' ) ) ) {
		$State = new openprint::Location();
		$State->save({'name'=>$states::states{$state}, 'short'=>$state, 'type'=>'state','parent_id'=>$US->id() });
	} else {
		if ( ! $State->name() ) {
			$State->save({'name'=>$states::states{$state} });
		} # end if
		if ( $State->parent_id() != $US->id() ) {
			$State->save({'parent_id'=>$US->id()});
		} # end if
	} # end if
} # end foreach state

my $CA = openprint::Location->find_one('short'=>'CA');
die if ! $CA;
foreach my $state ( keys %provinces::provinces ) {
	my $State;
	if ( ! ( $State = openprint::Location->find_one('short'=>$state,'type'=>'province' ) ) ) {
		$State = new openprint::Location();
		$State->save({'name'=>$provinces::provinces{$state}, 'short'=>$state, 'type'=>'province','parent_id'=>$CA->id() });
	} else {
		if ( ! $State->name() ) {
			$State->save({'name'=>$provinces::provinces{$state} });
		} # end if
		if ( $State->parent_id() != $CA->id() ) {
			$State->save({'parent_id'=>$CA->id()});
		} # end if
	} # end if
} # end foreach state


$dbh->disconnect();
1;
__END__
