use strict;
package handlers::assets_authen;

use Apache2::Request ();
use Apache2::RequestRec ();
use Apache2::Access ();
use Apache2::Const -compile => qw(HTTP_UNAUTHORIZED OK HTTP_NOT_FOUND FORBIDDEN AUTH_REQUIRED);# Offers OK, Error,etc for web server.
use Apache2::Log ();
use Time::HiRes qw{ time gettimeofday tv_interval }; 

require sql;
require configuration;
require openprint::Photo_in_Album;
require openprint::Asset;
require openprint::Object;

use openprint ();
use vars qw( $r %session %config $log $dbh );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

use constant DEBUG => 1;

sub cleanup {
	if ( $dbh ) {
		if ( %session ) {
			$session{lastupdated} = time;
			untie %session;
		} # end if
		$dbh->disconnect();
	} # end if
} # end sub cleanup

sub access_handler {
	my $request = $_[0];

	$r = Apache2::Request->new( $request );
	$log = $r->log;
	unless ($request->some_auth_required) {
    $log->error("No auth requried");
		$request->log_reason("No authentication has been configured");
		return Apache2::Const::FORBIDDEN;
	}

	$request->push_handlers(PerlCleanupHandler => \&cleanup);

	$dbh = sql::open_sql( $log,
			database  => $r->dir_config('db_name'),
			port			=> $r->dir_config('db_port'),
			driver    => $r->dir_config('db_driver'),
			host      => $r->dir_config('db_host'),
			login     => $r->dir_config('db_user'),
			password  => $r->dir_config('db_password'),
			);
	my $return_code = Apache2::Const::OK;
# This one has to go here, because it loads data, the others clear data, so they can go after the requires
	configuration::init( $r->dir_config() );
	if ( $dbh ) {
# Need session, have to know who we are!
		openprint::session_init();
		$log->debug("Session is: $session{_session_id} user_id:$session{user_id} company_id:$session{company_id}");
# update connection record
		if ( $session{user_id} ) {
			my $User = new openprint::User( $session{user_id} );
			if ( $User->id() and ! $User->deleted() ) {
				$request->user($User->email());
				$log->debug("Already logged in as $$User{email}") if DEBUG;
# do not ask for a password
				$r->set_handlers(PerlAuthenHandler => [\&Apache2::Const::OK]);
			} # end if
		} # end if

		$session{lastupdated} = time if ! $session{lastupdated};

		# The asset filename form is id_title.extension, path is either assets or thumbnails
		my ( $path, $id, $filename ) = $r->uri() =~ /^\/(.*)\/(\d+)_(.+)$/;
		$path =~ s/^assets\///;
		if ( $id ) {
			my $Asset = new openprint::Asset( $id );
			if ( $$Asset{id} ) {
				my @Photos = openprint::Photo_in_Album->find( asset_id=>$$Asset{id} );
				$log->debug("# of photos found for asset $$Asset{id} " . @Photos ) if DEBUG;
				if ( @Photos ) {
					if ( ! $session{user_id} ) {
						# Not logged in, so make us log in.
						$log->debug("Not logged in , auth required user is " . $r->user() ) if DEBUG;
						return Apache2::Const::OK;
						return Apache2::Const::AUTH_REQUIRED
					} # end if
				
					my $can_view = 0;

					# If any album makes it viewable, then it is viewable... 
					foreach my $Album ( map { $_->Album() } @Photos ) {
						if ( $Album->can_view() ) {
							$can_view = 1;
							last;
						} # end if
					} # end foreach Album
					if ( $can_view ) {
						$log->debug("OK") if DEBUG;
						$return_code = Apache2::Const::OK;
					} else {
						$log->debug("can't view") if DEBUG;
						$return_code = Apache2::Const::HTTP_UNAUTHORIZED;
					} # end if
				} else {
					$log->debug("Not albums, assuming site asset, allowing view: OK") if DEBUG;
					$return_code = Apache2::Const::OK;
				} # end if
			} else {
$log->error("Asset NOT FOUND.  id was $id");
				$return_code = Apache2::Const::HTTP_NOT_FOUND;
			} # end if Asset not found
		} else {
$log->error("No value for aset. " . $r->uri() );
		} # end if parsed uri into asset
        untie %session;
        $dbh->disconnect();
	} else {
		$return_code = Apache2::Const::FORBIDDEN;
    } # end if dbh

    return $return_code;
}

sub authen_handler {
    my $request = $_[0];
    $r = Apache2::Request->new( $request );
    $log    = $r->log;
$log->debug("authen_handler: ") if DEBUG;

	$request->push_handlers(PerlCleanupHandler => \&cleanup);

# get user's authentication credentials
    my ($res, $sent_pw) = $r->get_basic_auth_pw;
    return $res if $res != Apache2::Const::OK;
    my $user = $r->user;

$log->debug("authen_handler: user is $user") if DEBUG;
    $dbh = sql::open_sql( $log,
            database  => $r->dir_config('db_name'),
            driver    => $r->dir_config('db_driver'),
            host      => $r->dir_config('db_host'),
            login     => $r->dir_config('db_user'),
            password  => $r->dir_config('db_password'),
            );
    if ( $dbh ) {
# Should update session
# This one has to go here, because it loads data, the others clear data, so they can go after the requires
		configuration::init( $r->dir_config() );
# Need session, have to know who we are!
		openprint::session_init();
		my $reason = authenticate( $user, $sent_pw );
		if ( ! $reason ) {
			$log->debug("Authen:: Session is: $session{_session_id} user_id:$session{user_id} company_id:$session{company_id}");
			return Apache2::Const::OK;
		} else {
			$r->note_basic_auth_failure;
			$r->log_reason('user not found or password incorrect', $r->uri);
			return Apache2::Const::AUTH_REQUIRED;
		}
	} # end if
	$r->note_basic_auth_failure;
	$r->log_reason('Unable to authenticate', $r->uri);
	return Apache2::Const::AUTH_REQUIRED;
}

sub authenticate {
	my ( $user, $password ) = @_;
# validate username/passwd
	my @Users = openprint::User->find( email=>lc $user, password=>$password, web_active=>'Y' );
	if ( @Users ) {
		my $User = $Users[0];
		@session{'user_id','company_id','user_type'} = @$User{'id','company_id','type'};
	} else {
		return 'User not found.';
	} # end if
	return;
}

1;
__END__
