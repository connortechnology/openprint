package openprint::jsrs_handler;

use Apache2::Request;	 # instead of CGI, it's MUCH faster, and does nice things.
use Apache2::RequestRec ();
use APR::URI;
use Apache2::Const -compile => qw(HTTP_INTERNAL_SERVER_ERROR OK HTTP_NOT_FOUND HTTP_FORBIDDEN);# Offers OK, Error,etc for web server.
use Apache2::Log;
use Apache2::ServerUtil ();
use Apache2::RequestIO ();
use Apache::Session::Postgres;

use strict;

require jsrs;
require sql;
require ssi;
require misc;
require configuration;
require openprint::login;

require openprint::obj_customer;
require openprint::paper_purchase_order;
require openprint::print;
require openprint::Estimating::Printing;
require openprint::print_project;
require openprint::paper;
require openprint::Estimating::Shipping;
require openprint::service;
require	openprint::Estimating::Lamination;
require	openprint::Object;
require openprint::administrator_paper;
require openprint::employee_schedule;

use openprint ();
use vars qw( $r %variable %session %param %config $log $dbh);
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

sub handler {
	my $status;

	%variable = ();
	%param = ();

	my $request = shift;
	$log	= $request->log;
	$r = Apache2::Request->new( $request );
	my $starttime = time;
	$log->debug( "Beginning of JSRS Request: Time (seconds) : $starttime" );

	$dbh = sql::open_sql( $log, 
			'database'	=> $r->dir_config('db_name'),
			'driver'	=> $r->dir_config('db_driver'), 
			'host'		=> $r->dir_config('db_host'),
			'login'		=> $r->dir_config('db_user'),
			'password'	=> $r->dir_config('db_password'),
			);
	configuration::init_cache( $log, $dbh, $r->dir_config() );
	openprint::session_init();
	openprint::usergroup::init_cache();
	openprint::Material::init_cache();
	openprint::Service::init_cache();

	foreach my $key ( $r->param() ) {
$log->debug("Paramter: $key => " . $r->param($key) );
}
	jsrs::Dispatch( $r, $log, $dbh, \%variable );

	if ( exists $variable{'Download'} and $variable{'Download'} ) {
		foreach ( @{$variable{'File_Data'}} ) {
			$r->print( $_ );
		} # end foreach
	} else {
		if ( exists $variable{'Redirect'} and $variable{'Redirect'} ) {
			unless (open(file_handle, $ENV{'DOCUMENT_ROOT'} . $variable{'Redirect'} )) {
				$log->error("Failed opening " . $ENV{'DOCUMENT_ROOT'} . $variable{'Redirect'} . ": $!");
				$dbh->disconnect();
				return Apache2::Const::HTTP_INTERNAL_SERVER_ERROR;
			} # end unless
		} else {
			unless (open(file_handle, $ENV{'DOCUMENT_ROOT'} . $r->uri() )) {
				$log->error("Failed opening " . $r->uri() . ": $!");
				$dbh->disconnect();
				return Apache2::Const::HTTP_INTERNAL_SERVER_ERROR;
			} # end unless
		} # end if
		my $file_data = '';
		while (<file_handle>) {
			$file_data .= $_;
		} # end foreach

		close file_handle;

		$file_data = ssi::variable_substitution( $r, $r->log, $dbh, \$file_data, \%variable );

		$r->print( $file_data );
	} # end if

	#$log->debug("Object cache");
	#foreach my $key ( keys %openprint::Object::cache ) {
		#$log->debug("$key => $openprint::Object::cache{$key}");
	#} # end foreach
	#foreach my $key ( keys %openprint::session ) {
		#$log->debug("Session $key => $openprint::session{$key}");
	#} # end foreach

	# This one loads the cache as well, so it needs the db
	$session{'lastupdated'} = time;
	untie %session;
	$dbh->disconnect();# if $dbh->{'thread_id'};
	$log->debug( "Elapsed seconds: " . ( time - $starttime ) );
	openprint::service::init_cache();
	openprint::Object::init_cache();
	openprint::pricing::clear_cache();
	return Apache2::Const::OK;
}

sub load_content {
	my ( $r, $log, $dbh, $variable, $div, $page, @specs ) = @_;

	while ( @specs ) {
		my ( $name, $value ) = splice @specs, 0, 2;
		if ( exists $param{$name} ) {
#$log->debug("REF $name: " . ref($param{$name}) );
			if ( ref($param{$name}) =~ /ARRAY/ ) {
				push @{$param{$name}}, $value;
			} else {
				$param{$name} = [ $param{$name}, $value ];
			} # end if
		} else {
			$param{$name} = $value;
		} # end if
	} # end while

	my $content = misc::load_file( $log,  $ENV{'DOCUMENT_ROOT'}.$page );
	return jsrs::encode_pairs( 'Div', $div, 'Content', ssi::variable_substitution( $r, $r->log, $dbh, \$content, $variable ) );
} # end sub load_content

sub fill_ddm {
	my ( $r, $log, $dbh, $variable, $formname, $selectname, $arraygenerator ) = @_;
	my @array;
	eval( '@array = ' . $arraygenerator );
	$log->error( "Eval error of ($arraygenerator), Reason: " . $@ ) if $@;
	my @results;
	push @results, join('~', 'Form', $formname );
	push @results, join('~', 'Select', $selectname );

	while ( @array ) {
		push @results, join('~', ( 'Option', shift @array, shift @array ) );
	} # end while
	return join('|', @results );
}

sub exec {
	my ( $r, $log, $dbh, $variable, $div, $function, @specs ) = @_;

	while ( @specs ) {
		my ( $name, $value ) = splice @specs, 0, 2;
		if ( exists $param{$name} ) {
			if ( ref($param{$name}) =~ /ARRAY/ ) {
				push @{$param{$name}}, $value;
			} else {
				$param{$name} = [ $param{$name}, $value ];
			} # end if
		} else {
			$param{$name} = $value;
		} # end if
	} # end while

	my $content = eval $function.'($r, $log, $dbh, $variable);';
	return jsrs::encode_pairs( 'Div', $div, 'Content', ssi::variable_substitution( $r, $r->log, $dbh, \$content, $variable ) );
} # end sub load_content

1;

__END__
