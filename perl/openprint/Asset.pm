use strict;
require Digest::MD5;

package openprint::Asset_Type;
our @ISA = qw(openprint::Object);
use vars qw( $debug %fields %transforms %defaults $table $serial );
$debug = 1;
$table = 'asset_types';
$serial = 'asset_types_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
);

package openprint::Asset;
our @ISA = qw(openprint::Object);

use vars qw( $debug %fields %transforms %defaults $table $serial );

$debug = 1;

%fields = (
	'id'			=>	'id',
	'company_id'	=>	'company_id',
	'created_by'	=>	'created_by',
	'type_id'		=>	'type_id',
	'name'			=>	'name',
	'description'	=>	'description',
	'filename'		=>	'filename',
	'data'			=>	'data',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'deleted'		=>	'deleted',
	'md5'			=>	'md5',
);
%defaults = (
	'data'		=>	undef,
	'type_id'	=>	undef,
	'md5'		=>	undef,
	'deleted'	=>	0,
);
%transforms = (
	'filename' => [ 's/^\s+//', 's/\s+$//', 's/ /_/g' ],
);
$table = 'assets';
$serial = 'assets_id_seq';

sub Type {
	return new openprint::Asset_Type( $_[0]{'type_id'} );
} # end sub Type

sub on_disk_path {
	return $openprint::config{'AssetPath'}.'/'.$_[0]->on_disk_filename();
} # end sub on_disk_path
sub on_disk_filename {
	return $_[0]{'id'}.'_'.$_[0]{'filename'};
} # end sub on_disk_filename
sub on_disk_thumbnail_path {
	my $src = $_[0]->on_disk_path();
	if ( ! -e $openprint::config{'AssetPath'}.'/thumbnails/' ) {
		mkdir $openprint::config{'AssetPath'}.'/thumbnails/';
		$openprint::log->error("Unable to create thumbnail path $openprint::config{'AssetPath'}/thumbnails/: $!" );
		return $src;
	} # end if
	my $dest = $openprint::config{'AssetPath'}.'/thumbnails/'.$_[0]->on_disk_filename();
    my ( $blah, $extension ) = $dest =~ /(.+)\.([^\.]+)$/;
	if ( sets::isin( lc $extension, [ 'jpg','jpeg','png','gif' ] ) ) {
		if ( ! -e $dest ) {
			$openprint::log->debug("Creating thumbnail at 75x $src $dest");
			`convert  -adaptive-resize 75x $src $dest`;
		} # end if
	} elsif ( sets::isin( lc $extension, [ '3gp', '3g2', 'asf', 'avi', 'dat', 'divx', 'dsm', 'evo', 'flv', 'm1v', 'm2ts', 'm2v', 'm4a', 'mj2', 'mjpg', 'mjpeg', 'mkv', 'mov', 'moov', 'mp4', 'mpg', 'mpeg', 'mpv', 'nut', 'ogg', 'ogm', 'qt', 'swf', 'ts', 'vob', 'wmv', 'xvid' ] ) ) {
		$dest = $blah.'.jpg';
		if ( ! -e $dest ) {
			$openprint::log->debug("Creating thumbnail at 75x $src $dest");
			`mplayer -frames 1 -nosound -quiet -zoom -vf scale=75:-3 -vo jpeg:outdir=/tmp -ss 60 $src`;
			`mv /tmp/00000001.jpg $dest`;
			if ( $! ) {
				$openprint::log->error("Unable to create thumbnail at $dest: $!" );
				return $src;
			} # end if
		} # end if
	} # end if

	if ( -e $dest ) {
		return $dest;
	} else {
		return $src;
	} # end if
} # end sub on_disk_thumbnail_path
sub thumbnail_filename {
	my $path = $_[0]->on_disk_thumbnail_path();
	if ( $path =~ /thumbnails/ ) {
		return 'thumbnails/'.$_[0]->on_disk_filename();
	} # end if
	return $_[0]->on_disk_filename();
} # end sub thumbnail_filename
sub url {
	return '/assets/'.$_[0]->on_disk_filename();
} # end sub url
sub thumbnail_url {
	return '/'.$_[0]->thumbnail_filename();
} # end sub thumbnail_url
sub md5 {
	if ( @_ > 1 ) {
		$_[0]{'md5'} = $_[1];
	} # end if
	if ( ( ! $_[0]{'md5'} ) and $_[0]{'data'} ) {
		$_[0]{'md5'} = Digest::MD5::md5_base64( $_[0]{'data'} );
	} # end if
	return $_[0]{'md5'};	
} # end sub md5

sub can_delete {
	return 1 if $_[0]{'created_by'} == $openprint::session{'user_id'};
	return 0;
} # end sub can_delete
sub can_approve {
	return 1 if $_[0]{'created_by'} == $openprint::session{'user_id'};
	return 0;
} # end sub can_approve {

sub destroy {
	foreach ( openprint::SRED_Asset->find('asset_id'=>$_[0]{'id'}) ) {
		$_->destroy();
	} # end foreach SRED_Asset
	foreach ( openprint::Claim_Asset->find('asset_id'=>$_[0]{'id'}) ) {
		$_->destroy();
	} # end foreach Claim_Asset
	unlink $_[0]->on_disk_thumbnail_path();
	unlink $_[0]->on_disk_path();
	sql::execute( undef, undef, 'DELETE FROM Assets WHERE id=?', $_[0]{'id'} );
} # end sub destroy


1;
__END__
