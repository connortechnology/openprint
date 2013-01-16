use strict;
package openprint::includes;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub _states {
} # end sub _states

sub _provinces {
} # end sub _provinces

sub _like_button {
	my $Object = $variable{'Object'} = $param{'object_type'}->new( $param{'object_id'} );
	my $Like = $Object->Like();
	if ( $Like ) {
		$Object->unlike();
	} else {
		$Object->like();
	} # end if
} # end sub like_button

sub _likes {
	my $Object = $variable{'Object'} = $param{'object_type'}->new( $param{'object_id'} );
	my $Like = $Object->Like();
	if ( $Like ) {
		$Object->unlike();
	} else {
		$Object->like();
	} # end if
} # end sub _likes

sub _captcha {
} # end sub _captcha

sub _privacy_name {
} # end sub _privacy_name
sub _privacy_users {
	my $Privacy = $variable{'Privacy'} = new openprint::Privacy( $param{'privacy_id'} );
	if ( $param{'action'} eq 'add' ) {
		$Privacy->user_id( [ sets::union( @{$Privacy->user_id()}, $param{'user_id'} ) ] );
		$variable{'error'} .= $Privacy->save();	
	} elsif ( $param{'action'} eq 'set' ) {
		$Privacy->user_id( $param{'user_id'} );
	} else {
		$log->error("Unknown action in _privacy_users");
	} # end if
}

sub _users {
} # end sub _users

sub _equipment {
} # end sub _equipment

sub _company_ddm {
} # end sub _company_ddm
1;
__END__
