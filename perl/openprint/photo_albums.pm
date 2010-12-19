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
	my $Album = $variable{'Album'} = new openprint::Photo_Album( $param{'album_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$variable{'error'} .= $Album->save(\%param);
        if ( $param{'filename'} ) {
            my $upload = $r->upload('filename');
            if ( ! $upload ) {
                #$Asset->save({'file'=>''});
                $variable{'error'} .= "There was no upload for $param{'filename'}<br/>";
			} else {
				my $Asset = new openprint::Asset();
				$variable{'error'} .= $Asset->save({'filename'=>$param{'filename'}});
				if ( ! $upload->link( $Asset->on_disk_path() ) ) {
					$variable{'error'} .= "There was an error saving file $param{'filename'} to " . $Asset->on_disk_path() . ": $!<br/>";
#$Asset->save({'filename'=>''});
				} else {
					my $Photo = new openprint::Photo_in_Album();
					$variable{'error'} .= $Photo->save({'asset_id'=>$Asset->id(), 'album_id'=>$Album->id()});	
					$variable{'information'} .= "File $param{'filename'} was uploaded successfully.<br/>";
				} # end if
            } # end if
        } # end if
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

sub _photos {
	my $Album = $variable{'Album'} = new openprint::Photo_Album( $param{'album_id'} );
	if ( $param{'action'} eq 'set as thumbnail' ) {
		$variable{'error'} .= $Album->save({'thumbnail_id'=>$param{'asset_id'}});
	} elsif ( $param{'action'} eq 'set as profile pic' ) {
		my $User = new openprint::User( $session{'user_id'} );
		$variable{'error'} .= $User->save({'asset_id'=>$param{'asset_id'}});
	} # end if
} # end sub photos

1;
__END__
