use strict;
package handlers::assets_authen;

use Apache2::Request ();
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(HTTP_UNAUTHORIZED OK HTTP_NOT_FOUND);# Offers OK, Error,etc for web server.
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
        $session{lastupdated} = time;
        untie %session;
        $dbh->disconnect();
    } # end if
} # end sub cleanup

sub handler {

	my $request = $_[0];
	$r = Apache2::Request->new( $request );
	my $starttime = gettimeofday() if DEBUG;
	#$r->log->debug( "Beginning of Request: $ENV{HTTP_USER_AGENT} Page: " . $r->uri() );

	$log	= $r->log;
	$request->push_handlers(PerlCleanupHandler => \&cleanup);

	$dbh = sql::open_sql( $log, 
			'database'	=> $r->dir_config('db_name'),
			'driver'	=> $r->dir_config('db_driver'), 
			'host'		=> $r->dir_config('db_host'),
			'login'		=> $r->dir_config('db_user'),
			'password'	=> $r->dir_config('db_password'),
			);

	my $return_code = Apache2::Const::OK;
	# This one has to go here, because it loads data, the others clear data, so they can go after the requires
	configuration::init( $r->dir_config() );
	if ( $dbh ) {
		# Need session, have to know who we are!
		openprint::session_init();
#$log->debug("Session is: $session{_session_id} $session{user_id} $session{company_id}");
		# If the session was created, then we want to tell it when, otherwise
		# don't update it so that we don't incur another db update
		# Do it up here cuz if the browser kills the connection, we will die during sending and won't do this line
		$session{'lastupdated'} = time if ! $session{'lastupdated'};

$log->debug("hello") if DEBUG;
		# The asset filename form is id_title.extension, path is either assets or thumbnails
		my ( $path, $id, $filename ) = $r->uri() =~ /^\/(.*)\/(\d+)_(.+)$/;
		$path =~ s/^assets\///;
		if ( $id ) {
			my $Asset = new openprint::Asset( $id );
			if ( $$Asset{id} ) {
				if ( my @Photos = openprint::Photo_in_Album->find('asset_id'=>$$Asset{id}) ) {
					my $can_view = 0;
					foreach my $Album ( map { $_->Album() } @Photos ) {
						if ( $Album->can_view() ) {
							$can_view = 1;
							last;
						} # end if
					} # end foreach Album
					if ( $can_view ) {
					$log->debug("OK") if DEBUG;
						return Apache2::Const::OK;
					} else {
					$log->debug("UNATH") if DEBUG;
						return Apache2::Const::HTTP_UNAUTHORIZED;
					} # end if
				} else {
					$log->debug("OK") if DEBUG;
					return Apache2::Const::OK;
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
		$log->error("No dbh!");
	} # end if dbh
	$log->debug( "Elapsed seconds after: " . sprintf('%.4f', tv_interval([$starttime])*1000).' usecs' ) if DEBUG;
	# Clear all the caches AFTER we send the data to client! I'm hoping this allows browsers to render before we actually send the OK< the microsecond probably doesn't matter.
	return $return_code;
} # end sub handler

1;
__END__
