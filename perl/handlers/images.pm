use strict;
package handlers::images;

use Apache2::Request ();
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(REDIRECT HTTP_INTERNAL_SERVER_ERROR OK DECLINED HTTP_NOT_FOUND HTTP_FORBIDDEN);# Offers OK, Error,etc for web server.
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

sub handler {

	my $request = $_[0];
	$r = Apache2::Request->new( $request );
	my $starttime = gettimeofday();
	$r->log->debug( "Beginning of Request: $ENV{HTTP_USER_AGENT} Page: " . $r->uri() );

	$log	= $r->log;

	$dbh = sql::open_sql( $log, 
			'database'	=> $r->dir_config('db_name'),
			'driver'	=> $r->dir_config('db_driver'), 
			'host'		=> $r->dir_config('db_host'),
			'login'		=> $r->dir_config('db_user'),
			'password'	=> $r->dir_config('db_password'),
			);

	my $return_code = Apache2::Const::OK;
	# This one has to go here, because it loads data, the others clear data, so they can go after the requires
	configuration::init_cache( $r->dir_config() );
	if ( $dbh ) {
		#openprint::session_init();

		# The asset filename form is id_title.extension
		my ( $id ) = $r->uri() =~ /(\d+)_.+$/;
		if ( $id ) {
			my $Asset = new openprint::Asset( $id );
			if ( $Asset->id() ) {
				if ( my @Photos = openprint::Photo_in_Album->find('asset_id'=>$$Asset{id}) ) {
					my $can_view = 0;
					foreach my $Album ( map { $_->Album() } @Photos ) {
						if ( $Album->can_view() ) {
							$can_view = 1;
							last;
						} # end if
					} # end foreach Album
					if ( $can_view ) {
						$r->sendfile( $Asset->on_disk_path() );
					} else {
						$return_code = Apache2::Const::HTTP_FORBIDDEN;
					} # end if
				} else {
					# No album means has to be an article image, or a generic site image.
					$r->sendfile( $Asset->on_disk_path() );
				} # end if
			} else {
				$return_code = Apache2::Const::HTTP_NOT_FOUND;
			} # end if
		} # end if

		#$session{'lastupdated'} = time;
		untie %session;
		$dbh->disconnect();
	} # end if
	$log->debug( "Elapsed seconds after: " . sprintf('%.4f', tv_interval([$starttime])*1000).' usecs' );
	# Clear all the caches AFTER we send the data to client! I'm hoping this allows browsers to render before we actually send the OK< the microsecond probably doesn't matter.
	return $return_code;
} # end sub handler

1;
__END__
