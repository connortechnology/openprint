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
		new openprint::Log()->save({'action'=>'Create Photo Album'}) if ! $param{'id'};

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
					new openprint::Log()->save({'action'=>'Upload Photo', 'Object'=>$Photo});
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
	my $Album = $variable{'Album'} = new openprint::Photo_Album( $param{'album_id'} );
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
	} elsif ( $param{'action'} eq 'delete' ) {
		my $Asset = new openprint::Asset( $param{'asset_id'} );
		foreach my $Photo ( openprint::Photo_in_Album->find( 'asset_id' => $Asset->id() ) ) {
			$variable{'error'} .= $Photo->delete();
		} # end foreach Photo
		$variable{'error'} .= $Asset->delete();
	} # end if
} # end sub photos

sub view_photo {
	$param{'asset_id'} =~ s/\D//g;
	$param{'album_id'} =~ s/\D//g;
	my $Photo = new openprint::Photo_in_Album( { 'asset_id' => $param{'asset_id'}, 'album_id'=> $param{'album_id'} } );
	if ( $Photo->user_id() == $session{'user_id'} ) {
		if ( $param{'btnFunction'} eq 'Delete' ) {
			$variable{'error'} .= $Photo->delete();
			if ( ! $variable{'error'} ) {
				$variable{'Redirect'} = '/photo_album/view.html';
				%param = ( 'album_id' => $param{'album_id'} );
			} # end if
		} elsif ( $param{'btnFunction'} eq 'Undelete' ) {
			$variable{'error'} .= $Photo->undelete();
		} elsif ( $param{'btnFunction'} eq 'Save' ) {
			$variable{'error'} .= $Photo->save( \%param );
			if ( ! $variable{'error'} ) {
				$variable{'information'} .= 'Information successfully stored.<br/>';
			} # end if
		} elsif ( $param{'btnFunction'} eq 'Send' ) {
			$variable{'information'} .= $Photo->send();
		} # end if btnfunction
	} # end if owner of the photo
	$variable{'Photo'} = $Photo;
} # end sub view_photo

sub _photo_comments {
	my $Photo = $variable{'Photo'} = openprint::Photo_in_Album->find_one( 'album_id'=>$param{'album_id'}, 'asset_id'=>$param{'asset_id'} );
	if ( ! $Photo ) {
		$variable{'error'} .= 'Photo not found.';
		return;
	} # end if
	if ( $param{'text'} =~ /\S/ ) {
		if ( ! openprint::Comment->find_one(
			'user_id'	=>	$session{'user_id'},
			'text'		=>	$param{'text'},
			'object_id'	=>	$Photo->asset_id(),
			'object_type'	=>	'openprint::Asset',
			) ) {

			my $approved = 0;
			if ( $session{'user_type'} eq 'A' or $session{'user_id'} == $Photo->Asset()->created_by() ) {
				$approved = 1;
			} # endif

			$variable{'error'} .= new openprint::Comment()->save({
					'text'			=>	$param{'text'},
					'object_type'	=>	'openprint::Asset',
					'object_id'		=>	$Photo->Asset()->id(),
					'approved'		=>	$approved,
					});
		} # end if comment already exists
	} elsif ( $param{'action'} eq 'approve' ) {
		my $Comment = openprint::Comment->find_one('object_id'=>$$Photo{'asset_id'}, 'object_type'=>'openprint::Asset', 'id'=>$param{'comment_id'} );
		if ( $Comment ) {
			if ( $Comment->can_approve() ) {
				$Comment->save({'approved'=>1});
			} else {
				$variable{'error'} .= 'You do not have rights to approve that comment.';
$log->error("Attempt to approve a comment without rights");
			} # end if
		} else {
			$variable{'error'} .= 'Comment not found.';
		} # end if
	} elsif ( $param{'action'} eq 'remove' ) {
		my $Comment = openprint::Comment->find_one('object_id'=>$$Photo{'asset_id'}, 'object_type'=>'openprint::Asset', 'id'=>$param{'comment_id'} );
		
		if ( $Comment ) {
			if ( $Comment->can_delete() ) {
				$variable{'error'} .= $Comment->delete();
			} else {
				$variable{'error'} .= 'You do not have rights to delete that comment.';
$log->error("Attempt to delete a comment without rights");
			} # end if
		} else {
			$variable{'error'} .= 'Comment not found or you do not have rights to delete.';
		} # end if
	} # end if
} # end sub _photo_comments
1;
__END__
