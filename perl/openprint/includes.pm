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

1;
__END__
