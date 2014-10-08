use strict;
package openprint::www;

use constant DEBUG => 0;

#use Benchmark;
#use diagnostics;

use Apache2::Request ();
use Apache2::RequestRec ();
use Apache2::Connection ();
use Apache2::RequestUtil ();
use APR::URI ();
use Apache2::Const -compile => qw(REDIRECT HTTP_INTERNAL_SERVER_ERROR OK DECLINED HTTP_NOT_FOUND HTTP_FORBIDDEN);# Offers OK, Error,etc for web server.
use Apache2::Log ();
use Time::HiRes qw{ time gettimeofday tv_interval }; 

require openprint::login;
require openprint::usergroup;
require openprint::Page_Setting;

require sql;
require misc;
require ssi;
require configuration;

require openprint::Object;
require openprint::Currency;
require openprint::Authorization;

use openprint ();
use vars qw( $r %variable %session %param %config $log $dbh $starttime );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

sub cleanup {
	if ( $r->connection->aborted( ) ) {
		$log->debug("Was aborted");
	} # end if
	%openprint::variable = ();
	%openprint::param = ();
	if ( $dbh ) {
		openprint::pricing::clear_cache();
		openprint::service::init_cache();
		openprint::Object::init_cache();
		openprint::StockBrand->find();
		openprint::StockFinish->find();
		$session{lastupdated} = time;
		untie %session;
		if ( ! $dbh->{AutoCommit} ) {
			$log->error("Uncommited transaction");
		} # end if
		$dbh->disconnect();
	} else {
		$log->debug("No dbh at cleanup");
	} # end if
} # end sub cleanup

