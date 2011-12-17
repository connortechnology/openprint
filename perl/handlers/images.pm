package handlers::images;

#use Benchmark;
#use diagnostics;

use strict;
use Apache2::Request;
use Apache2::RequestRec ();
use APR::URI;
use Apache2::Const -compile => qw(REDIRECT HTTP_INTERNAL_SERVER_ERROR OK DECLINED HTTP_NOT_FOUND HTTP_FORBIDDEN);# Offers OK, Error,etc for web server.
use Apache2::Log;
use Apache2::ServerUtil ();
use Apache2::RequestIO ();
use Apache::Session::Postgres;
use Apache2::Cookie;
use Time::HiRes qw{ time gettimeofday tv_interval }; 


require openprint::login;
require openprint::Page_Setting;
require openprint::logs;

require sql;
require misc;
require ssi;
require configuration;

use openprint::Object;

use openprint;
use vars qw( $r %variable %session %param %config $log $dbh %page_settings );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

sub handler {
	%variable = ();
	%param = ();

	my $request = shift;
	$r = Apache2::Request->new( $request );
	$r->content_type(q{text/html; charset=utf-8});
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

	# This one has to go here, because it loads data, the others clear data, so they can go after the requires
	configuration::init_cache( $r->dir_config() );
	if ( $dbh ) {
		openprint::session_init();

		my ( $id, $filename ) = $r->uri() =~ /(\d+)_(.+)$/;
		if ( $id ) {
			my $Asset = new openprint::Asset( $id );
			$r->sendfile( $Asset->on_disk_path() );
		} # end if

		$session{'lastupdated'} = time;
		untie %session;
		$dbh->disconnect();
	} # end if
	$log->debug( "Elapsed seconds: " . sprintf('%.4f', tv_interval([$starttime])*1000).' usecs' );
	# Clear all the caches AFTER we send the data to client! I'm hoping this allows browsers to render before we actually send the OK< the microsecond probably doesn't matter.
	return Apache2::Const::OK;
} # end sub handler

1;
__END__
