package openprint::www;

#use Benchmark;
#use diagnostics;

use strict;
use Apache2::Request;
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
	foreach my $key ( sort sets::union( $r->param ) ) {
		my @values = $r->param($key);
		if ( @values > 1 ) {
			$param{$key} = \@values;
		} else {
			$param{$key} = shift @values;
		} # end if
	} # end foreach
	foreach my $key ( sort keys %param ) {
		if ( ref $param{$key} eq 'ARRAY' ) {
			$log->debug("Parameter $key is (" . join(',',@{$param{$key}}) . ')' );
		} else {
			$log->debug("Parameter $key is (" . $param{$key} . ")" );
		} # end if
	}  # end foreach

	$dbh = sql::open_sql( $log, 
			'database'	=> $r->dir_config('db_name'),
			'driver'	=> $r->dir_config('db_driver'), 
			'host'		=> $r->dir_config('db_host'),
			'login'		=> $r->dir_config('db_user'),
			'password'	=> $r->dir_config('db_password'),
			);

	my $lastpage = '';
	my $page = $r->uri();


		# This one has to go here, because it loads data, the others clear data, so they can go after the requires
	configuration::init_cache( $log, $dbh, $r->dir_config() );
	if ( $dbh ) {
		openprint::session_init();

		foreach my $o ( split(',',$config{'Cached Objects'} ) ) {
			eval sprintf('openprint::%s->init_cache();', $o );
			$log->warn( "Eval error of cached object $o Reason: " . $@ ) if $@;
		} # end foreach

	$openprint::log->debug("Page: $page");
		while ( $page and $lastpage ne $page ) {
			# This is for loop detection
			$lastpage = $page;
	$variable{'uri'} = $page;
			parse_page( $page );
			if ( (exists $variable{'Redirect'}) and $variable{'Redirect'} ) {
$openprint::log->debug("Reirect: $variable{'Redirect'}");
				$page = $variable{'Redirect'};
				$variable{'Redirect'} = '';
			} # end if
		} # end while

	} # end if

	if ( $variable{'ExternalRedirect'} ) {
		$r->headers_out->set(Location=>$variable{'ExternalRedirect'});
		$r->status(Apache2::Const::REDIRECT);
		#$r->send_http_header;
$log->debug("Redirecting to " . $variable{'ExternalRedirect'} );
	} elsif ( exists $variable{'Download'} and $variable{'Download'} ) {
		foreach ( @{$variable{'File_Data'}} ) {
			$r->print( $_ );
		} # end foreach
	} else {
		$variable{'SiteTitle'} = $r->dir_config('SiteTitle');
		$variable{'SecureSiteURL'} = $r->dir_config('SecureSiteURL');
		$variable{'siteURL'} = $r->dir_config('siteURL');
		$variable{'PageTitle'} = $r->dir_config('SiteTitle') .' - ' . $page;

	$log->debug( "Before loading content: ($page) Elapsed seconds: " . ( time - $starttime ) );
		if ( ! exists $variable{'PageContent'} ) {
			my $content;
			if ( -e ($_ = join('/', $config{'SkinPath'}, $page )) ) {
				$content = misc::load_file( $log, $_ );
			} else {
				$content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . $page );
			} # end if
			#$variable{'PageContent'} = ssi::variable_substitution( \$content, \%variable );
			$variable{'PageContent'} = $content;
		} # end if
		my $template;
		my @page_path = split('/', $page );
		my $filename = pop @page_path;
		# _ signifies a page fragment, so don't load layout
		if ( substr($filename, 0, 1 ) ne '_' ) {
			while ( @page_path ) {
				my $file = join( '/', $config{'SkinPath'}, 'layouts', @page_path, $filename );
				#$log->debug("Looking for $file");
				if ( -e $file ) {
					$template = misc::load_file( $log, $file );
					last;
				} # end if
				$file = join( '/', $config{'SkinPath'}, 'layouts', @page_path, 'default.html' );
				#$log->debug("Looking for $file");
				if ( -e $file ) {
					$template = misc::load_file( $log, $file );
					last;
				} # end if
				pop @page_path;
			} # end while
		} # end if _
		if ( $template ) {
			#$log->debug("parsing template!");
			$r->print( ssi::variable_substitution( \$template, \%variable ) );
		} else {
			#$log->warn("No template!" . $r->content_type());
			$_ =  ssi::variable_substitution( \$variable{'PageContent'}, \%variable ) if $variable{'PageContent'} ne '';
			#$log->warn($_);
			$r->print( $_ );
		} # end if
	} # end if

	if ( 0 ) {
		foreach my $key ( keys %openprint::session ) {
			$log->debug("Session $key => $openprint::session{$key}");
		} # end foreach
	} # end if

	if ( $dbh ) {
		$session{'lastupdated'} = time;
		untie %session;
		$dbh->disconnect();
	} # end if
	$log->debug( "Elapsed seconds: " . ( time - $starttime ) );
	# Clear all the caches AFTER we send the data to client! I'm hoping this allows browsers to render before we actually send the OK< the microsecond probably doesn't matter.
	openprint::pricing::clear_cache();
	openprint::service::init_cache();
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
		my $sourceDir = $config{'ProjectFilesPath'} . openprint::upload_handler::get_destdir();
		push @{$variable{'File_Data'}}, misc::load_file( $log, $sourceDir.$variable{'Download'});
		$r->headers_out->{'Content-Disposition'} = "attachment; filename=\"$variable{'Download'}\"";
		$r->content_type( "application/octet-stream; name=\"$variable{'Download'}\"" );
		return;
	} elsif ( $first eq 'administrator' ) {
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
$log->debug("User Type: $session{'user_type'}");
			# If the page requires you to be logged in, check that we are logged in.
			if ( ! sets::isin_regx( $uri, split( ',', $config{'public_URIs'} ) ) ) {
				if ( sql::execute( $log, $dbh, 'SELECT type FROM Users WHERE type=?', 'A' ) ) {
					$variable{'Redirect'} = '/administrator/error/login.html';
					$variable{'Destination'} = misc::get_destination( $r, $r->uri() );
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
			my $eval = "openprint::$first";
			$eval .= '_'.$second if $second;
			eval	'require '.$eval;
			$log->warn( "Eval error of ($eval), Reason: " . $@ ) if $@;
			$filename =~ /(.*).html/;
			$eval .= '::'.$1.'( $r, $log, $dbh, \%variable );';
			eval $eval;
			$log->warn( "Eval error of ($eval), Reason: " . $@ ) if $@;
		} # end if		

	} elsif ( $first eq 'employee' ) {

		openprint::login::verify_user( $r, $log, $dbh, $session{_session_id}, \%variable, 'E' );
		return Apache2::Const::OK if $variable{'Redirect'};	

		if ( $filename eq 'login_confirmation.html' ) {
			$status = openprint::login::verify_login( $r, $log, $dbh, $session{_session_id}, \%variable, 'E' );
			return $status if $variable{'Redirect'};	
		} # end if

		if ( ! sets::isin( $session{'user_type'}, ['E','A'] ) ) {
			if ( ! sets::isin_regx( $uri, split( ',', $config{'public_URIs'} ) )	) {
				$variable{'Redirect'} = '/employee/error/login.html';
				$variable{'Destination'} = misc::get_destination( $r, $uri );
				return Apache2::Const::OK;
			} # end if
		} # end if

		if ( $second eq 'proj' ) {
			require openprint::employee_production;
			openprint::print_project::get_service_specifications( $r, $log, $dbh, \%variable, @openprint::param{'ProjectIndex','ServiceIndex'} ) if $filename ne 'multipage_signatures.html';
			$variable{'ProjectIndex'} = $r->param('ProjectIndex');
			$variable{'ServiceIndex'} = $r->param('ServiceIndex');
			
			$variable{'OrderID'} = $r->param('OrderID');

			$variable{'Project'} = new openprint::Project( $variable{'ProjectIndex'} );
			@variable{'ddmDueDate','OrderedQuantityIndex'} = ( $variable{'Project'}->due_date(), $variable{'Project'}->ordered_quantity_index() );
			$variable{'QTYIndex'} = $variable{'OrderedQuantityIndex'};
			$variable{'DocketNumber'} = $variable{'Project'}->docket();

			$variable{'Employee'} = new openprint::User( $openprint::session{'user_id'} )->name();
			
			if ( $filename eq 'proofs.html' or $filename eq 'FilmStripping.html' ) {
				foreach my $signature_service_index ( $variable{'Project'}->signatures() ) {
					my $sig_specs = openprint::service::get_specs_ref( $variable{'Project'}, $signature_service_index );
					push @{$variable{'Signatures'}}, @$sig_specs{'SignatureIndex','txtServiceDescription'};
					if ( ! $$sig_specs{'UsePress'} ) {
						openprint::service::insert_service_spec( $log, $dbh, $variable{'ProjectIndex'}, $signature_service_index, 'UsePress', $$sig_specs{'ddmPress'.$variable{'Project'}->ordered_quantity_index()} );
					} # end if
					$variable{"UsePress-$signature_service_index"} = $$sig_specs{'UsePress'};
				} # end foreach signature_service_index

				if ( ! $variable{'ddmDueDate'} ) {
					$variable{'ddmDueDate'} = $variable{'Project'}->get_due_date();
				} # end if
				@variable{'duedate_year','duedate_month','duedate_day'} = split('-', $variable{'ddmDueDate'});

			} elsif ( $third eq 'prin' ) {	
				openprint::employee_production::load_press_completion( $log, $dbh, \%variable, $variable{'ProjectIndex'} );
				if ( $filename eq '_production_feedback.html' ) {
					openprint::employee_project::_production_feedback( );
				} elsif ( $filename eq 'prin_multi.html' ) {
					if ( $param{'action'} eq 'SendPPF' ) {
						my $Project = new openprint::Project( $param{'ProjectIndex'} );
						require openprint::CIP3_PPF;
						my $PPF = new openprint::CIP3_PPF( $param{'ppf_id'} );

						my $Equipment;
						foreach my $sig_id ( $Project->signatures() ) {
							my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
							if ( $$sig_specs{'SignatureIndex'} == $$PPF{'signature'} ) {
$log->debug("Found sig");
								my @Equipment = openprint::Equipment->find('strid'=>$$sig_specs{'UsePress'} ? $$sig_specs{'UsePress'} : $$sig_specs{'ddmPress'.$Project->ordered_quantity_index()} );
								if ( @Equipment ) {
									$Equipment = $Equipment[0];
									last;
								} 	
							} # end if
						} # end foreach
						if ( ! $Equipment ) {
							$log->debug("Looking it up from Schedule");
							my @rows = openprint::press_schedule->find('project_id'=>$param{'ProjectIndex'},'service_id'=>$param{'ServiceIndex'});
							if ( @rows == 1 ) {
								$Equipment = new openprint::Equipment( $rows[0]{'equipment_id'} );
							} 
						} # end if
						if ( ! $Equipment ) {
$log->error("Unable to load equipment.  No PPF for you for signature $$PPF{'signature'}.");
						} else {
						$PPF->send_ppf( $Equipment );
						} # end if
					} # end if
				} # end if
			} # end if
		} elsif ( ( $second eq 'accounting' ) and ($session{'user_type'} ne 'A' ) and ! openprint::usergroup::is_user_in( ['Accounting'], $session{'user_id'} ) ) {
			$variable{'error'} = 'Unauthorized';
			$variable{'details'} = 'You are not authorized to view this page.';
			$variable{'Redirect'} = $config{'errorpage'};
			return;
		} else {
			eval( 'require openprint::'.join('_', @path ) );
$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
			my ( $proc ) = $filename =~ /(.*)\.\w*$/;
			eval( 'openprint::'.join('_',@path).'::'.$proc.'( $r, $log, $dbh, \%variable );' );
$log->warn( "Eval error of $filename => ($proc), Reason: " . $@ ) if $@;
		} # end if
	} elsif ( sets::isin( $first , [ 'opera', 'handheld' ] ) ) { # Handheld
		openprint::login::verify_user( $r, $log, $dbh, $session{_session_id}, \%variable, 'E' );
		if ( $variable{'Redirect'} ) {
			$variable{'Destination'} = misc::get_destination( $r, $log, $uri );
			return Apache2::Const::OK;
		} # end if
	} elsif ( $first eq 'content' ) { # main
		$status = openprint::login::verify_user( $r, $log, $dbh, $session{_session_id}, \%variable, 'C' );
		return $status if $variable{'Redirect'};	

		if ( ! $session{'user_id'} ) {
			# if not logged in, determine if they are allowed to see this page or not.
			if ( ! sets::isin_regx( $uri, split( ',', $config{'public_URIs'} ) ) ) {
				$variable{'Redirect'} = '/error/error_login.html';
				$variable{'Destination'} = misc::get_destination( $r, $uri );
				return Apache2::Const::OK;
			} # end if
		} # end if
		eval( 'require openprint::'.join('_', @path ) );
		$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
		my ( $proc ) = $filename =~ /(.*)\.\w*$/;
		eval( 'openprint::'.join('_',@path).'::'.$proc.'( $r, $log, $dbh, \%variable );' );
		$log->warn( "Eval error of ($proc), Reason: " . $@ ) if $@;
	} elsif ( $first eq 'account' ) {
		$status = openprint::login::verify_user( $r, $log, $dbh, $session{_session_id}, \%variable, 'C' );
$log->debug("Account status($status) redirect($variable{'Redirect'}) error($variable{'details'}) details($variable{'error'})");
		return $status if $variable{'Redirect'};	

		if ( ! $session{'user_id'} ) {
			# if not logged in, determine if they are allowed to see this page or not.
$log->debug("Not logged in");
			if ( ! $config{'public_URIs'} ) {
$log->error("No public_URIs");
			} elsif ( ! sets::isin_regx( $uri, split( ',', $config{'public_URIs'} ) ) ) {
$log->debug("redirecting");
				$variable{'Redirect'} = '/error/error_login.html';
				$variable{'Destination'} = misc::get_destination( $r, $uri );
				return Apache2::Const::OK;
			} # end if
		} else {
$log->debug("logged in");
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
			if ( ! sets::isin_regx( $uri, split( ',', $config{'public_URIs'} ) ) ) {
				$variable{'Redirect'} = '/error/error_login.html';
				$variable{'Destination'} = misc::get_destination( $r, $uri );
				return Apache2::Const::OK;
			} # end if
		} # end if

		if ( $second eq 'project' ) {
			require openprint::main_project;
			if ( ( defined $third ) or ( $filename eq 'Paper.html' ) ) {
				if ( ! $variable{'ServiceIndex'} ) {
					my @service_ids = split(',', $openprint::param{'ServiceIndex'} );
					$variable{'ServiceIndex'} = $service_ids[0];
				} # end if
				$variable{'ProjectIndex'} = $openprint::param{'ProjectIndex'} if ! $variable{'ProjectIndex'};
				$variable{'ProjectIndex'} = $openprint::session{'project_id'} if ! $variable{'ProjectIndex'};
				$variable{'Project'} = new openprint::Project( $variable{'ProjectIndex'} );
				$variable{'ServiceType'} = openprint::print::get_ServiceType( @variable{'ProjectIndex','ServiceIndex'} );
				
				@variable{'ServiceTypeID','ServiceTypeName','ServiceTypeType'} = $variable{'ServiceType'}->get('name','description','type' ) if $variable{'ServiceType'};
				my $Currency = openprint::Currency::get_current();
				@variable{'CurrencyName','CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
#, sql::execute( $log, $dbh, q{SELECT currency_id from Projects where index=?}, $variable{'ProjectIndex'} ) );
				my $project_index = $variable{'ProjectIndex'};
				my $service_index = $variable{'ServiceIndex'};

				# Things like UPS SHipping might not actually have a service
				openprint::print::get_quantities( \%variable, $project_index );
				if ( $project_index and $service_index ) {
					my $specs = openprint::service::get_specs_ref( $variable{'Project'}, $service_index );
					@variable{keys %$specs} = @$specs{keys %$specs};
				} # end if
				$variable{'ProjectType'} = $variable{'Project'}->Type();
#$openprint::log->debug("Pid: $variable{'ProjectIndex'} sid: $variable{'ServiceIndex'}");
if ( ! $variable{'ServiceIndex'} ) {
#$openprint::log->warn("Pid: $variable{'ProjectIndex'} sid: $variable{'ServiceIndex'}");
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
						$status = openprint::print::publication_pages( $r, $log, $dbh, \%variable );
					} elsif ( $filename eq 'ScratchPads.html' ) {
						$status = openprint::print::publication_pages( $r, $log, $dbh, \%variable );
					} elsif ( $filename =~ /^_.*\.html$/ ) {
						eval( 'require openprint::'.join('_', @path ) );
						$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
						my ( $proc ) = $filename =~ /(.*)\.\w*$/;
						eval( 'openprint::'.join('_',@path).'::'.$proc.'( $r, $log, $dbh, \%variable );' );
						$log->warn( "Eval error of ($proc), Reason: " . $@ ) if $@;
						$status = openprint::print::print_prices( $r, $log, $dbh, $session{_session_id}, \%variable );
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
$openprint::log->warn('bind');
					if ( $filename eq 'folding.html' ) {
						require openprint::Estimating::Folding;
						openprint::Estimating::Folding::display( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'cutting.html' ) {
						require openprint::Estimating::Cutting;
						openprint::Estimating::Cutting::display( $log, $dbh, \%variable, $project_index, $service_index );
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
					} elsif ( $filename =~ /^(\w*).html$/ ) {
#$openprint::log->debug("$1");
						eval sprintf('require openprint::Estimating::%1$s;
						openprint::Estimating::%1$s::display( $log, $dbh, \%variable, $project_index, $service_index );', $1 );
						$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
					
					} # end if
				} elsif ($third eq 'spec') {
					if ( $filename eq 'lamination.html' ) {
						require openprint::Estimating::Lamination;
						openprint::Estimating::Lamination::display( $log, $dbh, \%variable );
					} elsif ( $filename =~ /^(\w*).html$/ ) {
$openprint::log->debug("$1");
						eval sprintf('require openprint::Estimating::%1$s;
						openprint::Estimating::%1$s::display( $log, $dbh, \%variable, $project_index, $service_index );', $1 );
						$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
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
			} # end if defined third

			openprint::print_project::create_edit_display( $r, $log, $dbh, \%variable )		if $filename eq 'create_edit.html';
			openprint::main_project::history()			if $filename eq 'history.html';
			openprint::main_project::_history()			if $filename eq '_history.html';
			openprint::print::view_services( $r, $log, $dbh, \%variable )					if $filename eq 'view.html';
			openprint::print_project::view_pdfs( $r, $log, $dbh, \%variable )				if $filename eq 'proj_view_pdf.html';
			openprint::print_project::summary( $r, $log, $dbh, \%variable )					if $filename eq 'summary.html';
			openprint::print_project::summary( $r, $log, $dbh, \%variable )					if $filename eq 'docket_sheet.html';
			openprint::print_project::display_reuse_project( $r, $log, $dbh, \%variable ) 	if $filename eq 'reuse.html';
		} else {
			my $module = 'openprint::' . join('_', ($first, $second )	);
			eval( "require $module;" );
			$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
			my ( $proc ) = $filename =~ /(.*).html/;
			if ( $proc ) {
			eval( $module.'::'.$proc.'( $r, $log, $dbh, \%variable );' );
			$log->warn( "Eval error of ($proc), Reason: " . $@ )  if $@;
			} # end if
		} # end if main:$second

	} else {
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

		if ( $first ) {
			my $module = 'openprint::' . lc $first;
			$module .= '_'.$second if $second;
			eval( "require $module;" );
			$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
			my ( $proc ) = $filename =~ /(.*).html/;
			if ( $proc ) {
				eval( $module.'::'.$proc.'( $r, $log, $dbh, \%variable );' );
				$log->warn( "Eval error of ($proc), Reason: " . $@ ) if $@;
			} # end if
		} # end if
	} # end if $first

	return $status;
}


1;

__END__
