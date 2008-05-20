package openprint::employee_account;

use strict;
require openprint::User;
require	email;

require misc;
require sql;
require openprint::MarketingCategory;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config);
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;
*config = \%openprint::config;

sub profile {

	my $User = new openprint::User( $session{'user_id'} );
    if ( $param{'btnFunction'} eq 'Save' ) {
		if ( $param{'password'} ) {
			$variable{'error'} .= 'Password fields do not match.<br>' if $param{'password'} ne $param{'VerifyPassword'};
			$variable{'error'} .= 'New Password is the same as your current password.<br/>' if $param{'password'} eq $User->Password();
		} # end if
        $variable{'error'} .= 'First Name cannot be blank.<br>' if ! $param{'firstname'};
        $variable{'error'} .= 'Last Name cannot be blank.<br>' if ! $param{'lastname'};
        $variable{'error'} .= 'You must select a Salutation.<br>' if ! $param{'salutation'};
        $variable{'error'} .= 'Phone cannot be blank.<br>' if ! $param{'phone'};
        $variable{'error'} .= 'Email Cannot be blank.<br>' if ! $param{'email'};
        if ( ! $variable{'error'} ) {
			delete $param{'password'} if ( ! $param{'password'} );
			delete $param{'VerifyPassword'} if ( ! $param{'VerifyPassword'} );
			delete $param{'btnFunction'};
			$variable{'error'} .= $User->save( \%param );
        } # end if
		if ( $config{mail_db_name} and $param{'email'} =~ /(.*)\@point\-one\.com/ ) {
			if ( $param{'VacationState'} ) {
				email::start_vacation( $r, $log, @param{'email','VacationSubject','VacationMessage'} );
			} else {
				email::stop_vacation( $r, $log, $param{'email'} );
			} # end if
			if ( $param{'EmailPassword'} and $param{'EmailPassword'} eq $param{'VerifyEmailPassword'} ) {
				email::set_password( $r, $log, @param{'email','EmailPassword'} );
			} # end if
			my @aliases = ();
			foreach my $alias ( split "\r\n", $param{'aliases'} ) {
				next if ! $alias;
				push @aliases, $alias;
			} # end foreach
			email::aliases( $log, $User->email(), @aliases );
			$sql::dbh = $dbh;
		} # end if
    } # end if
	$variable{'User'} = $User;
	if ( $config{mail_db_name} and $User->email() =~ /(.*)\@point\-one\.com/ ) {
		@variable{'VacationState','VacationSubject','VacationMessage'} = email::get_vacation( $r, $log, $User->email() );
		@{$variable{'Aliases'}} = email::aliases( $log, $User->email() );
		$sql::dbh = $dbh;
	} # end if

} # end sub profile

sub login {
} # end sub login

sub logout {
	openprint::login::logout( $log, $dbh, \%variable, $session{_session_id}, 'E' );
}


1;

__END__
