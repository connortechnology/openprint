use strict;
use warnings;
package openprint;
use vars qw( $r %variable %session %param %config $log $dbh $User $Company $TZ $Owner $Pricelist $Currency );


sub session_init {
	require Apache2::Cookie;
	require Apache::Session::Postgres;
	require openprint::Pricelist;
	require openprint::Currency;
	require DateTime::TimeZone;
 
	if ( ! $openprint::config{Timezone} ) {
		$log->error("You must configure a time zone.  Defaulting to America/Toronto");
		$openprint::config{Timezone} = 'America/Toronto';
	} # end if
	$TZ = DateTime::TimeZone->new( name => $openprint::config{Timezone} );

	my $cookies;
	my $cookie;
	if ( $r ) {
		$cookies = Apache2::Cookie->fetch( $r );
		if ( $$cookies{_session_id} ) {
			$cookie = $$cookies{_session_id};
			$cookie = $cookie->value if $cookie;
		} else {
			if ( $r->param('_session_id') ) {
				$log->error("Since when is session_id in the params");
				$cookie = $r->param('_session_id');
			} # end if
		} # end if

		if ( $dbh ) {
			# If we have no cookie, then... shouldn't try to load it...
			if ( ! eval q`tie %session, 'Apache::Session::Postgres', $cookie, { Handle => $dbh, Commit => 0, IDLength => 8 }` ) {
				$log->error("Error fetching Session: $cookie: $@");
				if ( ! eval q`tie %session, 'Apache::Session::Postgres', undef, { Handle		=> $dbh, Commit		=> 0, IDLength	=> 8, };` ) {
					$log->error("Error creating Session: ");
				} # end if
				if ( $r->param('_session_id') ) {
					if ( $session{ip} ne $ENV{REMOTE_ADDR} ) {
						$log->error("Change of session ip");
						untie %session;
						%session = ();
					} # end if
				} # end if
				# Store this, will be useful
				$session{ip} = $ENV{REMOTE_ADDR};
				$session{lastupdated} = time;
				$session{HTTP_USER_AGENT} = $ENV{HTTP_USER_AGENT};
			} # end if

			if ( (!$cookie) or ( $cookie ne $session{_session_id} ) ) {
				my $Cookie = Apache2::Cookie->new($r,
						-name	=> '_session_id',
						-value => $session{_session_id},
						-path		=>	'/',
						);
				if ( $Cookie ) {
					$Cookie->bake( $r );
					$cookie = $Cookie->value;
				} else {
					$log->error("No Cookie.  Does db have a sessions table?");
				} # end if
			} # end if
		} else {
			%session = ();
		} # end if
	} # end if $r

	$session{ip} = $ENV{REMOTE_ADDR} if $ENV{REMOTE_ADDR} and ! $session{ip};

# Now set some defaults right away, if we can, FIXME namespace colision
	if ( $param{Country} ) {
		$session{Country} = $param{Country};
	} elsif ( ! $session{Country} ) {
		$session{Country} = $config{Country};
	} # end if

	return if ! $dbh;

	if ( $param{btnFunction} and sets::isin( $session{user_type}, ['E','A'] ) ) {
		if ( $param{btnFunction} eq 'SelectCompany' ) {
			if ( $param{ddmCompany} != $session{company_id} ) {
				my $C = new openprint::Company( $param{ddmCompany} );
				if ( ! $C->id() ) {
					$variable{error} .= 'Unknown company selected.  Please try again.';
				} else {
					switch_company( $C );
				} # end if
			} # end if
		} elsif ( $param{btnFunction} eq 'SelectPricelist' ) {
			my $Pricelist = new openprint::Pricelist( $param{pricelist_id} );
			if ( ! $Pricelist->id() ) {
				$Pricelist = openprint::Pricelist::get_current();
			} # end if
			$session{Pricelist_id} = $Pricelist->id() if $Pricelist->id();
		} # end if
	} # end if

	if ( $param{Currency} ) {
		my $short = $param{Currency};
		$short = substr( $short, 0, 3 );
		$_ = openprint::Currency->find_one( short => $short );
		$session{Currency_id} = $_->id() if $_;
	} elsif ( $param{select_currency_id} ) {
		$param{select_currency_id} = openprint::Currency->transform( id=>$param{select_currency_id} );
		if ( $param{select_currency_id} ) {
			my $Currency = new openprint::Currency( $param{select_currency_id} );
			$session{Currency_id} = $Currency->id();
		} # end if
	}
	if ( ! $session{Currency_id} ) {
		$_ = openprint::Currency->find_one( short => $config{Currency} );
		$session{Currency_id} = $_->id() if $_;
	} # end if

	$User = new openprint::User( $session{user_id} );
	$Company = new openprint::Company( $session{company_id} );
	$Owner = new openprint::Company( $config{owner_id} );
	$Currency = new openprint::Currency( $session{Currency_id} );

	if ( $config{Pricelist} ) {
		if ( ! $session{Pricelist_id} ) {
			$_ = openprint::Pricelist->find_one( name => $config{Pricelist} );
			$session{Pricelist_id} = $_->id() if $_;
		} # end if
	} # end if

	if ( ! $session{Pricelist_id} ) {
		my $Pricelist = openprint::Pricelist::get_current();
		$session{Pricelist_id} = $Pricelist->id() if $Pricelist->id();
	} else {
		my $Pricelist = new openprint::Pricelist( $session{Pricelist_id} );
		if ( ! $Pricelist->id() ) {
			$Pricelist = openprint::Pricelist::get_current();
			$session{Pricelist_id} = $Pricelist->id() if $Pricelist->id();
		} # end if
	} # end if
	$Pricelist = new openprint::Pricelist( $session{Pricelist_id} ) if $session{Pricelist_id};

} # end sub session_init

sub switch_company {
	my ( $Company ) = @_;
	$session{company_id} = $Company->id();
	$openprint::Company = $Company;
	(new openprint::Log())->save({action=>'Switch Company', Object=>$openprint::Company});

	if ( $Company->currency_id() ) {
		$session{Currency_id} = $Company->currency_id();
	} elsif ( $Company->country() eq 'US' ) {
		$_ = openprint::Currency->find_one('short'=>'USD');
		$session{Currency_id} = $_->id() if $_;
	} elsif ( $Company->country() eq 'CA' ) {
		$_ = openprint::Currency->find_one('short'=>'CAD');
		$session{Currency_id} = $_->id() if $_;
	} # end if
	require openprint::Order;
	foreach my $Order ( openprint::Order->find(session_id=>$session{_session_id} ) ) {
		$Order->save({session_id => undef });
	} # end foreach Order
	my @keys = sets::exclude( [ 'Currency_id', '_session_id','user_id','company_id','user_type','Country' ], [ keys %session ] );
	delete @session{@keys};
} # end sub switch_company

sub index {
} # end sub index

1;
__END__
