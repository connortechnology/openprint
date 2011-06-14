use strict;
package openprint::Photo_in_Album;
our @ISA = qw( openprint::Object );

use openprint ();

use vars qw( $debug $table %fields %transforms %defaults @identified_by );
$debug = 1;
$table = 'photos_in_albums';
%fields = (
	'album_id'	=>	'album_id',
	'asset_id'	=>	'asset_id',
);

@identified_by = ( 'album_id','asset_id' );

sub thumbnail_url {
	my $Asset = $_[0]->Asset();
	return $Asset->thumbnail_url();
} # end sub thumbnail_url 

sub url {
	my $Asset = $_[0]->Asset();
	return $Asset->url();
} # end sub url 

sub Album {
	return new openprint::Photo_Album( $_[0]{'album_id'} );
} # end sub Album

sub id {
	return $_[0]{'album_id'}.'-'.$_[0]{'asset_id'};
} # end sub id

sub Comments {
	my $self = shift;
	return $self->Asset()->Comments( @_ );
} # end sub Comments

sub can_edit {
	return 1 if $openprint::session{'user_id'} == $_[0]{'created_by'};
	return 1 if $openprint::session{'user_type'} eq 'A';
	return 1 if openprint::usergroup::is_user_in( ['Accounting','SalesAdmin','Sales'], $openprint::session{'user_id'} );
	return 1 if sets::isin( $openprint::session{'user_id'}, $_[0]->editor_id() );
	return 0;
} # end sub can_edit
1;
__END__

