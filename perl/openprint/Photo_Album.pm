use strict;
require openprint::Asset;
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
);

%defaults = (
	'created_on'	=> q`'NOW()'`,
	'thumbnail_id'	=>	undef,
	'user_id'		=>	q`$openprint::session{'user_id'}`,
);

sub thumbnail_url {
	# if no thumbnail set, then choose randomal
	if ( ! $_[0]{'thumbnail_id'} ) {
		my @Photos = $_[0]->Photos();
		return $Photos[0]->thumbnail_url() if @Photos;
	} # end if
} # end sub thumbnail_url

sub Photos {
	return map { $_->Asset() } openprint::Photos_in_Albums->find('album_id'=>$_[0]{'id'});
} # end sub Photos

package openprint::Photos_in_Albums;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table %fields %transforms %defaults @identified_by );
$debug = 1;
$table = 'photos_in_albums';
%fields = (
	'album_id'	=>	'album_id',
	'asset_id'	=>	'asset_id',
);

@identified_by = ( 'album_id','asset_id' );

1;
__END__
