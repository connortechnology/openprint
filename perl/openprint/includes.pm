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

sub _opinion_button {
	my $Object_Type = openprint::Object_Type->find_one('name'=>$param{'object_type'});
	if ( ! $Object_Type ) {
		$log->error('Object type not found : ' . $param{'object_type'} );
		$variable{'error'} .= 'Unable to opinion. Please try again later';
		return;
	} # end if
	my $Object = $variable{'Object'} = $Object_Type->Object( $param{'object_id'} );
	$Object->toggle_Opinion( $param{'opinion_type_id'} );
} # end sub opinion_button

sub _opinions {
	my $Object_Type = openprint::Object_Type->find_one('name'=>$param{'object_type'});
	if ( ! $Object_Type ) {
		$log->error('Object type not found : ' . $param{'object_type'} );
		$variable{'error'} .= 'Unable to load opinions. Please try again later';
		return;
	} # end if
	my $Object = $variable{'Object'} = $Object_Type->Object( $param{'object_id'} );
	$Object->toggle_Opinion( $param{'opinion_type_id'} );
} # end sub _opinions

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

1;
__END__
