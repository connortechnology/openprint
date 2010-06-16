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

sub sign_off {
    require Authen::Captcha;
    if ( $param{'btnFunction'} eq 'Approve Project' ) {
        my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
        if ( 1 == $Captcha->check_code( $param{'Captcha'}, $param{'MD5SUM'} ) ) {
            $variable{'Approved'} = 1;
            # Transitions from Waiting for Customer Approval to Waiting for QA Approval
            #eprint::project::set_status( $log, $dbh, $variable, $param{'ProjectIndex'), 'Waiting for QA Approval' };
            my $Project = new openprint::Project( $param{'ProjectIndex'} );
            my $services = $Project->services();
            my $proofs_service_index = $$services{'Proofs'} ? $$services{'Proofs'}[0] : $$services{'FilmStripping'}[0];

            my $name = $param{'Name'};
            my $when = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', Date::Calc::Today_and_Now() );
            $Project->add_to_log( @session{'company_id','user_id'}, "Client Approval by $name at $when" );
            openprint::service::insert_service_spec( $log, $dbh, $param{'ProjectIndex'}, $proofs_service_index, 'rdbClientApproved', 'Y' );
            openprint::service::insert_service_spec( $log, $dbh, $param{'ProjectIndex'}, $proofs_service_index, 'ClientApprovalDate', $when );
        } else {
            $variable{'Name'} = $param{'Name'};
            $variable{'error'} = 'Validation Code incorrect.  Please try again.';
            $variable{'Redirect'} = '/main/project/sign_off.html';
        } # end if
    } # end if
    openprint::project::view( $log, $dbh, \%variable, $param{'ProjectIndex'} );
    $variable{'ProjectIndex'} = $param{'ProjectIndex'};
} # end sub sign_off

sub history {

	foreach my $key ( keys %param ) {
		if ( $key =~ /chkDelete(\d*)/ ) {
			$variable{'error'} .= openprint::print_project::try_to_delete_project( $log, $dbh, \%variable, $1 );
		} elsif ( $key eq 'btnFunction' and $r->param($key) eq 'Delete Project' ) {
			$variable{'error'} .= openprint::print_project::try_to_delete_project( $log, $dbh, \%variable, $param{'ProjectIndex'} );
		} # end if
	} # end foreach
	# Doing it here will set the defaults if neccessary, but then they will get overriden by the saev_params below.  This is neccessary because save_params will update lastupdated.
	ssi::setup_date_select( '/main/project/history.html', 'created_on', -180, 0 );
	ssi::setup_date_select( '/main/project/history.html', 'updated_on', -14, 0 );
    if ( ! exists $session{'/main/project/history.html?ddmStatus'} ) {
        $session{'/main/project/history.html?ddmStatus'} = join(';', ( 'uncalculated','Unordered','Pending Deposit','Ordered','In Prepress','Proofs Out','Waiting For Customer Approval','Waiting For QA Approval','Approved','Printed','Complete','Waiting For Pickup','Picked Up','Shipped' ) );
    } # end if

	ssi::save_params( '/main/project/history.html', 
			'ddmStatus', 'type_id', 'predefined',
			'created_on_start_year', 'created_on_start_month','created_on_start_day', 
			'created_on_end_year', 'created_on_end_month','created_on_end_day', 
			'updated_on_start_year', 'updated_on_start_month','updated_on_start_day', 
			'updated_on_end_year', 'updated_on_end_month','updated_on_end_day', 
			);
} # end sub history

sub _history {
	ssi::save_params( '/main/project/history.html', 
			'ddmStatus', 'type_id', 'predefined',
			'created_on_start_year', 'created_on_start_month','created_on_start_day', 
			'created_on_end_year', 'created_on_end_month','created_on_end_day', 
			'updated_on_start_year', 'updated_on_start_month','updated_on_start_day', 
			'updated_on_end_year', 'updated_on_end_month','updated_on_end_day', 
			);
} # end sub _history 

1;
__END__