sub handler {

	my $request = shift;
	$r = Apache2::Request->new( $request );

	# Don't do any caching.	This makes the back button not work.
	$r->no_cache(1);

	$starttime = gettimeofday();
	#$r->log->debug( "Beginning of Request: $ENV{HTTP_USER_AGENT} Page: " . $r->uri() );

	$log	= $r->log;
	$request->push_handlers(PerlCleanupHandler => \&cleanup);
	my $page = $r->uri();
	$log->debug( "Beginning of Request: Page: " . $page );

	%param = ();
	# Here we copy the param data into a hash that is sligthly more useful to use.	Wish we didn't have to do this.
	foreach my $key ( $r->param ) {
	#foreach my $key ( sets::union( $r->param ) ) {
		my @values = $r->param($key);
		#next unless scalar @values;
		if ( @values > 1 ) {
			$param{$key} = \@values;
			#$log->debug("Parameter $key is ARRAY(" . join(',',@{$param{$key}}) . ')' );
		} else {
			$param{$key} = $values[0];
			#$log->debug("Parameter $key is (" . $param{$key} . ") ref: " . ref $param{$key} );
		} # end if
	} # end foreach
	foreach my $key ( sort keys %param ) {
		if ( ref $param{$key} eq 'ARRAY' ) {
			$log->debug("Parameter $key is ARRAY(" . join(',',@{$param{$key}}) . ')' );
		} else {
			$log->debug("Parameter $key is (" . $param{$key} . ")" );
		} # end if
	}	# end foreach

	$dbh = sql::open_sql( $log, 
			database	=> $r->dir_config('db_name'),
			driver		=> $r->dir_config('db_driver'), 
			host		=> $r->dir_config('db_host'),
			login		=> $r->dir_config('db_user'),
			password	=> $r->dir_config('db_password'),
			);

	my $page = $r->uri();
	my $lastpage = '';

	# This one has to go here, because it loads data, the others clear data, so they can go after the requires
	configuration::init( $r->dir_config() );
	openprint::session_init();
	openprint::usergroup::init_cache();
	if ( $dbh ) {
		my $PageSetting = openprint::Page_Setting::get( $page );
		$PageSetting = new openprint::Page_Setting() if ! $PageSetting;
		$variable{PageSetting} = $PageSetting;

		# if not logged in, determine if they are allowed to see this page or not.
		if ( ! $PageSetting->can_view() ) {
			$log->debug("No good, need login");
			if ( $page =~ /^.*\/_/ ) {
				$r->content_type(q{text/javascript; charset=utf-8});
				$r->print( q`window.location='/error/error_login.html';` );
				return Apache2::Const::OK;
			} else {
				if ( $page =~ /employee/ ) {
				$page = '/employee/account/login.html';
				} else {
				$page = '/error/error_login.html';
				} # end if
			} # end if
			$variable{'Destination'} = misc::get_destination( $r, $r->uri() );
				#$r->headers_out->set(Location=>'/error/error_login.html');
				#$r->status(Apache2::Const::REDIRECT);
		} # end if

		foreach my $o ( split(',',$config{'Cached Objects'} ) ) {
			('openprint::'.$o)->init_cache();
		} # end foreach

		#$openprint::log->debug("Page: $page");

		# Just does timeout
		openprint::login::verify_user( $r, $log, $dbh, $session{_session_id}, \%variable );
		$page = $variable{'Redirect'} if $variable{'Redirect'};	

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

	if ( $lastpage =~ /\.html/ ) {
		$r->content_type(q{text/html; charset=utf-8});
	} elsif ( $lastpage =~ /\.json/ ) {
		$r->content_type(q{text/javascript; charset=utf-8});
	} elsif ( $lastpage =~ /\.xml/ ) {
		$r->content_type(q{text/xml; charset=utf-8});
	} elsif ( $lastpage =~ /\.rss/ ) {
		$r->content_type(q{application/rss+xml; charset=utf-8});
	} # end if

	if ( $variable{'ExternalRedirect'} ) {
		foreach my $key ( 'error', 'warning', 'information' ) {
			if ( $variable{$key} ) {
				$session{$key} = $variable{$key};
			} # end if
		} # end foreach
		$r->headers_out->set(Location=>$variable{'ExternalRedirect'});
		$r->status(Apache2::Const::REDIRECT);
		#$r->send_http_header;
		$log->debug("Redirecting to " . $variable{'ExternalRedirect'} );
	} elsif ( exists $variable{'Download'} and $variable{'Download'} ) {
		if ( $variable{'File_Data'} ) {
		foreach ( @{$variable{'File_Data'}} ) {
			$r->print( $_ );
		} # end foreach
		} else {
			$r->print( $variable{'Download'} );
		} # en dif
	} else {
		$variable{'SiteTitle'} = $config{'SiteTitle'};
		$variable{'SecureSiteURL'} = $config{'SecureSiteURL'};
		$variable{'siteURL'} = $config{'siteURL'};
		$variable{'PageTitle'} = $config{'SiteTitle'} .' - ' . $page;

	#$log->debug( "Before loading content: ($page) Elapsed time: " . sprintf('%.4f', tv_interval([$starttime])*1000).' usecs' );
		if ( ! exists $variable{'PageContent'} ) {
			my $content;
			if ( -e ( my $path = join('/', $config{'SkinPath'}, 'html', $page )) ) {
				$content = misc::load_file( $log, $path );
				if ( ! $content ) {
					$log->error("Found no content at $path");
				} # end if
			} elsif ( -e ( my $path = join('/', $config{SkinPath}, $page )) ) {
$log->error("Deprecated SkinPath layout! $path");
				$content = misc::load_file( $log, $path );
				if ( ! $content ) {
					$log->error("Found no content at $path");
				} # end if
			} else {
				$content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . $page );
				if ( ! $content ) {
					$log->error("Found no content at $ENV{'DOCUMENT_ROOT'}$page instead of $config{SkinPath}/$page");
				} # end if
			} # end if
			#$variable{'PageContent'} = ssi::variable_substitution( \$content, \%variable );
			$variable{'PageContent'} = $content;
		} else {
$log->debug("PageContent is $variable{PageContent}");
		} # end if
		my $template;
		my @page_path = split('/', $page );
		my $filename = pop @page_path;
		# _ signifies a page fragment, so don't load layout
		if ( substr($filename, 0, 1 ) ne '_' ) {
			my $file = join( '/', $config{'SkinPath'}, 'layouts', @page_path, $filename );
			#$log->debug("Looking for $file");
			if ( -e $file ) {
				$template = misc::load_file( $log, $file );
			} else {
			while ( @page_path ) {
				$file = join( '/', $config{'SkinPath'}, 'layouts', @page_path, 'default.html' );
				#$log->debug("Looking for $file");
				if ( -e $file ) {
					$template = misc::load_file( $log, $file );
					last;
				} # end if
				pop @page_path;
			} # end while
			} # end if
		} # end if _
		#$log->debug( "After finding template: ($page) Elapsed time: " . sprintf('%.4f', tv_interval([$starttime])*1000).' usecs' );
		local $|=1;
		if ( $template ) {
			#$log->debug("parsing template! $template");
			$r->print( ssi::variable_substitution( \$template, \%variable ) );
		} else {

			#$log->warn("No template!" . $r->content_type());
			$variable{PageContent} = ssi::variable_substitution( \$variable{'PageContent'}, \%variable ) if $variable{'PageContent'} ne '';
			#$log->warn($variable{PageContent});
			#$log->debug( "Before printing: ($page) Elapsed time: " . sprintf('%.4f', tv_interval([$starttime])*1000).' usecs' . length( $variable{PageContent} ) );
			$r->print( $variable{PageContent} );
	#$log->debug( "After printing: ($page) Elapsed time: " . sprintf('%.4f', tv_interval([$starttime])*1000).' usecs' );
		} # end if
	} # end if

	$log->debug( 'Elapsed seconds: ' . sprintf('%.4f', tv_interval([$starttime])*1000).' usecs' );
	return Apache2::Const::OK;
} # end sub handler

