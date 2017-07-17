use strict;
package handlers::files_authen;

use Apache2::Request ();
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(HTTP_UNAUTHORIZED OK HTTP_NOT_FOUND);# Offers OK, Error,etc for web server.
use Apache2::Log ();
use Time::HiRes qw{ time gettimeofday tv_interval }; 

require sql;
require configuration;
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
			port		=>	$r->dir_config('db_port'),
			'database'	=> $r->dir_config('db_name'),
			'driver'	=> $r->dir_config('db_driver'), 
			'host'		=> $r->dir_config('db_host'),
			'login'		=> $r->dir_config('db_user'),
			'password'	=> $r->dir_config('db_password'),
			);

	# This one has to go here, because it loads data, the others clear data, so they can go after the requires
	configuration::init( $r->dir_config() );
	if ( $dbh ) {
		# Need session, have to know who we are!
		openprint::session_init();
$log->debug("Session is: $session{_session_id} user_id:$session{user_id} company_id:$session{company_id}");
		# If the session was created, then we want to tell it when, otherwise
		# don't update it so that we don't incur another db update
		# Do it up here cuz if the browser kills the connection, we will die during sending and won't do this line
		$session{'lastupdated'} = time if ! $session{'lastupdated'};

		# The asset filename form is id_title.extension, path is either assets or thumbnails
		my ( $path, $filename ) = $r->uri() =~ /^\/project_files\/(.*\/)(.+)$/;

$log->debug("Path: $path, filename: $filename " );
	
		if ( ! -e $config{ProjectFilesPath}.'/'.$path.$filename ) {
$log->error("Path not found: " . $config{ProjectFilesPath}.'/'.$path.$filename );
			return Apache2::Const::HTTP_NOT_FOUND;
		} # end if
		return if $session{user_type} eq 'A';
		
		my ( $company_name, @path ) = split('/', $path );
		my $Company = openprint::Company->find_one(name=>$company_name);
		if ( ! $Company ) {
			$log->warn("Company not foundL: $company_name");
			return Apache2::Const::HTTP_UNAUTHORIZED;
		} # end if
		if ( ! $Company->can_view() ) {
			return Apache2::Const::HTTP_UNAUTHORIZED;
		} # end if
		return Apache2::Const::OK;

		untie %session;
		$dbh->disconnect();
	} else {
		$log->error("No dbh!");
	} # end if dbh
	$log->debug( "Elapsed seconds after: " . sprintf('%.4f', tv_interval([$starttime])*1000).' usecs' ) if DEBUG;
	# Clear all the caches AFTER we send the data to client! I'm hoping this allows browsers to render before we actually send the OK< the microsecond probably doesn't matter.
	return Apache2::Const::HTTP_UNAUTHORIZED;
} # end sub handler

1;
__END__
