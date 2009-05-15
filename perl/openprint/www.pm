package openprint::www;

#use Benchmark;
#use diagnostics;

use strict;
use Apache2::Request;	# instead of CGI, it's MUCH faster, and does nice things.
use Apache2::RequestRec ();
use APR::URI;
use Apache2::Const -compile => qw(HTTP_INTERNAL_SERVER_ERROR OK DECLINED HTTP_NOT_FOUND HTTP_FORBIDDEN);# Offers OK, Error,etc for web server.
use Apache2::Log;
use Apache2::ServerUtil ();
use Apache2::RequestIO ();
use Apache::Session::Postgres;
use Apache2::Cookie;


require openprint::quote;
require openprint::main_quote;

require openprint::login;

require openprint::print;
require openprint::print_project;
require openprint::Estimating::Proofs;
require openprint::usergroup;

require openprint::logs;

require sql;
require misc;
require ssi;
require configuration;

use openprint::Object;
use openprint::Currency;

use openprint;
use vars qw( $r %variable %session %param %config $log $dbh );
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


	# Don't do any caching.  This makes the back button not work.
	$r->no_cache(1);

	my $starttime = time;
	$r->log->debug( "Beginning of Request: Time (seconds) : $starttime Page: " . $r->uri() );

	$log	= $r->log;

	# Here we copy the param data into a hash that is sligthly more useful to use.  Wish we didn't have to do this.
	foreach my $key ( sets::union( $r->param ) ) {
		my @values = $r->param($key);
		if ( @values > 1 ) {
			$param{$key} = \@values;
				$log->debug("Parameter $key is (" . join(',',@{$param{$key}}) . ')' );
		} else {
			$param{$key} = shift @values;
				$log->debug("Parameter $key is (" . $param{$key} . ")" );
		} # end if
	} # end foreach

	$dbh = sql::open_sql( $log, 
			'database'	=> $r->dir_config('db_name'),
			'driver'	=> $r->dir_config('db_driver'), 
			'host'		=> $r->dir_config('db_host'),
			'login'		=> $r->dir_config('db_user'),
			'password'	=> $r->dir_config('db_password'),
			);

	# This one has to go here, because it loads data, the others clear data, so they can go after the requires
	configuration::init_cache( $log, $dbh, $r->dir_config() );
	openprint::session_init();
	openprint::usergroup::init_cache();
	openprint::Material::init_cache();
	openprint::Service::init_cache();
	openprint::Equipment::init_cache();

	my $lastpage = '';
	my $page = $r->uri();
