use strict;
use Digest::MD5;
require openprint::Asset;
require openprint::Photo_in_Album;
# A collection of Assets
package openprint::Photo_Album;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$serial = 'photo_albums_id_seq';
$table = 'photo_albums';

%fields = (
	'id'				=>	'id',
	'user_id'			=>	'user_id',
	'name'				=>	'name',
	'thumbnail_id'		=>	'thumbnail_id',
	'created_on'		=>	'created_on',
	'privacy_mode_id'	=>	'privacy_mode_id',
	'deleted'			=>	'deleted',
);

%defaults = (
	'created_on'	=> q`'NOW()'`,
	'thumbnail_id'	=>	undef,
	'deleted'		=>	0,
);


sub Thumbnail {
	if ( ! $_[0]{'thumbnail_id'} ) {
$openprint::log->debug("No thumbnail assigned, showing first.");
		my @Photos = $_[0]->Photos();
		return $Photos[0] if @Photos;
	} # end if
$openprint::log->debug("thumbnail assigned.");
	return new openprint::Photo_in_Album( { 'asset_id'=>$_[0]{'thumbnail_id'}, 'album_id'=>$_[0]{'id'} } );
} # end sub Thumbnail

sub thumbnail_url {
	return $_[0]->Thumbnail()->thumbnail_url();
} # end sub thumbnail_url

sub Photos {
	if ( @_ > 1 or ! $_[0]{'Photos'} ) {
		@{$_[0]{'Photos'}} = openprint::Photo_in_Album->find('album_id'=>$_[0]{'id'},'order'=>'asset_id');
	} # end if
	return @{$_[0]{'Photos'}};
} # end sub Photos

sub destroy {
	my $error = '';
	foreach my $Photo ( $_[0]->Photos() ) {
		$error .= $Photo->destroy();
	} # end foreach Photo
	$error .= $_[0]->SUPER::destroy();
	return $error;
} # end sub delete

sub upload {
	my $error = '';
	my $Asset = openprint::Asset::upload( $_[1], $_[2] );
	if ( ref $Asset eq 'openprint::Asset' ) {
		my $Photo = new openprint::Photo_in_Album({'asset_id'=>$$Asset{'id'},'album_id'=>$_[0]{'id'}});
		if ( ! $Photo->asset_id() ) {
			$error .= $Photo->save({'asset_id'=>$$Asset{'id'}, 'album_id'=>$_[0]->id()});   
			$error .= new openprint::Log()->save({'action'=>'Upload Photo', 'Object'=>$Photo});
		} else {
			$error .= 'Photo already exists in album.';
		} # end if
	} else {
		$error .= "Failed to upload photo: $Asset";
	} # end if
	return $error;
} # end sub upload

sub User {
	return new openprint::User( $_[0]{'user_id'} );
} # end sub User

sub can_edit {
	return 1 if $openprint::session{'user_type'} eq 'A';
	return 1 if $_[0]{'user_id'} == $openprint::session{'user_id'};
} # end sub can_edit

1;
__END__
