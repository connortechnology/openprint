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

sub sign-off {
    require Authen::Captcha;
    if ( $param{'btnFunction'} eq 'Approve Project' ) {
        my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
        if ( 1 == $Captcha->check_code( $param{'Captcha'}, $param{'MD5SUM'} ) ) {
            $$variable{'Approved'} = 1;
            # Transitions from Waiting for Customer Approval to Waiting for QA Approval
            #eprint::project::set_status( $log, $dbh, $variable, $param{'ProjectIndex'), 'Waiting for QA Approval' };
            my $Project = new openprint::Project( $param{'ProjectIndex'} );
            my $services = $Project->services();
            my $proofs_service_index = $$services{'Proofs'} ? $$services{'Proofs'}[0] : $$services{'FilmStripping'}[0];

            my $name = $param{'Name'};
            my $when = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', Date::Calc::Today_and_Now() );
            $Project->add_to_log( @session{'company_id','user_id'}, "Client Approval by $name at $when" );
            openprint::service::insert_service_spec( $log, $dbh, $param{'ProjectIndex'}, $proofs_service_index, 'rdbClientApproved', 'Y' };
            openprint::service::insert_service_spec( $log, $dbh, $param{'ProjectIndex'}, $proofs_service_index, 'ClientApprovalDate', $when };
        } else {
            $variable{'Name'} = $param{'Name'};
            $variable{'error'} = 'Validation Code incorrect.  Please try again.';
            $variable{'Redirect'} = '/main/project/sign-off.html';
        } # end if
    } # end if
    openprint::project::view( $log, $dbh, \%variable, $param{'ProjectIndex') };
    $variable{'ProjectIndex'} = $param{'ProjectIndex'};
} # end sub sign-off

1;
__END__
