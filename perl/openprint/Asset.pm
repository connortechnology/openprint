use strict;

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
	'md5'			=>	'md5',
);
%defaults = (
	'data'		=>	undef,
	'type_id'	=>	undef,
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'created_by'	=>	q`$openprint::session{'user_id'}`,
	'company_id'	=>	q`$openprint::session{'company_id'}`,
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
	return '' if ! $_[0]{'id'};
	return $_[0]{'id'}.'_'.$_[0]{'filename'};
} # end sub on_disk_filename

sub url {
	return '/assets/'.$_[0]->on_disk_filename();
}

sub on_disk_thumbnail_path {
	return '' if ! $_[0]{'id'};
	my $src = $_[0]->on_disk_path();
	if ( ! $src ) {
		$openprint::log->error( "No src for Asset: " . $_[0]->to_string() );
		return '';
	} # end if
$openprint::log->debug("Asset::on_disk_thumbnail_path: $src");
	if ( ! -e $openprint::config{'AssetPath'}.'/thumbnails' ) {
$openprint::log->debug("Asset::on_disk_thumbnail_path: makeing $openprint::config{'AssetPath'}/thumbnails");
		mkdir $openprint::config{'AssetPath'}.'/thumbnails';
		if ( $! ) {
			$openprint::log->error("Unable to create thumbnail path $openprint::config{'AssetPath'}/thumbnails/: $!" );
			return $src;
		} # end if
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
		$openprint::log->debug("Created thumbnail at 75x $dest");
		return $dest;
	} else {
		return $src;
	} # end if
} # end sub on_disk_thumbnail_path

sub thumbnail_filename {
	return '' if ! $_[0]{'id'};
	my $path = $_[0]->on_disk_thumbnail_path();
	my $thumbnail_url;

	if ( my ( $thumbnail_url ) = $path =~ /(\/thumbnails\/.*)$/ ) {
$openprint::log->debug("thumbanil_filename: returning thumb $thumbnail_url");
		return $thumbnail_url;
	} # end if
$openprint::log->debug("thumbanil_filename: returning url $path");
	return $_[0]->url();
} # end sub thumbnail_filename

sub Comments {
	if ( $_[1] ) {
		$_[1]{'object_id'} = $_[0]{'id'};
		$_[1]{'object_type'} = 'openprint::Asset';
		$_[1]{'order'} = 'created_on' if ! $_[1]{'order'};

		return openprint::Comment->find($_[1]);
	} # end if

	if ( ! defined $_[0]{'Comments'} ) {
		@{$_[0]{'Comments'}} = openprint::Comment->find({'object_type'=>'openprint::Asset', 'object_id'=>$_[0]{'id'}, 'order'=>'created_on'});
	} # end if
	return @{$_[0]{'Comments'}};
} # end sub Comments
1;
__END__
