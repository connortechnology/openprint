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
	'user_id'		=>	q`$openprint::session{'user_id'}`,
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
	foreach my $Photo ( $_[0]->Photos() ) {
		$Photo->destroy();
	} # end foreach Photo
} # end sub delete

sub upload {
	my $filename = $openprint::param{$_[1]};
	my $upload = $openprint::r->upload($_[1]);
	if ( ! $upload ) {
		return "There was no upload for $filename<br/>";
	} # end if
	my $data;
	$upload->slurp( $data );
	my $md5 = Digest::MD5::md5_hex( $data );
$openprint::log->debug("MD5: $md5");
	foreach my $Photo ( $_[0]->Photos() ) {
		if ( $md5 eq $Photo->Asset()->md5() ) {
			return "Photo already exists in album.<br/>";
		} else {
			$openprint::log->debug("Photos md5: " . $Photo->Asset()->md5() );
		} # end if
	} # end foreach
	my $error;
	my $Asset = new openprint::Asset();
	$error .= $Asset->save({'filename'=>$filename, 'md5'=>$md5});
	if ( ! $upload->link( $Asset->on_disk_path() ) ) {
		$error .= "There was an error saving file $filename to " . $Asset->on_disk_path() . ": $!<br/>";
	} else {
		my $data = misc::load_file( $openprint::log, $Asset->on_disk_path() );
		my $Photo = new openprint::Photo_in_Album();
		$error .= $Photo->save({'asset_id'=>$Asset->id(), 'album_id'=>$_[0]->id()});
	} # end if
	return $error;
} # end sub upload
1;
__END__
