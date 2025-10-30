use strict;
use warnings;
package openprint;
use vars qw( $r %variable %session %param %config $log $dbh $User $Company $TZ $Owner $Pricelist $Currency $parser $Host);

use constant Debug => 0;

sub session_init {
	require Apache2::Cookie;
	require Apache::Session::Postgres;
	require openprint::Pricelist;
	require openprint::Currency;
	require DateTime::TimeZone;

	$parser = 'DateTime::Format::Pg';
 
	if ( ! $openprint::config{Timezone} ) {
		$log->error('You must configure a time zone.  Defaulting to America/Toronto');
		$openprint::config{Timezone} = 'America/Toronto';
	} # end if
	$TZ = DateTime::TimeZone->new( name => $openprint::config{Timezone} );
  if ($dbh) {
    $dbh->do('SET timezone = ?', {}, $openprint::config{Timezone}) or die $dbh->errstr();
  }
  my $current_ip = $ENV{HTTP_X_FORWARDED_FOR} ? $ENV{HTTP_X_FORWARDED_FOR} : $ENV{REMOTE_ADDR};

	my $cookies;
	my $cookie;
	if ( $r ) {
		$cookies = Apache2::Cookie->fetch($r);
		if ( $$cookies{_session_id} ) {
			$cookie = $$cookies{_session_id}->value;
      $log->debug("Have session $cookie from cookies") if Debug;
      $cookie =~ s/[^A-Za-z0-9]//g; # sanitize
		} # end if

		if ( $dbh ) {
			# If we have no cookie, then... shouldn't try to load it...
      if ( $cookie ) {
        eval {
          tie %session, 'Apache::Session::Postgres', $cookie, { Handle => $dbh, Commit => 0, IDLength => 8 };
        };
        if (!$@) {
          # No errors, do validation
          # Validate ip on existing session
					if ( $current_ip and $session{ip} and ($session{ip} ne $current_ip) ) {
						$log->error('Change of session ip');
						untie %session;
						%session = ();
          }
        } else { 
          $log->debug("Error fetching Session: $cookie: $@") if $@;
        }
      }
      if (!%session) {
        eval { tie %session, 'Apache::Session::Postgres', undef, { Handle		=> $dbh, Commit		=> 0, IDLength	=> 8 }; };
        if ($@) {
          $log->error('Error creating Session'. $@. ' Trying a second time');
          eval {
            tie %session, 'Apache::Session::Postgres', undef, { Handle		=> $dbh, Commit		=> 0, IDLength	=> 8 };
          };
        }
			} # end if

			if ( (!$cookie) or ($session{_session_id} and ($cookie ne $session{_session_id}))) {
        $log->debug('Generated new cookie '.$session{_session_id}.' because '.($cookie?' != '.$cookie : ' no cookie')) if Debug;
				my $Cookie = Apache2::Cookie->new($r,
						-name	=> '_session_id',
						-value => $session{_session_id},
						-path		=>	'/',
						);
				if ( $Cookie ) {
					$Cookie->bake( $r );
					$cookie = $Cookie->value;
				} else {
					$log->error('No Cookie.  Does db have a sessions table?');
				} # end if
			} # end if
		} else {
			%session = ();
		} # end if
	} # end if $r

  $session{ip} = $current_ip;
  $session{lastupdated} = time;
  $session{HTTP_USER_AGENT} = $ENV{HTTP_USER_AGENT};

# Now set some defaults right away, if we can, FIXME namespace colision
	if ( $param{Country} ) {
		$session{Country} = $param{Country};
	} elsif ( ! $session{Country} ) {
		$session{Country} = $config{Country};
	} # end if

	return if ! $dbh;

	$User = new openprint::User($session{user_id});

	if ( $param{btnFunction} and $session{user_type} and sets::isin($session{user_type}, ['E','A']) ) {
		if ( ( $param{btnFunction} eq 'SelectCompany' ) and $param{ddmCompany} ) {
			if ( $param{ddmCompany} != $session{company_id} ) {

				my $C = new openprint::Company( $param{ddmCompany} );
				if ( ! $C->id() ) {
					$variable{error} .= 'Unknown company selected.  Please try again.<br/>';
				} elsif ( ! $C->can_become( $openprint::User ) ) {
					$variable{error} .= 'You are not authorized to use ' . $C->name().'<br/>';
				} else {
					switch_company( $C );
				} # end if
        undef (@param{'btnFunction','ddmCompany'});
			} # end if
		} elsif ( $param{btnFunction} eq 'SelectPricelist' ) {
			my $pricelist = new openprint::Pricelist( $param{pricelist_id} );
      $pricelist = openprint::Pricelist::get_current() if !$pricelist->id();
			$session{Pricelist_id} = $pricelist->id() if $pricelist->id();
      undef (@param{'btnFunction','pricelist_id'});
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
		if ( $config{currency_id} ) {
			my $C = openprint::Currency->find_one( id => $config{currency_id} );
			if ( ! $C ) {
				$log->error("The default currency $config{currency_id} was not found in db!");
			} else {
				$session{Currency_id} = $C->id();
			}
		} elsif ($config{Currency}) {
			my $C = openprint::Currency->find_one( short => $config{Currency} );
			if ( ! $C ) {
				$log->error("The default currency $config{Currency} was not found in db!");
			} else {
				$session{Currency_id} = $C->id();
			}
    } else {
			$log->warn('Please specify a default currency!');
		}
	} # end if

	$Company = new openprint::Company( $session{company_id} );
	$Owner = new openprint::Company( $config{owner_id} );
	$Currency = new openprint::Currency( $session{Currency_id} );
	$log->debug("Company: $$Company{name} $$User{email} $session{user_type} session: $cookie") if $$User{id};

	if ( $config{Pricelist} ) {
		if ( ! $session{Pricelist_id} ) {
			$_ = openprint::Pricelist->find_one( name => $config{Pricelist} );
			$session{Pricelist_id} = $_->id() if $_;
		} # end if
	} # end if

	if ( ! $session{Pricelist_id} ) {
		my $pricelist = openprint::Pricelist::get_current();
		$session{Pricelist_id} = $pricelist->id() if $pricelist->id();
	} else {
		my $pricelist = new openprint::Pricelist( $session{Pricelist_id} );
		if ( ! $pricelist->id() ) {
			$pricelist = openprint::Pricelist::get_current();
			$session{Pricelist_id} = $pricelist->id() if $pricelist->id();
		} # end if
  } # end if
  if ($session{Pricelist_id}) {
    $Pricelist = new openprint::Pricelist( $session{Pricelist_id} );
    if (!$$Pricelist{id}) {
      $openprint::log->error("No Pricelist from $session{Pricelist_id}");
    } elsif (Debug) {
      $openprint::log->debug("Pricelist $$Pricelist{id} from $session{Pricelist_id}");
    }
  }

  my $ip = $ENV{HTTP_X_FORWARDED_FOR} ? $ENV{HTTP_X_FORWARDED_FOR} : $ENV{REMOTE_ADDR};
  if ($ip) {
    my $safe_ip = openprint::Host_Interface->transform(ip=>$ip);
    # FIXME :ipv6
    if ($safe_ip and ($safe_ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)) {
      openprint::Host_Interface->lock();
      my @Interfaces = openprint::Host_Interface->find(ip=>$safe_ip);
      if ( !@Interfaces ) {
        $log->debug('No HI found for '.$safe_ip);
        $Host = openprint::Host->find_one(hostname=>$safe_ip);
        if ( !$Host ) {
          $Host = new openprint::Host();
          $Host->save({hostname=>$safe_ip});
        }
        # The logging of the creation of the Host entry will save the host_interface
      } else { 
        if ( @Interfaces > 1 ) {
          $log->error("More than 1 Interface with ip $safe_ip");
        }
        $Host = $Interfaces[0]->Host();
      }
      openprint::Host_Interface->unlock();
    } else {
      $log->warn("ip and safe ip differ. $ip != $safe_ip bad ip");
    } # end if safe_ip
  } # end if ip

} # end sub session_init

sub switch_company {
	my ( $Company ) = @_;
	$session{company_id} = $Company->id();
	$openprint::Company = $Company;
	(new openprint::Log())->save({action=>'Switch Company', Object=>$openprint::Company});

	if ( $Company->currency_id() ) {
		$session{Currency_id} = $Company->currency_id();
	} elsif ( $Company->country() ) {
		if ( $Company->country() eq 'US' ) {
			$_ = openprint::Currency->find_one( short=>'USD');
			$session{Currency_id} = $_->id() if $_;
		} elsif ( $Company->country() eq 'CA' ) {
			$_ = openprint::Currency->find_one( short=>'CAD');
			$session{Currency_id} = $_->id() if $_;
		} # end if
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
