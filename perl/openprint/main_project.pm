package openprint::main_project;
use strict;
use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

require openprint::Project;
require openprint::print_project;
require openprint::service;
require JSON;

sub sign_off {
	require Authen::Captcha;
	if ( $param{btnFunction} eq 'Approve Project' ) {
		my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{SkinPath}.'/images/captcha');
		if ( 1 == $Captcha->check_code( $param{Captcha}, $param{MD5SUM} ) ) {
			$variable{Approved} = 1;
			# Transitions from Waiting for Customer Approval to Waiting for QA Approval
			#eprint::project::set_status( $log, $dbh, $variable, $param{'ProjectIndex'), 'Waiting for QA Approval' };
			my $Project = new openprint::Project( $param{ProjectIndex} );
			my $services = $Project->services();
			my $proofs_service_index = $$services{Proofs} ? $$services{Proofs}[0] : $$services{FilmStripping}[0];

			my $name = $param{Name};
			my $when = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', Date::Calc::Today_and_Now() );
			$Project->add_to_log( @session{'company_id','user_id'}, "Client Approval by $name at $when" );
			openprint::service::insert_service_spec( $log, $dbh, $param{ProjectIndex}, $proofs_service_index, 'rdbClientApproved', 'Y' );
			openprint::service::insert_service_spec( $log, $dbh, $param{ProjectIndex}, $proofs_service_index, 'ClientApprovalDate', $when );
		} else {
			$variable{Name} = $param{Name};
			$variable{error} = 'Validation Code incorrect.	Please try again.';
			$variable{Redirect} = '/main/project/sign_off.html';
		} # end if
	} # end if
	openprint::main_project::view( $param{ProjectIndex} );
	$variable{ProjectIndex} = $param{ProjectIndex};
} # end sub sign_off

sub history {

	if ( $param{btnFunction} eq 'Delete Project' ) {
		if ( $param{project_id} ) {
		foreach my $project_id ( ref $param{project_id} eq 'ARRAY' ? @{$param{project_id}} : $param{project_id} ) {
			$variable{error} .= openprint::print_project::try_to_delete_project( $log, $dbh, \%variable, $project_id );
		} # end foreach project_id
		} elsif ( $param{ProjectIndex} ) {
			$variable{error} .= openprint::print_project::try_to_delete_project( $log, $dbh, \%variable, $param{ProjectIndex} );
		} # end if
		$variable{ExternalRedirect} = '/main/project/history.html';
		return;
	} elsif ( $param{btnFunction} eq 'Reuse Project' ) {
		foreach my $project_id ( ref $param{project_id} eq 'ARRAY' ? @{$param{project_id}} : $param{project_id} ) {
			openprint::print_project::reuse_project( $project_id );
		} # end if
	} elsif ( $param{btnFunction} eq 'Reset' ) {
$log->debug("Reset");
		foreach my $k ( keys %session ) {
			if ( $k =~ /^\/main\/project\/history.html/ ) {
$log->debug("Reset $k");
				delete $session{$k};
			} # end if
		} # end foreach k
		%param = ();
	} # end if

	# Doing it here will set the defaults if neccessary, but then they will get overriden by the saev_params below.	This is neccessary because save_params will update lastupdated.
	ssi::setup_date_select( '/main/project/history.html', 'created_on_start', -180 );
	ssi::setup_date_select( '/main/project/history.html', 'created_on_end', 0 );
	ssi::setup_date_select( '/main/project/history.html', 'updated_on_start', -14 );
	ssi::setup_date_select( '/main/project/history.html', 'updated_on_end', 0 );
	if ( ! exists $session{'/main/project/history.html?ddmStatus'} ) {
		$session{'/main/project/history.html?ddmStatus'} = join(',', ( 'uncalculated','Unordered','Pending Deposit','Ordered','In Prepress','Proofs Out','Waiting For Customer Approval','Waiting For QA Approval','Approved','Printed','Complete','Waiting For Pickup','Picked Up','Shipped','Calculating' ) );
	} # end if
	if ( ! exists $session{'/main/project/history.html?company_id'} ) {
		$session{'/main/project/history.html?company_id'} = $session{company_id};
	} # end if

	_history();
} # end sub history

