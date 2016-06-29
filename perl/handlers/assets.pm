use strict;
package handlers::assets;

use Apache2::Request ();
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(REDIRECT HTTP_INTERNAL_SERVER_ERROR OK DECLINED HTTP_NOT_FOUND HTTP_FORBIDDEN);# Offers OK, Error,etc for web server.
use APR::Const   -compile => 'SUCCESS';
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

use constant DEBUG => 0;

sub cleanup {
    if ( $r->connection->aborted( ) ) {
$log->debug("Was aborted");
    } else {
#$log->debug("cleanup");
    } # end if
    if ( $dbh ) {
        $session{lastupdated} = time;
        untie %session;
        $dbh->disconnect();
	} else {
$log->error("No dbh in cleanup");
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
		# If the session was created, then we want to tell it when, otherwise
		# don't update it so that we don't incur another db update
		# Do it up here cuz if the browser kills the connection, we will die during sending and won't do this line
		$session{'lastupdated'} = time if ! $session{'lastupdated'};

		# The asset filename form is id_title.extension, path is either assets or thumbnails
		my ( $path, $id, $filename ) = $r->uri() =~ /^\/(.*)\/(\d+)_(.+)$/;
$log->debug("Path: $path id: $id uri:" . $r->uri());
		$path =~ s/^assets\///;
$log->debug("Path: $path id: $id uri:" . $r->uri());
		if ( $id ) {
			my $Asset = new openprint::Asset( $id );
			if ( $$Asset{id} ) {
				if ( my @Photos = openprint::Photo_in_Album->find( asset_id=>$$Asset{id} ) ) {
$log->debug(" Have " . @Photos . " photo for this asset" );
					my $can_view = 0;
					foreach my $Album ( map { $_->Album() } @Photos ) {
						if ( $Album->can_view() ) {
							$can_view = 1;
							last;
						} else {
							$log->debug("Album " . $Album->to_string() . " cannot view" );
						} # end if
					} # end foreach Album
					if ( $can_view ) {
						#$r->headers_out->set('Last-Modified'=>Date::Format::time2str( '%a, %d %b %Y %H:%M:%S %Z', Date::Parse::str2time( $Asset->updated_on() ) ));
						if ( $path eq 'thumbnails' ) {
							$r->sendfile( $Asset->thumbnail_path() );
						} elsif ( $path eq 'medium' ) {
							$r->sendfile( $Asset->medium_path() );
						} elsif ( $path eq 'large' ) {
							$r->sendfile( $Asset->large_path() );
						} elsif ( $path eq 'small' ) {
$log->debug("Sending: " .  $Asset->sized_path( 'small' ) );
							$r->sendfile( $Asset->sized_path( 'small' ) );
						} elsif ( $path eq 'videos' ) {
							if ( -e $config{AssetPath}.'videos/'.$id.'_'.$filename ) {
								#$r->content_type( $Asset->content_type( $id.'_'.$filename ) );
#$r->rflush;
								$log->debug('Sending ' . $config{AssetPath}.'videos/'.$id.'_'.$filename );
								$return_code = $request->sendfile( $config{AssetPath}.'videos/'.$id.'_'.$filename );
$log->debug( "sendfile has failed" ) unless $return_code == APR::Const::SUCCESS;
$log->debug("Return code: $return_code");
							} else {
								$log->error("DOes not exist at: " . $config{AssetPath}.'videos/'.$id.'_'.$filename );
							} # en dif
						} else {
$log->debug("Sending ... " . $Asset->on_disk_path() );
							$r->sendfile( $Asset->on_disk_path() );
						} # end if
$log->error( "Eval error sending image Reason: " . $@ ) if $@;
					} else {
$log->error("FORBIDDEN");
						$return_code = Apache2::Const::HTTP_FORBIDDEN;
					} # end if
				} else {
					$r->headers_out->set('Last-Modified'=>Date::Format::time2str( '%a, %d %b %Y %H:%M:%S %Z', Date::Parse::str2time( $Asset->updated_on() ) ));
					if ( $path eq 'thumbnails' ) {
						$r->sendfile( $Asset->thumbnail_path() );
					} elsif ( $path eq 'medium' ) {
						$r->sendfile( $Asset->medium_path() );
					} else {
# No album means has to be an article image, or a generic site image.
#$log->debug( $Asset->on_disk_path() );
						$r->sendfile( $Asset->sized_path( $path ) );
					} # end if
				} # end if
			} else {
$log->error("NOT FOUND");
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
