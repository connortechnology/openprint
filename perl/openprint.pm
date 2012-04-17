use strict;
package openprint;

require Apache::Session::Postgres;
require Apache2::Cookie;

use vars qw( $r %variable %session %param %config $log $dbh );

sub session_init {
	my $cookies = Apache2::Cookie->fetch( $r );
	my $cookie = $$cookies{'_session_id'};
	$cookie = $cookie->value if $cookie;

	if ( ! eval q`tie %session, 'Apache::Session::Postgres', $cookie, { Handle => $dbh, Commit => 0, IDLength => 8 }` ) {
		$log->debug("Error fetching Session: $cookie: $@");
		if ( ! eval q`tie %session, 'Apache::Session::Postgres', undef, { Handle		=> $dbh, Commit		=> 0, IDLength	=> 8, };` ) {
			$log->debug("Error creating Session: ");
		} # end if
		# Store this, will be useful
		$session{'ip'} = $ENV{'REMOTE_ADDR'};
		$session{'lastupdated'} = time;
	} # end if

	if ( $cookie ne $session{_session_id} ) {
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
	$session{'ip'} = $ENV{'REMOTE_ADDR'} if $ENV{'REMOTE_ADDR'} and ! $session{'ip'};
$log->error("IP : $session{ip}");

# Now set some defaults right away, if we can
	if ( $r->param('Country') ) {
		$session{'Country'} = $r->param('Country');
	} # end if

	if ( $r->param('Currency') ) {
		$_ = openprint::Currency->find_one( 'short' => $r->param('Currency') );
		$session{'Currency_id'} = $_->id() if $_;
	} elsif ( $param{'select_currency_id'} ) {
		my $Currency = new openprint::Currency( $param{'select_currency_id'} );
		$session{'Currency_id'} = $Currency->id();
	} elsif ( ! $session{'Currency_id'} ) {
		$_ = openprint::Currency->find_one( 'short' => $r->dir_config('Currency') );
		$session{'Currency_id'} = $_->id() if $_;
	} # end if

	if ( sets::isin( $session{'user_type'}, ['E','A'] ) ) {
		if ( $r->param('btnFunction') eq 'SelectCompany' ) {
			if ( $r->param('ddmCompany') != $session{'company_id'} ) {
				my $Company = new openprint::Company( $r->param('ddmCompany') );
				if ( ! $Company->id() ) {
					$variable{'error'} .= 'Unknown company selected.  Please try again.';
				} else {
					switch_company( $Company );
				} # end if
			} # end if
		} elsif ( $r->param('btnFunction') eq 'SelectPricelist' ) {
			my $Pricelist = new openprint::Pricelist( $r->param('pricelist_id') );
			if ( ! $Pricelist->id() ) {
				$Pricelist = new openprint::Pricelist( openprint::pricing::get_pricelist_id( ) );
			} # end if
			$session{'Pricelist_id'} = $Pricelist->id() if $Pricelist->id();
		} # end if
	} # end if

	if ( ! $session{'Country'} ) {
		$session{'Country'} = $r->dir_config('Country');
		#$log->debug("Setting Country to " . $r->dir_config('Country') );
	#} else {
		#$log->debug("Country is " . $session{'Country'} );
	} # end if
	if ( $config{'Pricelist'} ) {
		if ( ! $session{'Pricelist_id'} ) {
			$_ = openprint::Pricelist->find_one( 'name' => $config{'Pricelist'} );
			$session{'Pricelist_id'} = $_->id() if $_;
		} # end if
	} # end if
	if ( ! $session{'Pricelist_id'} ) {
		my $Pricelist = new openprint::Pricelist( openprint::pricing::get_pricelist_id( ) );
		$session{'Pricelist_id'} = $Pricelist->id() if $Pricelist->id();
	} else {
		my $Pricelist = new openprint::Pricelist( $session{'Pricelist_id'} );
		if ( ! $Pricelist->id() ) {
			$Pricelist = new openprint::Pricelist( openprint::pricing::get_pricelist_id( ) );
			$session{'Pricelist_id'} = $Pricelist->id() if $Pricelist->id();
		} # end if
	} # end if

} # end sub session_init

sub switch_company {
	my ( $Company ) = @_;
	$session{'company_id'} = $Company->id();
	(new openprint::Log())->save({'action'=>'Switch Company'});

	if ( $Company->currency_id() ) {
		$session{'Currency_id'} = $Company->currency_id();
	} elsif ( $Company->country() eq 'US' ) {
		$_ = openprint::Currency->find_one('short'=>'USD');
		$session{'Currency_id'} = $_->id() if $_;
	} elsif ( $Company->country() eq 'CA' ) {
		$_ = openprint::Currency->find_one('short'=>'CAD');
		$session{'Currency_id'} = $_->id() if $_;
	} # end if
	my @keys = sets::exclude( [ 'Currency_id', '_session_id','user_id','company_id','user_type','Country' ], [ keys %session ] );
	delete @session{@keys};
} # end sub switch_company

sub index {
} # end sub index

1;
__END__
