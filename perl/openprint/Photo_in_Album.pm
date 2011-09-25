use strict;
package openprint::Photo_in_Album;
our @ISA = qw( openprint::Object );

use openprint ();

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'photos_in_albums';
$serial = 'photos_in_albums_id_seq';
%fields = (
	'id'		=>	'id',
	'album_id'	=>	'album_id',
	'asset_id'	=>	'asset_id',
);

sub thumbnail_url {
	my $Asset = $_[0]->Asset();
	return $Asset->thumbnail_url();
} # end sub thumbnail_url 

sub url {
	my $Asset = $_[0]->Asset();
if ( ! $Asset ) {
$openprint::log->error('Photo_in_Album: no aasset in url: ');
}
	return $Asset->url();
} # end sub url 

sub Album {
	return new openprint::Photo_Album( $_[0]{'album_id'} );
} # end sub Album

sub Comments {
	my $self = shift;
	return $self->Asset()->Comments( @_ );
} # end sub Comments

sub can_edit {
	return 1 if $openprint::session{'user_id'} == $_[0]{'created_by'};
	return 1 if $openprint::session{'user_type'} eq 'A';
	return 0;
} # end sub can_edit

sub view_url {
	return '/photo_albums/view_photo.html?album_id='.$_[0]{'album_id'}.'&amp;asset_id='.$_[0]{'asset_id'};	
} # end sub view_url

sub name {
	return $_[0]->Album()->User()->name()."'s Photo";
} # end sub name
1;
__END__