sub _history {
	ssi::save_params( '/main/project/history.html', 
			'ddmStatus', 'type_id', 'predefined', 'company_id', 'user_id', 'servicetype_id','salesrep_id',
			'created_on_start_year', 'created_on_start_month','created_on_start_day', 
			'created_on_end_year', 'created_on_end_month','created_on_end_day', 
			'updated_on_start_year', 'updated_on_start_month','updated_on_start_day', 
			'updated_on_end_year', 'updated_on_end_month','updated_on_end_day', 
			);
} # end sub _history 

sub view {
	my ( $project_index ) = @_;

	if ( exists $param{ShowAllSignatures} ) {
		$session{ShowAllSignatures} = $param{ShowAllSignatures};
	} # end if
	$variable{ProjectIndex} = $project_index;
	my $Project = $variable{Project} = new openprint::Project( $project_index );
	my $save = 0;
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		if ( $$Project{'price'.$qty_index} != $Project->price($qty_index,undef) ) {
			$save = 1;
			last;
		} # endif
	} # end foreach
	if ( $save ) {
		$Project->save();
	} # end if
} # end sub view

sub _copy_popup {
} # end sub _copy_popup

sub create_edit {
	my $project_index = $param{ProjectIndex};

	my $Project = $variable{Project} = openprint::Project->find_one( id=>$project_index );
	if ( ! $Project ) {
		$Project = $variable{Project} = new openprint::Project();
		if ( $project_index ) {
			$variable{error} .= "Project $param{ProjectIndex} was not found.  A new Project will be created.<br/>";
		}
	}

	@{$variable{ProjectTypes}} = map { $_->name(), $_->description() } openprint::ProjectType->find( order=>'sorting, lower(name)' );
	# Check the appropriate button for project type
	$variable{SelectedProjectType} = $Project->Type()->name();

	@variable{'txtProjectReference','ddmDesign','txtComments','txtQuantity1','txtQuantity2','txtQuantity3','rdbMode','chkPrograms','txtOtherPrograms'} = (
		$Project->reference(), $Project->design(), $Project->comments(), $Project->quantity1(), $Project->quantity2(), $Project->quantity3(), $Project->mode(), $Project->programs(), $Project->other_programs() 
	);

	my $services = $Project->services();
	@{$variable{SelectedServices}} = keys %{$services};

	$variable{ProjectIndex} = $$Project{id};
} # end sub create_edit

sub _calc {
	my $Project = new openprint::Project( $param{ProjectIndex} );
if ( $param{ProjectIndex} and ! $$Project{id} ) {
$log->debug("No project $param{ProjectIndex} found");
}
    if ( $param{action} eq 'add_service' ) {
        my $services = $Project->services();
        foreach my $service_name ( ref $param{service_name} eq 'ARRAY' ? @{$param{service_name}} : $param{service_name} ) {

            next if $$services{$service_name};
            $Project->add_service( $service_name );
        } # end foreach service_name
    } elsif ( $param{action} eq 'del service' ) {
        my $services = $Project->services();
        foreach my $service_name ( ref $param{service_name} eq 'ARRAY' ? @{$param{service_name}} : $param{service_name} ) {
            next if ! $$services{$service_name};
            foreach ( @{$$services{$service_name}} ) {
                my $Service = new openprint::Project_Service( { project_id=>$$Project{id}, service_id=>$_ } );
                $Service->delete();
            } # end foreach service_id
        } # end foreach service_name
    } # end if
} # end sub _calc