$openprint::log->debug("Page: $page");
	while ( $page and $lastpage ne $page ) {
		# This is for loop detection
		$lastpage = $page;
$variable{'uri'} = $page;
		parse_page( $page );
		if ( (exists $variable{'Redirect'}) and $variable{'Redirect'} ) {
			$page = $variable{'Redirect'};
			$variable{'Redirect'} = '';
		} # end if
	} # end while

	if ( exists $variable{'Download'} and $variable{'Download'} ) {
		foreach ( @{$variable{'File_Data'}} ) {
			$r->print( $_ );
		} # end foreach
	} else {
		$variable{'SiteTitle'} = $r->dir_config('SiteTitle');
		$variable{'SecureSiteURL'} = $r->dir_config('SecureSiteURL');
		$variable{'siteURL'} = $r->dir_config('siteURL');
		$variable{'PageTitle'} = $r->dir_config('SiteTitle') .' - ' . $page;

	$log->debug( "Before loading content: ($page) Elapsed seconds: " . ( time - $starttime ) );
		if ( ! $variable{'PageContent'} ) {
			my $content;
			if ( -e join('/', $ENV{'DOCUMENT_ROOT'}, 'skins', $config{'SiteTitle'}, $page ) ) {
				$content = misc::load_file( $log, join('/', $ENV{'DOCUMENT_ROOT'}, 'skins', $config{'SiteTitle'}, $page ) );
			} else {
				$content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . $page );
			} # end if
			$variable{'PageContent'} = ssi::variable_substitution( $r, $r->log, $dbh, \$content, \%variable );
		} # end if
		my $template;
		my @page_path = split('/', $page );
		my $filename = pop @page_path;
		# _ signifies a page fragment, so don't load layout
		if ( substr($filename, 0, 1 ) ne '_' ) {
			while ( @page_path ) {
				my $file = join( '/', $ENV{'DOCUMENT_ROOT'}, 'skins/', $r->dir_config('SiteTitle'), '/layouts', @page_path, $filename );
				if ( -e $file ) {
					$template = misc::load_file( $log, $file );
					last;
				} # end if
				$file = join( '/', $ENV{'DOCUMENT_ROOT'}, 'skins/', $r->dir_config('SiteTitle'), '/layouts', @page_path, 'default.html' );
				#$log->debug("Looking for $file");
				if ( -e $file ) {
					$template = misc::load_file( $log, $file );
					last;
				} # end if
				$file = join( '/', $ENV{'DOCUMENT_ROOT'}, 'layouts', @page_path, $filename );
				if ( -e $file ) {
					$template = misc::load_file( $log, $file );
					last;
				} # end if
				$file = join( '/', $ENV{'DOCUMENT_ROOT'}, 'layouts', @page_path, 'default.html' );
				if ( -e $file ) {
					$template = misc::load_file( $log, $file );
					last;
				} # end if
				pop @page_path;
			} # end while
		} # end if _
		if ( $template ) {
			#$log->debug("parsing template!");
			$r->print( ssi::variable_substitution( $r, $log, $dbh, \$template, \%variable ) );
		} else {
			$log->warn("No template!");
			$log->warn($variable{'PageContent'});
			$r->print( $variable{'PageContent'} );
		} # end if
	} # end if

	if ( 0 ) {
		foreach my $key ( keys %openprint::session ) {
			$log->debug("Session $key => $openprint::session{$key}");
		} # end foreach
	} # end if

	$session{'lastupdated'} = time;
	untie %session;
	$dbh->disconnect();
	$log->debug( "Elapsed seconds: " . ( time - $starttime ) );
	# Clear all the caches AFTER we send the data to client!  This is really smart.
	openprint::service::init_cache();
	openprint::pricing::clear_cache();
	openprint::Object::init_cache();
	return Apache2::Const::OK;
} # end sub handler

