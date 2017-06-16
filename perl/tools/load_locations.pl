#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Location;
require openprint::Company;
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
$dbh = sql::open_sql( $log, (database=>$ARGV[0], driver=>'Pg',login=>$ARGV[1], password=>$ARGV[2], host=>$ARGV[3]) );
die if ! $dbh;

my $interactive = 0;

if ( 0 ) {
for ( my $i = 0; $i < @countries::countries; $i += 2 ) {
	my $Country;
	$countries::countries[$i+1] = Encode::encode('utf-8',  $countries::countries[$i+1] );
	if ( ! ( $Country = openprint::Location->find_one(name=>$countries::countries[$i+1], type=>'country') ) ) {
		$log->debug("Adding country " . $countries::countries[$i+1] );
		<STDIN>;
		$Country = new openprint::Location();
		$_ = $Country->save({name=>$countries::countries[$i+1], short=>$countries::countries[$i], type=>'country' });
		die $_ if $_;
	} else {
		if ( ! $Country->short() ) {
		$log->debug("setting short country " . $countries::countries[$i+1] );
		<STDIN>;
			$_ = $Country->save({short=>$countries::countries[$i]});
		die $_ if $_;
		} # end if
		if ( $Country->type() ne 'country' ) {
		$log->debug("mkaing into country " . $countries::countries[$i+1] );
		<STDIN>;
			$_ = $Country->save({type=>'country'});
		die $_ if $_;
		} # end if
	} # end if
} # end for

my $US = openprint::Location->find_one(short=>'US');
die if ! $US;
foreach my $state ( keys %states::states ) {
	my $State;
	$state = Encode::encode('utf-8',  $state );
	if ( ! ( $State = openprint::Location->find_one(short=>$state,type=>'state' ) ) ) {
		if ( ! ( $State = openprint::Location->find_one(name=>Encode::encode('utf-8', $states::states{$state} ), type=>'state' ) ) ) {
			$log->debug("Adding state " . $state );
			<STDIN>;
			$State = new openprint::Location();
			$_ = $State->save({name=>Encode::encode('utf-8', $states::states{$state} ), short=>$state, type=>'state', parent_id=>$US->id() });
			die $_ if $_;
		} else {
			$State->save({short=>$state});
		}
	} else {
		if ( ! $State->name() ) {
		$log->debug("Adding state " . $states::states{$state} );
		<STDIN>;
			$_ = $State->save({name=>Encode::encode('utf-8', $states::states{$state} )});
		die $_ if $_;
		} # end if
		if ( $State->parent_id() != $US->id() ) {
			$_ = $State->save({parent_id=>$US->id()});
		die $_ if $_;
		} # end if
	} # end if
} # end foreach state

my $CA = openprint::Location->find_one(short=>'CA', name=>'Canada');
die if ! $CA;
foreach my $state ( keys %provinces::provinces ) {
	my $State;
	$state = Encode::encode('utf-8',  $state );
	if ( ! ( $State = openprint::Location->find_one(short=>$state,type=>'state' ) ) ) {
		$log->debug("Adding province " . $state . ' => ' . $provinces::provinces{$state} );
		<STDIN>;
		$State = new openprint::Location();
		$_ = $State->save({name=>Encode::encode('utf-8', $provinces::provinces{$state}), short=>$state, type=>'state',parent_id=>$CA->id() });
		die $_ if $_;
	} else {
		if ( ! $State->name() ) {
		$log->debug("Updating province $state => " . $provinces::provinces{$state} );
		<STDIN>;
			$_ = $State->save({name=>Encode::encode('utf-8', $provinces::provinces{$state}) });
		die $_ if $_;
		} # end if
		if ( $State->parent_id() != $CA->id() ) {
			$_ = $State->save({parent_id=>$CA->id()});
		die $_ if $_;
		} # end if
	} # end if
} # end foreach state
} # end if

foreach my $Company ( openprint::Company->find( 'last_order_id is null'=>0, 'address1 !='=>'' ) ) {
	$log->debug("Doing location for $$Company{name} $$Company{address1} $$Company{address2}");
	# Assume Country and State already exist. Start with city
	my $Country = openprint::Location->find_one( type=>'country', short=>$$Company{country} );
	die "No country for $$Company{country}" if ! $Country;
	my $State = openprint::Location->find_one( type=>'state', short=>$$Company{state} );
	die "No state for $$Company{state}" if ! $State;
	my $City = openprint::Location->find_one( type=>'city', name=>$$Company{city} );
	if ( ! $City ) {
		$City = new openprint::Location();
		$City->save({
			parent_id	=>	$$State{id},
		});
	}
	my @Locations = openprint::Location->find( company_id=>$$Company{id}, type=>'place' );
	print "Company $$Company{name} has " . @Locations . " locations. They are as follows:\n".join("\n", map { $_->to_string() } @Locations ) . "\n\n";
	my $Location = openprint::Location->find_one( company_id=>$$Company{id}, type=>'place',
			address=>join( "\n",
				( $$Company{address1} ? $$Company{address1} : () ), 
				( $$Company{address2} ? $$Company{address2} : () ) )
		);
	if ( ! $Location ) {
		$Location = new openprint::Location();
		$Location->set({
			name=>join(', ', $$Company{address1}, $$Company{state} ),
			address=>join( "\n",
				( $$Company{address1} ? $$Company{address1} : () ), 
				( $$Company{address2} ? $$Company{address2} : () ) ),
			type=>'place',
			parent_id=>$$City{id},
			postalcode	=>$$Company{postalcode},
			company_id	=>	$$Company{id},
			});
if ( $interactive ) {
		print "Should I add a location for " . $Location->to_string() . " ? (Y|n)\n";
		$_ = <STDIN>;
		chomp;
		next if ( $_ and ! ( $_ =~ /^y/i ) );
}
		$_ = $Location->save();	
		die $_ if $_;
	}
} # end foreach Company


$dbh->disconnect();
1;
__END__
