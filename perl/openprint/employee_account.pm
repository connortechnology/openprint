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

	$param{'user_id'} = $session{'user_id'} if ! $param{'user_id'};
	$param{'company_id'} = $session{'company_id'} if ! $param{'company_id'};

	my $User = new openprint::User( $param{'user_id'} );

    if ( $param{'btnFunction'} eq 'Save' ) {
		if ( $param{'password'} ) {
			if ( ! $param{'VerifyPassword'} ) {
				$variable{'warning'} .= 'Verify password left blank, password not changed.<br/>';
			} else {
				$variable{'error'} .= 'Password fields do not match.<br/>' if $param{'password'} ne $param{'VerifyPassword'};
			} # end if
			$variable{'warning'} .= 'New Password is the same as your current password.<br/>' if $param{'password'} eq $User->Password();
		} # end if
        $variable{'error'} .= 'First Name cannot be blank.<br/>' if ! $param{'firstname'};
        $variable{'error'} .= 'Last Name cannot be blank.<br/>' if ! $param{'lastname'};
        $variable{'error'} .= 'You must select a Salutation.<br/>' if ! $param{'salutation'};
        $variable{'error'} .= 'Phone cannot be blank.<br/>' if ! $param{'phone'};
        $variable{'error'} .= 'Email Cannot be blank.<br/>' if ! $param{'email'};
        if ( ! $variable{'error'} ) {
			if ( ($session{'user_type'} eq 'A' ) or ( openprint::usergroup::is_user_in( ['UserManagement'], $session{'user_id'} ) ) ) {
				$param{'csr_ids'} = '' if ! exists $param{'csr_ids'};
			} # end if
			delete $param{'password'} if ( ! $param{'password'} );
			delete $param{'VerifyPassword'} if ( ! $param{'VerifyPassword'} );
			delete $param{'btnFunction'};
			$variable{'error'} .= $User->save( \%param );
        } # end if
        if ( ! $variable{'error'} ) {
			if ( $config{mail_db_name} and $param{'email'} =~ /(.*)\@point\-one\.com/ ) {
				if ( $param{'VacationState'} ) {
					email::start_vacation( $r, $log, @param{'email','VacationSubject','VacationMessage'} );
				} else {
					email::stop_vacation( $r, $log, $param{'email'} );
				} # end if
				if ( $param{'EmailPassword'} ) {
					if ( ! $param{'VerifyEmailPassword'} ) {
						$variable{'warning'} .= 'Verify Email password left blank, password not changed.<br/>';
					} elsif ( $param{'EmailPassword'} eq $param{'VerifyEmailPassword'} ) {
						email::set_password( $r, $log, @param{'email','EmailPassword'} );
					} else {
						$variable{'error'} .= 'Email Password fields do not match.<br/>';
					} # end if
				} # end if
				my @aliases = ();
				foreach my $alias ( split "\r\n", $param{'aliases'} ) {
					next if ! $alias;
					push @aliases, $alias;
				} # end foreach
				push @aliases, $User->email() if ! @aliases;
				email::aliases( $log, $User->email(), @aliases );
				$sql::dbh = $dbh;
			} # end if

			if ( ($session{'user_type'} eq 'A' ) or ( openprint::usergroup::is_user_in( ['UserManagement'], $session{'user_id'} ) ) ) {
				my @categories = sql::execute( $log, $dbh, 'SELECT id FROM Marketing_Categories' );

				sql::execute( $log, $dbh, 'DELETE FROM Users_in_Marketing_Categories WHERE user_id=?', $User->id() );
				if ( $param{'marketing_categories'} ) {
					my $sth = $dbh->prepare( q{INSERT INTO Users_in_Marketing_Categories (category_id,user_id) VALUES ( ?, ? )} );
					foreach my $cat ( ref $param{'marketing_categories'} eq 'ARRAY' ? @{$param{'marketing_categories'}} : $param{'marketing_categories'} ) {
						if ( sets::isin( $cat, \@categories ) ) {
							$sth->execute( $cat, $User->id() ) or $log->error( DBI->errstr );
						} # end if
					} # end foreach
				} # end if

				sql::execute( $log, $dbh, q{DELETE FROM Users_in_UserGroups WHERE User_Id=?}, $User->id() );
				if ( $param{'UserGroups'} ) {
					foreach my $group_id ( ref $param{'UserGroups'} eq 'ARRAY' ? @{$param{'UserGroups'}} : $param{'UserGroups'} ) {
						sql::insert( $log, $dbh, 'Users_in_UserGroups', ['usergroup_id', $group_id, 'user_id', $User->id() ] );
					} # end foreach
				} # end if
			} # end if

			$variable{'information'} = 'Record saved successfully.<br/>';
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
