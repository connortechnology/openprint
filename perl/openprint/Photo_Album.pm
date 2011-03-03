use strict;
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
	'user_id'		=>	q`$openprint::session{'user_id'}`,
	'deleted'		=>	0,
);


sub Thumbnail {
	if ( ! $_[0]{'thumbnail_id'} ) {
		my @Photos = $_[0]->Photos();
		return $Photos[0] if @Photos;
	} # end if
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
	foreach my $Photo ( $_[0]->Photos() ) {
		$Photo->destroy();
	} # end foreach Photo
} # end sub delete

1;
__END__