sub calc {
	my $debug = @_ ? $_[0] : 1;
$log->debug("Project Index is ($param{ProjectIndex}");
	my $Project = undef;
	if ( $param{ProjectIndex} ) {
		$Project = openprint::Project->find_one( id=>$param{ProjectIndex} );
	}
	if ( ! $Project ) {
		$Project = new openprint::Project();
		$Project->save();
	} else {
		$log->debug("Found proejct $$Project{id}" . $Project->to_string() );
	}
	my $module;
	my $Service;
	if ( $param{ServiceIndex} ) {
		my $Service = $Project->Service( $param{ServiceIndex} );
	}
	if ( ! $Service ) {
		$Service = new openprint::Project_Service();
		$Service->set({ project_id=>$Project->id(), service_type=>$param{ServiceType} } );
	}

	eval {
		require 'openprint/Estimating/'.$Service->service_type().'.pm';
	};
	$log->error("Error requiring $module: $@") if $@;
	my $module = 'openprint::Estimating::'.$Service->service_type();

	$param{method} = 'calc' if ! $param{method};
# Not sure this is a good idea, but its neccessary for printing... why is it neccessary?
	$openprint::service::specs_cache{$param{ServiceIndex}} = \%param if $param{ServiceIndex};
	my %specs = %param;
	if ( my $function = $module->can( $param{method} ) ) {
		$log->debug("Can do $module -> $param{method}");
		$specs{Status} = $function->( $log, $dbh, \%variable, @param{'ProjectIndex','ServiceIndex'}, \%specs );
	} else {
		$log->error("Cant do $param{method} for $module");
	} # end if

	my @vars;
	if ( my $function = $module->can( 'outputs' ) ) {
		@vars = sort $function->( @param{'ProjectIndex', 'ServiceIndex'}, \%specs );
		$log->debug("outputs @vars") if $debug;
	} # end if
	if ( ! @vars ) {
		@vars = keys %specs;
		$log->debug("no outputs, so using keys @vars") if $debug;
	} # end if
	if ( my $function = $module->can( 'no_outputs' ) ) {
		my @no_outputs = sort $function->( @param{'ProjectIndex','ServiceIndex'}, \%specs , \%param );
		$log->debug("$module ::no_outputs: @no_outputs)") if $debug;
		@vars = sets::exclude( \@no_outputs, \@vars );

		foreach my $key ( @no_outputs ) {
			$log->debug("Deleting key $key in no_outputs ") if $debug;
			delete $specs{$key};
		} # end foreach
	} # end if
	foreach my $key ( 'method', 'ContinueProject' ) {
		$log->debug("Deleting key $key in standard no_outputs ") if $debug;
		delete $specs{$key};
	} # end foreach
	if ( $debug ) {
		foreach my $key ( sort keys %specs ) {
			$log->debug("values still in specs $key => $specs{$key}");
		} # end foreach
	} # end if debug
	if ( $debug ) {
		foreach my $key ( sort { $a cmp $b } keys %specs ) {
			if ( (exists $param{$key}) and ($specs{$key} eq $param{$key}) ) {
				$log->debug("Deleting $key cuz it's the same $key = $param{$key}");
				delete $specs{$key};
			} elsif ( ( ! exists $param{$key}) and ! $specs{$key} ) {
				$log->debug("Deleting $key cuz it's not in params and its empty");
				delete $specs{$key};
			} elsif ( ref $specs{$key} ) {
				$log->error("Got a non-scalar in specs! $key => $specs{$key}");
				#delete $specs{$key};
			} # end if
		} # end foreach
		foreach my $key ( sort { $a cmp $b } keys %specs ) {
			$log->debug("Outputting $key = $specs{$key}");
		} # end foreach
	} else {
		foreach my $key ( keys %specs ) {
			next if ref $specs{$key};

			if ( (exists $param{$key}) and ($specs{$key} eq $param{$key}) ) {
				delete $specs{$key};
			} elsif ( ( ! exists $param{$key}) and ! $specs{$key} ) {
				delete $specs{$key};
			} elsif ( ref $specs{$key} ) {
				$log->error("Got a non-scalar in specs! $key => $specs{$key}");
				#delete $specs{$key};
			} # end if
		} # end foreach
	} # end if debug
	return %specs;
} # end sub calc

sub reuse {

	$variable{Project} = new openprint::Project( $param{ProjectIndex} );
	$variable{ProjectIndex} = $variable{Project}->id();
	if ( $variable{Project}->reference() ) {
		$variable{Project}->reference( 'Copy of ' . $variable{Project}->reference() );
	} else {
		$variable{Project}->reference( 'Copy of project # ' . $param{ProjectIndex} );
	} # end if
	
} # end sub

sub docket_sheet {
	openprint::print_project::summary( $r, $log, $dbh, \%variable );
} # end sub docket_sheet

sub _view_log {
}
sub _service_dump {
}
1;
__END__