sub parse_page {
	my $uri = shift;
	my ( $status );

	my @thing = split( '/', $uri );
	my $filename = pop @thing;
	shift @thing; # get rid of element before leading slash
	my @path = @thing;
	my $first = shift @thing if @thing;
	my $second = shift @thing if @thing;
	my $third = shift @thing if @thing;
	my $fourth = shift @thing if @thing;

	if ( $filename eq 'getfile.html' ) {
$openprint::log->debug("Getfile");
		$variable{'Download'} = $openprint::param{'filename'};
		my $sourceDir = $openprint::config{'ProjectFilesPath'} . openprint::upload_handler::get_destdir();
		push @{$variable{'File_Data'}}, misc::load_file( $openprint::log, $sourceDir.$variable{'Download'});
		$r->headers_out->{'Content-Disposition'} = "attachment; filename=\"$variable{'Download'}\"";
		$r->content_type( "application/octet-stream; name=\"$variable{'Download'}\"" );
		return;
	} elsif ( $first eq 'administrator' ) {
		require openprint::admin_quote;
		require openprint::admin_colours;
		require openprint::admin_pricelist;

		$status = openprint::login::verify_user( $r, $log, $dbh, $session{_session_id}, \%variable, 'A' );
		return $status if $variable{'Redirect'};	
		$status = Apache2::Const::OK;

		# This needs special treatment.
		if ( $filename eq 'login_confirmation.html') {
			openprint::login::verify_login( $r, $log, $dbh, $session{_session_id}, \%variable, 'A' );
			return $status if $variable{'Redirect'};	
		} # end if

		if ( $session{'user_type'} ne 'A' ) {
			# If the page requires you to be logged in, check that we are logged in.
			if ( ! sets::isin_regx( $uri, split( ',', $openprint::config{'public_URIs'} ) ) ) {
				if ( sql::execute( $log, $dbh, q{SELECT chrType FROM Users WHERE chrType='A'} ) ) {
					$variable{'Redirect'} = '/administrator/error/login.html';
					$variable{'Destination'} = misc::get_destination( $r, $log );
					return $status;
				} # end if
			} # end if
		} # end if

		if ( $second eq 'account' ) {
			if ( $filename eq 'logout.html' ) {
				openprint::login::logout( $log, $dbh, \%variable, $session{_session_id}, 'A' );
			} # end if
			openprint::login::email_password( $r, $log, $dbh, \%variable )			if $filename eq 'password_confirmation.html';
			openprint::login::login_password( $r, $log, $dbh, \%variable )			if $filename eq 'change_password.html';
			openprint::login::change_password( $r, $log, $dbh, \%variable )			if $filename eq 'change_password_confirmation.html';
		} elsif ( $second eq 'production' ) {
			# services and equipment

			openprint::admin_colours::import_export( $r, $log, $dbh, \%variable ) if $filename eq 'colour_import_export.html';

			openprint::admin_pricelist::edit( $r, $log, $dbh, \%variable )	if $filename eq 'pricelists.html';

		} elsif ( $first ) {
$log->debug("1 $first _ $second $filename");
			my $eval = "openprint::$first";
			$eval .= '_'.$second if $second;
			eval	'require '.$eval;
			$log->warn( "Eval error of ($eval), Reason: " . $@ ) if $@;
			$filename =~ /(.*).html/;
			$eval .= '::'.$1.'( $r, $log, $dbh, \%variable );';
			eval $eval;
			$log->warn( "Eval error of ($eval), Reason: " . $@ ) if $@;
$log->debug('2');
		} # end if		

	} elsif ( $first eq 'employee' ) {

		openprint::login::verify_user( $r, $log, $dbh, $session{_session_id}, \%variable, 'E' );
		if ( $variable{'Redirect'} ) {
			$variable{'Destination'} = misc::get_destination( $r, $log, $uri );
			return Apache2::Const::OK;
		} # end if

		if ( $filename eq 'login_confirmation.html' ) {
			$status = openprint::login::verify_login( $r, $log, $dbh, $session{_session_id}, \%variable, 'E' );
			$variable{'Destination'} = misc::get_destination( $r, $log, $uri );
			return $status if $variable{'Redirect'};	
		} # end if

		if ( ! sets::isin( $session{'user_type'}, ['E','A'] ) ) {
			if ( ! sets::isin_regx( $uri, split( ',', $openprint::config{'public_URIs'} ) )	) {
				$variable{'Redirect'} = '/employee/error/login.html';
				$variable{'Destination'} = misc::get_destination( $r, $log );
				return Apache2::Const::OK;
			} # end if
		} # end if

		if ( $second eq 'proj' ) {
			require openprint::employee_production;
			openprint::print_project::get_service_specifications( $r, $log, $dbh, \%variable, @openprint::param{'ProjectIndex','ServiceIndex'} );
			$variable{'ProjectIndex'} = $r->param('ProjectIndex');
			$variable{'ServiceIndex'} = $r->param('ServiceIndex');
			
			$variable{'OrderID'} = $r->param('OrderID');

			$variable{'Project'} = new openprint::Project( $variable{'ProjectIndex'} );
			@variable{'ddmDueDate','OrderedQuantityIndex'} = ( $variable{'Project'}->due_date(), $variable{'Project'}->ordered_quantity_index() );
			$variable{'QTYIndex'} = $variable{'OrderedQuantityIndex'};
			$variable{'DocketNumber'} = $variable{'Project'}->docket();

			$variable{'Employee'} = new openprint::User( $openprint::session{'user_id'} )->name();
			
			if ( $filename eq 'proofs.html' or $filename eq 'FilmStripping.html' ) {
				my $printing_service_index = openprint::project::get_project_type_service_index( $log, $dbh, $variable{'ProjectIndex'} );
				my $duedatedays = openprint::employee_production::load_press_use( $log, $dbh, \%variable, $variable{'ProjectIndex'} );

				if ( ! $variable{'ddmDueDate'} ) {
					if ( ! $duedatedays ) {
						$duedatedays = 5;
					} # end if
# Make sure that it is a business day!
					my ( $year, $month, $day ) = Date::Calc::Today();
					while ($duedatedays) {
						( $year, $month, $day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, 1 );
						while ( 6 <= Date::Calc::Day_of_Week( $year, $month, $day ) ) {
							( $year, $month, $day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, 1 );
						} # end while
						$duedatedays -= 1;
					} # end while
					@variable{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'} = ( $year, $month, $day );
				} else {
					@variable{'ddmDueDateYear','ddmDueDateMonth','ddmDueDateDay'} = split('-', $variable{'ddmDueDate'});
				} # end if

			} elsif ( $third eq 'prin' ) {	
				openprint::employee_production::load_press_completion( $log, $dbh, \%variable, $variable{'ProjectIndex'} );
				if ( $filename eq '_production_feedback.html' ) {
					openprint::employee_project::_production_feedback( );
				} # end if
			} # end if
		} elsif ( ( $second eq 'accounting' ) and ($session{'user_type'} ne 'A' ) and ! openprint::usergroup::is_user_in( ['Accounting'], $openprint::session{'user_id'} ) ) {
			$variable{'error'} = 'Unauthorized';
			$variable{'details'} = 'You are not authorized to view this page.';
			$variable{'Redirect'} = $config{'errorpage'};
			return;
		} else {
			eval( 'require openprint::'.join('_', @path ) );
$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
			my ( $proc ) = $filename =~ /(.*)\.\w*$/;
			eval( 'openprint::'.join('_',@path).'::'.$proc.'( $r, $log, $dbh, \%variable );' );
$log->warn( "Eval error of ($proc), Reason: " . $@ ) if $@;
		} # end if
	} elsif ( $first eq 'handheld' ) { # Handheld
		openprint::login::verify_user( $r, $log, $dbh, $session{_session_id}, \%variable, 'E' );
		if ( $variable{'Redirect'} ) {
			$variable{'Destination'} = misc::get_destination( $r, $log, $uri );
			return Apache2::Const::OK;
		} # end if

		if ( $filename eq 'index.html' and $param{'action'} eq 'Login' ) {
			$status = openprint::login::verify_login( $r, $log, $dbh, $session{_session_id}, \%variable, 'E' );
			$variable{'Destination'} = misc::get_destination( $r, $log, $uri );
			return $status if $variable{'Redirect'};
		} # end if

		if ( $filename ne 'index.html' and ! sets::isin( $session{'user_type'}, ['E','A'] ) ) {
			$variable{'Redirect'} = '/handheld/index.html';
			$variable{'Destination'} = misc::get_destination( $r, $log );
			return Apache2::Const::OK;
		} # end if
		eval( 'require openprint::'.join('_', @path ) );
		$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
		my ( $proc ) = $filename =~ /(.*)\.\w*$/;
		eval( 'openprint::'.join('_',@path).'::'.$proc.'( $r, $log, $dbh, \%variable );' );
		$log->warn( "Eval error of ($proc), Reason: " . $@ ) if $@;

	} elsif ( $first eq 'content' ) { # main
		$status = openprint::login::verify_user( $r, $log, $dbh, $session{_session_id}, \%variable, 'C' );
		return $status if $variable{'Redirect'};	

		if ( ! $session{'user_id'} ) {
			# if not logged in, determine if they are allowed to see this page or not.
			if ( ! sets::isin_regx( $uri, split( ',', $config{'public_URIs'} ) ) ) {
				$variable{'Redirect'} = '/error/error_login.html';
				$variable{'Destination'} = misc::get_destination( $r, $log, $uri );
				return Apache2::Const::OK;
			} # end if
		} # end if
		eval( 'require openprint::'.join('_', @path ) );
		$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
		my ( $proc ) = $filename =~ /(.*)\.\w*$/;
		eval( 'openprint::'.join('_',@path).'::'.$proc.'( $r, $log, $dbh, \%variable );' );
		$log->warn( "Eval error of ($proc), Reason: " . $@ ) if $@;
	} elsif ( $first eq 'main' ) { # main
		$status = openprint::login::verify_user( $r, $log, $dbh, $session{_session_id}, \%variable, 'C' );
		return $status if $variable{'Redirect'};	

		if ( ! $session{'user_id'} ) {
			# if not logged in, determine if they are allowed to see this page or not.
			if ( ! sets::isin_regx( $uri, split( ',', $openprint::config{'public_URIs'} ) ) ) {
				$variable{'Redirect'} = '/error/error_login.html';
				$variable{'Destination'} = misc::get_destination( $r, $log, $uri );
$log->debug("Dset: $variable{'Destination'}");
				return Apache2::Const::OK;
			} # end if
		} # end if

		if ( $second eq 'order' ) {
			require openprint::order;
			openprint::order::quantity_select_display( $r, $log, $dbh, $session{_session_id}, \%variable )		if $filename eq 'selection.html';
			openprint::order::information( $r, $log, $dbh, $session{_session_id}, \%variable )					if $filename eq 'information.html';
			openprint::order::verify_order( $r, $log, $dbh, $session{_session_id}, \%variable )				if $filename eq 'submit.html';
			openprint::order::finalise_order( $r, $log, $dbh, $session{_session_id}, \%variable )				if $filename eq 'confirmation_make_order.html';
			openprint::order::history( $r, $log, $dbh, \%variable )								if $filename eq 'history.html';
			openprint::order::history_details( $r, $log, $dbh, \%variable )						if $filename eq 'history_details.html';
		
		} elsif ( $second eq 'project' ) {
			if ( defined $third ) {
				if ( ! $variable{'ServiceIndex'} ) {
					$variable{'ServiceIndex'} = $openprint::param{'ServiceIndex'};
				} # end if
				$variable{'ProjectIndex'} = $openprint::param{'ProjectIndex'} if ! $variable{'ProjectIndex'};
				$variable{'ProjectIndex'} = $openprint::session{'project_id'} if ! $variable{'ProjectIndex'};
				$variable{'Project'} = new openprint::Project( $variable{'ProjectIndex'} );
				my $ProjectType = $variable{'Project'}->Type();
				@variable{'ProjectTypeID','ProjectTypeName'} = ($ProjectType->strid(), $ProjectType->name() );
				$variable{'ServiceType'} = openprint::print::get_ServiceType( @variable{'ProjectIndex','ServiceIndex'} );
				
				@variable{'ServiceTypeID','ServiceTypeName'} = ($variable{'ServiceType'}->name(), $variable{'ServiceType'}->description() ) if $variable{'ServiceType'};
				my $Currency = openprint::Currency::get_current();
				@variable{'CurrencyName','CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
#, sql::execute( $log, $dbh, q{SELECT currency_id from tbl_Projects where index=?}, $variable{'ProjectIndex'} ) );
				my $project_index = $variable{'ProjectIndex'};
				my $service_index = $variable{'ServiceIndex'};

				# Things like UPS SHipping might not actually have a service
				openprint::print::get_quantities( \%variable, $project_index );
				if ( $project_index and $service_index ) {
				my $specs = openprint::service::get_specs_ref( $project_index, $service_index );
				@variable{keys %$specs} = @$specs{keys %$specs};
				} # end if
$openprint::log->debug("Pid: $variable{'ProjectIndex'} sid: $variable{'ServiceIndex'}");
if ( ! $variable{'ServiceIndex'} ) {
$openprint::log->warn("Pid: $variable{'ProjectIndex'} sid: $variable{'ServiceIndex'}");
$variable{'ServiceIndex'} = $service_index;
} # end if

				if ( $third eq 'prin' ) {
					$log->debug("** START OF MAIN:PROJ:PRIN * ($project_index) ($service_index)");
					if ( $filename eq 'paper.html' ) {
						require openprint::Paper;
						my $paperService = new openprint::Paper( );
						$paperService->display( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'multipage_signatures.html' ) {
						$status = openprint::print::print_prices( $r, $log, $dbh, $session{_session_id}, \%variable );
					} elsif ( $filename eq 'prin_multi.html' ) {
						$status = openprint::print::publication_pages( $r, $log, $dbh, $session{_session_id}, \%variable );
					} else {
						$status = openprint::print::print_prices( $r, $log, $dbh, $session{_session_id}, \%variable );
					} # end if
				} elsif ($third eq 'prep') {

					if ( $filename eq 'scanning.html' ) {
						openprint::Estimating::Scanning::display( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'proofs.html' ) {
						openprint::Estimating::Proofs::get_proof_specs( $log, $dbh, \%variable, $project_index, $service_index );
					} # end if

				} elsif ($third eq 'bind') {
					if ( $filename eq 'folding.html' ) {
						require openprint::Estimating::Folding;
						openprint::Estimating::Folding::display( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'cutting.html' ) {
						require openprint::Estimating::Cutting;
						openprint::Estimating::Cutting::display( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'die_cutting.html' or $filename eq 'bind_kiss_cutt.html' ) {
						require openprint::Estimating::DieCutting;
						openprint::Estimating::DieCutting::display( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'perforating.html' ) {
						require openprint::Estimating::Perforating;
						openprint::Estimating::Perforating::get_specs( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'scoring.html' ) {
						openprint::Estimating::Scoring::get_specs( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'stitching.html' ) {
						require openprint::Estimating::Stitching;
						openprint::Estimating::Stitching::display( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'drilling.html' ) {
						require openprint::Estimating::Drilling;
						openprint::Estimating::Drilling::display( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'collating.html' ) {
						require openprint::Estimating::Collating;
						openprint::Estimating::Collating::display( $log, $dbh, \%variable, $project_index, $service_index );
					} # end if
				} elsif ($third eq 'spec') {
					if ( $filename eq 'lamination.html' ) {
						require openprint::Estimating::Lamination;
						openprint::Estimating::Lamination::display( $log, $dbh, \%variable );
					} elsif ( $filename eq 'UVCoating.html' ) {
						require openprint::Estimating::UVCoating;
						openprint::Estimating::UVCoating::display( $log, $dbh, \%variable, $project_index, $service_index );
					} # end if
				} elsif ($third eq 'pack') {
					if ( $filename eq 'pack_by_weight.html' ) {
						openprint::Estimating::Skids::display( $log, $dbh, \%variable, $project_index, $service_index );
					} # end if
				} elsif ($third eq 'shipping') {

					if ( $filename eq 'Shipping.html' ) {
						require openprint::Estimating::Shipping;
						openprint::Estimating::Shipping::display( $r, $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'UPS.html' ) {
						require openprint::Estimating::UPS;
						openprint::Estimating::UPS::display( $log, $dbh, \%variable, $project_index, $service_index );
					} # end if
				} # end if main:proj:$third
			} # end if

			openprint::print_project::create_edit_display( $r, $log, $dbh, \%variable )		if $filename eq 'create_edit.html';
			openprint::print_project::history_list( $r, $log, $dbh, \%variable )					if $filename eq 'history.html';
			openprint::print::view_services( $r, $log, $dbh, \%variable )				if $filename eq 'view.html';
			openprint::print_project::view_pdfs( $r, $log, $dbh, \%variable )					if $filename eq 'proj_view_pdf.html';
			openprint::print_project::summary( $r, $log, $dbh, \%variable )						if $filename eq 'summary.html';
			openprint::print_project::summary( $r, $log, $dbh, \%variable )						if $filename eq 'docket_sheet.html';
			openprint::print_project::display_reuse_project( $r, $log, $dbh, \%variable ) 		if $filename eq 'reuse.html';
		} else {
			my $module = 'openprint::' . join('_', ($first, $second )	);
			eval( "require $module;" );
			$log->warn( "Eval error of require, Reason: " . $@ );	# if $@;
			my ( $proc ) = $filename =~ /(.*).html/;
			eval( $module.'::'.$proc.'( $r, $log, $dbh, \%variable );' );
			$log->warn( "Eval error of ($proc), Reason: " . $@ ); # if $@;
		} # end if main:$second

	} else {
		if ( $first ) {
			my $module = 'openprint::' . $first;
			$module .= '_'.$second if $second;
			eval( "require $module;" );
			$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
			my ( $proc ) = $filename =~ /(.*).html/;
			eval( $module.'::'.$proc.'( $r, $log, $dbh, \%variable );' );
			$log->warn( "Eval error of ($proc), Reason: " . $@ ) if $@;
		} # end if
	} # end if $first

	return $status;
}


1;

__END__
