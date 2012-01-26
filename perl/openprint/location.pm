use strict;
package openprint::location;

require openprint::Location;
use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub _load_location {
} # end sub _load_location

sub _locations {
} # end sub _locations

sub list {
} # end sub list

sub _action {
} # end sub _action

sub view {
	my $Location = $variable{'Location'} = new openprint::Location( $param{'location_id'} );
	if ( $param{'filename'} ) {
		my $Album = $Location->Album();
		if ( ! $Album->id() ) {
			$variable{'error'} .= $Album->save({'name'=>'Photos for ' . $Location->name()});
			$variable{'error'} .= $Location->save({'album_id'=>$Album->id()});
		} # end if
		$variable{'error'} = $Album->upload( 'filename' );
		if ( ! $variable{'error'} ) {
			$variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
		} # end if
	} # end if
} # end sub view

sub _photos {
	my $Location = $variable{'Location'} = new openprint::Location( $param{'location_id'} );
	if ( $param{'action'} eq 'delete' ) {
		my $Photo = openprint::Photo_in_Album->find_one( {'album_id'=>$$Location{'album_id'}, 'asset_id'=>$param{'asset_id'} } );
		$variable{'error'} .= $Photo->delete() if $Photo->id();
	} # end if
} # end sub _photos
1;
__END__
