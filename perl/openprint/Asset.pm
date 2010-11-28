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
);
%defaults = (
	'data'		=>	undef,
	'type_id'	=>	undef,
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
	if ( ! -e $dest ) {
		`convert  -adaptive-resize 75x $src $dest`;
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

1;
__END__
