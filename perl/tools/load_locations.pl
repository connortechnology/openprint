#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Location;
require Encode;
use countries;
use states;
use provinces;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[1] if ! $ARGV[2];
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
die if ! $dbh;

for ( my $i = 0; $i < @countries::countries; $i += 2 ) {
	my $Country;
	$countries::countries[$i+1] = Encode::encode('utf-8',  $countries::countries[$i+1] );
	if ( ! ( $Country = openprint::Location->find_one('name'=>$countries::countries[$i+1]) ) ) {
		$Country = new openprint::Location();
		$_ = $Country->save({'name'=>$countries::countries[$i+1], 'short'=>$countries::countries[$i], 'type'=>'country' });
		die $_ if $_;
	} else {
		if ( ! $Country->short() ) {
			$_ = $Country->save({'short'=>$countries::countries[$i]});
		die $_ if $_;
		} # end if
		if ( $Country->type() ne 'country' ) {
			$_ = $Country->save({'type'=>'country'});
		die $_ if $_;
		} # end if
	} # end if
} # end for

my $US = openprint::Location->find_one('short'=>'US');
die if ! $US;
foreach my $state ( keys %states::states ) {
	my $State;
	$state = Encode::encode('utf-8',  $state );
	if ( ! ( $State = openprint::Location->find_one('short'=>$state,'type'=>'state' ) ) ) {
		$State = new openprint::Location();
		$_ = $State->save({'name'=>Encode::encode('utf-8', $states::states{$state} ), 'short'=>$state, 'type'=>'state','parent_id'=>$US->id() });
		die $_ if $_;
	} else {
		if ( ! $State->name() ) {
			$_ = $State->save({'name'=>Encode::encode('utf-8', $states::states{$state} )});
		die $_ if $_;
		} # end if
		if ( $State->parent_id() != $US->id() ) {
			$_ = $State->save({'parent_id'=>$US->id()});
		die $_ if $_;
		} # end if
	} # end if
} # end foreach state

my $CA = openprint::Location->find_one('short'=>'CA');
die if ! $CA;
foreach my $state ( keys %provinces::provinces ) {
	my $State;
	$state = Encode::encode('utf-8',  $state );
	if ( ! ( $State = openprint::Location->find_one('short'=>$state,'type'=>'province' ) ) ) {
		$State = new openprint::Location();
		$_ = $State->save({'name'=>Encode::encode('utf-8', $provinces::provinces{$state}), 'short'=>$state, 'type'=>'province','parent_id'=>$CA->id() });
		die $_ if $_;
	} else {
		if ( ! $State->name() ) {
			$_ = $State->save({'name'=>Encode::encode('utf-8', $provinces::provinces{$state}) });
		die $_ if $_;
		} # end if
		if ( $State->parent_id() != $CA->id() ) {
			$_ = $State->save({'parent_id'=>$CA->id()});
		die $_ if $_;
		} # end if
	} # end if
} # end foreach state


$dbh->disconnect();
1;
__END__
