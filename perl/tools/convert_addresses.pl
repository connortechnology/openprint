#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Location;
require openprint::Address;
require openprint::Company;
require openprint::User;
require Encode;
use countries;
use states;
use provinces;
require misc;

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

my @tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
$dbh->do('ALTER TABLE Addresses RENAME To addr') if ! sets::isin( 'addr', \@tables );;
@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
#if ( sets::isin( 'addresses', \@tables ) ) {
	#$log->debug("DROPPING ADDESS");
	#$dbh->do('DROP TABLE Addresses');
	#die $dbh->errstr() if $dbh->errstr();
#} else {
	#$log->debug('NOT DROP TABLE Addresses');
#} # end if
#$dbh->do(misc::load_file($log,'../openprint/sql/Addresses.sql'));
#die $dbh->err_str if $dbh->errstr();
@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
die "No addr table\n" if ! sets::isin( 'addr', \@tables );
$dbh->do('ALTER TABLE rma ADD shipping_address_id INTEGER');
$dbh->do('ALTER TABLE rma ADD FOREIGN KEY (shipping_address_id) REFERENCES addresses (id)');

my $data = $dbh->selectall_arrayref( 'SELECT * FROM addr', { Slice => {} } );
foreach my $addr ( @$data ) {
	$$addr{name} =~ s/\.+$//;
	$$addr{name} =~ s/,//;
	$$addr{name} =~ s/CO\./CO/;
	$$addr{name} =~ s/MT\./MT/;
	my $Company = openprint::Company->find_one('name lc'=>lc openprint::Company->transform('name',$$addr{name}));
	if ( ! $Company ) {
		$Company = new openprint::Company();
		$_  = $Company->save({
				name=>$$addr{name},
				business_name	=>	$$addr{name},
				phone	=>	$$addr{phone},
		});
		die $_ if $_;
	} # end if
	my $Contact;
	if ( $$addr{contact} ) {
		my ( $sal, $first, $last, $extra ) = $$addr{contact} =~ /^(Mr|Mrs|Ms|Miss)\.?\s+(\S+)\s+(\S+)(.*)$/i;
#$log->debug("contact: $$addr{contact} Sal: $sal, first: $first, last: $last, extra: $extra");
		if ( $extra ) {
			$Contact = openprint::User->find_one('name lc'=>lc openprint::User->transform('firstname',$$addr{contact}) );
		} else {
			$Contact = openprint::User->find_one(
					'firstname lc' => lc openprint::User->transform('firstname', $first),
					'lastname lc' => lc openprint::User->transform('lastname', $last),
		
					);
			if ( ! $Contact ) {
				$Contact = new openprint::User();
				$_ = $Contact->save({
						company_id	=>	$Company->id(),
						phone	=>	$$addr{phone},
					( $extra ? (
								firstname	=>	$first . ' '. $last . ' ' . $extra,
							   ) : (
						firstname	=>	$first,
						lastname	=>	$last,
						) ),
						salutation	=>	$sal,
						});
				die $_ if $_;
			} # end if
		} # end if
	} # end if
	my $Country;
	if ( $$addr{country} ) {
		$Country = openprint::Location->find_one('name lc'=> lc openprint::Location->transform('name', $$addr{country}),type=>'country');
		if ( ! $Country ) {
			$Country = new openprint::Location();
			$_ = $Country->save({name=>$$addr{country}, type=>'country'});
			die $_ if $_;
		} # end 
	} # end 
	my $State;
	if ( $$addr{state} ) {
		$State = openprint::Location->find_one('name lc'=> lc openprint::Location->transform('name', $$addr{state},type=>($Country and $$Country{name} eq 'Canada' ? 'province' : 'state')));
		$State = openprint::Location->find_one('short lc'=> lc openprint::Location->transform('short', $$addr{state},type=>($Country and $$Country{name} eq 'Canada' ? 'province' : 'state'))) if ! $State;
		if ( ! $State ) {
			$State = new openprint::Location();
			$_ = $State->save({name=>$$addr{state}, 
				type	=>	( ($Country and $$Country{name} eq 'Canada' ) ? 'province' : 'state'),
				( $Country ? ( parent_id=>$Country->id() ) : () ),
					});
				die $_ if $_;
		} # end 
	} # end 
	my $City;
	if ( $$addr{city} ) {
		$City = openprint::Location->find_one('name lc'=> lc openprint::Location->transform('name', $$addr{city}),type=>'city');
		if ( ! $City ) {
			$City = new openprint::Location();
			$_ = $City->save({name=>$$addr{city},
				type=>'city',
			( $State ? ( parent_id => $State->id() ) : () ),
					});
				die $_ if $_;
		} # end 
	} # end 

	my $Location;
	if ( $$addr{address1} ) {
		$Location = openprint::Location->find_one( 'address lc'=> lc openprint::Location->transform('address', $$addr{address1}), type=>'place' );
	} elsif ( $$addr{postalcode} ) {
		$Location = openprint::Location->find_one( 'postalcode lc'=> lc openprint::Location->transform('postalcode', $$addr{postalcode}), type=>'place' );
	} else {
		print "No location.\n";
		next;
	} # end if
	if ( ! $Location ) {
		$Location = new openprint::Location();
		$_ = $Location->save({
			( $City ? ( parent_id=>$City->id() ) : () ),
			name	=>	$Company->name(),
			address	=>	$$addr{address1},
			postalcode	=>	$$addr{postalcode},
			type		=>	'place',
		});
				die $_ if $_;
	} # end if
	my $Address = openprint::Address->find_one(company_id	=>$Company->id(), location_id=>$Location->id(),
			( $Contact ? ( user_id	=>	$Contact->id() ) : () ),
			);
	if ( ! $Address ) {
		$Address = new openprint::Address;
		$_ = $Address->save({
			company_id	=>	$Company->id(),
			( $Contact ? ( user_id		=>	$Contact->id() ) : () ),
			location_id	=>	$Location->id(),
			notes		=>	$$addr{notes},
		});	
				die $_ if $_;
	} # end if
	sql::update(undef,undef, 'rma', [ 'shipto_address_id=?', $$addr{id} ], 'shipping_address_id', $Address->id(), 'shipto_address_id', undef );
 
} # end foreach addr
$dbh->do('ALTER TABLE rma DROP shipto_address_id');
$dbh->do('DROP TABLE addr');


$dbh->disconnect();
1;
__END__
