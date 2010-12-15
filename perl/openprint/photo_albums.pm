use strict;
package openprint::photo_albums;
use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

require openprint::Photo_Album;
require openprint::Asset;

sub list {
$log->debug("In list");
	my $Album = $variable{'Album'} = new openprint::Photo_Album( $param{'album_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $Album->save(\%param);
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $Album->delete();
	} # end if
} # end sub list
sub _list {
} # end sub _list
sub view {
} # end sub view
sub edit {
	my $Album = $variable{'Album'} = new openprint::Photo_Album( $param{'album_id'} );
} # end sub edit

1;
__END__