sub parse_page {
	my $uri = shift;
	my ( $status );

	# This deals with things like /account/login.html//balhblahblah.php
	my ($real_uri) = $uri =~ /^([^\.]+\.[^\.]+)/i;
#$openprint::log->debug("URI: $real_uri");
	my @thing = split( '/', $real_uri );
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
		push @{$variable{'File_Data'}}, misc::load_file( $log, $sourceDir.$param{'path'}.'/'.$variable{'Download'});
		$r->headers_out->{'Content-Disposition'} = "attachment; filename=\"$variable{'Download'}\"";
		$r->content_type( "application/octet-stream; name=\"$variable{'Download'}\"" );
		return;
	} elsif ( $first eq 'administrator' ) {
		$status = Apache2::Const::OK;

		# This needs special treatment.
		if ( $filename eq 'login_confirmation.html') {
			openprint::login::verify_login( $r, $log, $dbh, $session{_session_id}, \%variable, 'A' );
			return $status if $variable{'Redirect'};	
		} # end if

		if ( $second eq 'account' ) {
			if ( $filename eq 'logout.html' ) {
				openprint::login::logout( $log, $dbh, \%variable, $session{_session_id}, 'A' );
			} # end if
			openprint::login::email_password( $r, $log, $dbh, \%variable )			if $filename eq 'password_confirmation.html';
		} elsif ( $first ) {
			my ( $proc ) = $filename =~ /(.*)\.\w*$/;
			if ( $proc ) {
				my $module = join('_',@path);
				eval {
					require "openprint/$module.pm";
					('openprint::'.$module)->$proc( $r, $log, $dbh, \%variable );
				};
				$log->error( "Eval error of require $module :: $proc, Reason: " . $@ ) if $@;
			} # end if
		} # end if		

	} elsif ( $first eq 'employee' ) {
		if ( $second eq 'proj' ) {
			require openprint::print;
			require openprint::print_project;
			require openprint::employee_production;
			openprint::print_project::get_service_specifications( $r, $log, $dbh, \%variable, @param{'ProjectIndex','ServiceIndex'} ) if $filename ne 'multipage_signatures.html';
			@variable{'ProjectIndex','ServiceIndex','OrderID'} = @param{'ProjectIndex','ServiceIndex','OrderID'};
			
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
					$variable{"UsePress-$signature_service_index"} = $$sig_specs{UsePress};
				} # end foreach signature_service_index

				if ( ! $variable{'ddmDueDate'} ) {
					$variable{'ddmDueDate'} = $variable{Project}->get_due_date();
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
$log->error("Unable to load equipment.	No PPF for you for signature $$PPF{'signature'}.");
						} else {
						$PPF->send_ppf( $Equipment );
						} # end if
					} # end if
				} # end if
			} # end if
		} else {
			my ( $proc ) = $filename =~ /(.*)\.\w*$/;
			if ( $proc ) {
				my $module = join('_',@path);
				eval {
					require "openprint/$module.pm";
					('openprint::'.$module)->$proc( $r, $log, $dbh, \%variable );
				};
				$log->error( "Eval error of require $module :: $proc, Reason: " . $@ ) if $@;
			} # end if
		} # end if
	} elsif ( sets::isin( $first, [ 'content', 'account' ] ) ) { # main
		my ( $proc ) = $filename =~ /(.*)\.\w*$/;
		if ( $proc ) {
			my $module = join('_',@path);
			$log->debug("Calling $module :: $proc");
			eval {
				require "openprint/$module.pm";
				('openprint::'.$module)->$proc( $r, $log, $dbh, \%variable );
			};
			$log->error( "Eval error of require $module :: $proc, Reason: " . $@ ) if $@;
		} # end if
	} elsif ( $first eq 'main' ) { # main
		if ( $second eq 'project' ) {
			require openprint::print;
			require openprint::main_project;
			require openprint::print_project;
			if ( ( defined $third ) or ( $filename eq 'Paper.html' ) ) {
				if ( $param{'ServiceIndex'} and ! $variable{'ServiceIndex'} ) {
					my @service_ids = split(',', $param{'ServiceIndex'} );
					$variable{'ServiceIndex'} = $service_ids[0];
				} # end if
				$variable{'ProjectIndex'} = $openprint::param{'ProjectIndex'} if ! $variable{'ProjectIndex'};
				$variable{'ProjectIndex'} = $openprint::session{'project_id'} if ! $variable{'ProjectIndex'};
				$variable{'Project'} = new openprint::Project( $variable{'ProjectIndex'} );
				my $Currency = openprint::Currency::get_current();
				@variable{'CurrencyName','CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
				my $project_index = $variable{'ProjectIndex'};
				my $service_index = $variable{'ServiceIndex'};

				# Things like UPS SHipping might not actually have a service
				openprint::print::get_quantities( \%variable, $project_index );
				if ( $project_index and $service_index ) {
					my $Service = $variable{Project}->Service( $service_index );
$log->debug("Service: " . $Service->to_string() );
					if ( ! $Service->service_id() ) {
						$variable{error} .= "Unable to load data for service. Perhaps it was removed.<br/>";
						$variable{ExternalRedirect} = '/main/project/view.html?project_id='.$project_index;
					} else {
						$variable{ServiceType} = $Service->ServiceType();
						@variable{'ServiceTypeID','ServiceTypeName','ServiceTypeType'} = $variable{ServiceType}->get('name','description','type') if $variable{ServiceType};

	$log->debug("ServiceType: $variable{'ServiceTypeType'}");
						my $specs = $Service->specs();
						@variable{keys %$specs} = values %$specs;
					} # end if
				} # end if
				$variable{'ProjectType'} = $variable{'Project'}->Type();
				# THis couud happen if the ServiceSpecs clobbered it
				if ( ! $variable{ServiceIndex} ) {
					$variable{ServiceIndex} = $service_index;
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
						require openprint::Estimating::Scanning;
						openprint::Estimating::Scanning::display( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'proofs.html' ) {
						require openprint::Estimating::Proofs;
						openprint::Estimating::Proofs::get_proof_specs( $log, $dbh, \%variable, $project_index, $service_index );
					} # end if

				} elsif ($third eq 'bind') {
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
					if ( $filename =~ /^(\w*).html$/ ) {
						eval sprintf('require openprint::Estimating::%1$s;
						openprint::Estimating::%1$s::display( $log, $dbh, \%variable, $project_index, $service_index );', $1 );
						$log->warn( "Eval error of require, Reason: " . $@ ) if $@;
					} # end if
				} elsif ($third eq 'pack') {
					if ( $filename eq 'pack_by_weight.html' ) {
						openprint::Estimating::Skids::display( $log, $dbh, \%variable, $project_index, $service_index );
					} elsif ( $filename eq 'pack_by_quantity.html' ) {
						require openprint::Estimating::ShrinkWrapping;
						openprint::Estimating::ShrinkWrapping::display( \%variable, $variable{Project}, $service_index );
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
		} elsif ( -e $ENV{'DOCUMENT_ROOT'}.$uri ) {
			my ( $proc ) = $filename =~ /^(.*)\.(html|json|xml|rss)$/;
			if ( $proc ) {
				my $module = join('_', ($first, $second));
				eval{ 
					require "openprint/$module.pm"; 
					('openprint::'.$module)->$proc( $r, $log, $dbh, \%variable );
				};
				$log->error( "Eval error of ($module $proc), Reason: " . $@ )	if $@;
			} # end if
		} else {
			$log->debug($ENV{'DOCUMENT_ROOT'}.$uri . ' does not exist.');
		} # end if main:$second

	} else {
		if ( $first and -e $ENV{'DOCUMENT_ROOT'}.$uri ) {
			my ( $proc ) = $filename =~ /^(.*)\.(html|json|xml|rss)$/;
			if ( $proc ) {
				my $module = lc $first;
				$module .= '_'.$second if $second;
				eval{
					require "openprint/$module.pm"; 
					('openprint::'.$module)->$proc( $r, $log, $dbh, \%variable );
				};
				$log->warn( "Eval error of ($module $proc), Reason: " . $@ ) if $@;
			} # end if
		} else {
			$log->debug("No firstSo or non-existant $uri");
		} # end if
	} # end if $first

	return $status;
}

1;
__END__
