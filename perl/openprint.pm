package openprint;

use strict;

use vars qw( $r %variable %session %param %config $log $dbh );


sub store_session {
	my ( $uri, $params, @keys ) = @_;
	foreach my $key ( @keys ) {
		if ( ref $$params{$key} eq 'ARRAY' ) {
			$session{$uri.'?'.$key} = join('|', @{$$params{$key}} );
		} else {
			$session{$uri.'?'.$key} = $$params{$key};
		} # end if
	} # end foreach
	$session{$uri.'?'.'lastupdated'} = time;
}
sub load_session {
	my ( $uri, $hash ) = @_;
	
}

sub session_init {
    my $cookies = Apache2::Cookie->fetch( $r );
    my $cookie = $$cookies{'_session_id'};
    $cookie = $cookie->value if $cookie;

	if ( ! eval q`tie %session, 'Apache::Session::Postgres', $cookie, { Handle => $dbh, Commit => 0, IDLength => 8 }` ) {
		$log->debug("Error fetching Session: $cookie: $@");
		if ( ! eval q`tie %session, 'Apache::Session::Postgres', undef, { Handle      => $dbh, Commit      => 0, IDLength    => 8, };` ) {
			$log->debug("Error creating Session: ");
		} # end if
	} # end if

	if ( $cookie ne $session{_session_id} ) {
		my $Cookie = Apache2::Cookie->new($r,
				-name  => '_session_id',
				-value => $session{_session_id},
				-path	  =>  '/',
				#-domain	=> '.point-one.com',
				);
		$Cookie->bake( $r );
		$cookie = $Cookie->value;
	} # end if

# Now set some defaults right away, if we can
	if ( $r->param('Country') ) {
		$session{'Country'} = $r->param('Country');
	} # end if

	if ( $r->param('Currency') ) {
		my @currencies = openprint::Currency::find( 'short' => $r->param('Currency') );
#$session{'Currency'} = $Currency;
		$session{'Currency_id'} = ( shift @currencies )->id() if @currencies;
	} elsif ( $openprint::param{'select_currency_id'} ) {
		my $Currency = new openprint::Currency( $openprint::param{'select_currency_id'} );;
		$session{'Currency_id'} = $Currency->id();
	} elsif ( ! $session{'Currency_id'} ) {
		my @currencies = openprint::Currency::find( 'short' => $r->dir_config('Currency') );
		$session{'Currency_id'} = ( shift @currencies )->id() if @currencies;
	} # end if

	if ( sets::isin( $session{'user_type'}, ['E','A'] ) and ($r->param('btnFunction') eq 'SelectCompany') ) {
#$openprint::log->debug('Selecting company');
		my $Company = new openprint::Company( $r->param('ddmCompany') );
		if ( ! $Company->id() ) {
			$variable{'error'} .= 'Unknown company selected.  Please try again.';
		} else {
			$session{'company_id'} = $Company->id();
			openprint::logs::insertLogRecord('79',);

			if ( $Company->currency_id() ) {
				$session{'Currency_id'} = $Company->currency_id();
			} elsif ( $Company->country() eq 'US' ) {
				my @currencies = openprint::Currency::find('short'=>'USD');
				$session{'Currency_id'} = (shift @currencies)->id() if @currencies;
			} elsif ( $Company->country() eq 'CA' ) {
				my @currencies = openprint::Currency::find('short'=>'CAD');
				$session{'Currency_id'} = (shift @currencies)->id() if @currencies;
			} # end if
			my @keys = sets::exclude( [ 'Currency_id', '_session_id','user_id','company_id','user_type','Country' ], [ keys %session ] );
			delete @session{@keys};
		} # end if
	} # end if

	if ( ! $session{'Country'} ) {
		$session{'Country'} = $r->dir_config('Country');
		#$log->debug("Setting Country to " . $r->dir_config('Country') );
	} else {
		#$log->debug("Country is " . $session{'Country'} );
	} # end if
	if ( $config{'Pricelist'} ) {
		if ( ! $session{'Pricelist_id'} ) {
			my @pricelists = openprint::Pricelist::find( 'name' => $config{'Pricelist'} );
			$session{'Pricelist_id'} = (shift @pricelists)->id() if @pricelists;
		} # end if
	} # end if
	if ( ! $session{'Pricelist_id'} ) {
		my $Pricelist = new openprint::Pricelist( openprint::pricing::get_pricelist_id( $log, $dbh ) );
		$session{'Pricelist_id'} = $Pricelist->id() if $Pricelist->id();
	} else {
		my $Pricelist = new openprint::Pricelist( $session{'Pricelist_id'} );
		if ( ! $Pricelist->id() ) {
			$Pricelist = new openprint::Pricelist( openprint::pricing::get_pricelist_id( $log, $dbh ) );
			$session{'Pricelist_id'} = $Pricelist->id() if $Pricelist->id();
		} # end if
	} # end if

} # end sub session_init

sub index {
} # end sub index
1;
__END__
