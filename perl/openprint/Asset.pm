use strict;
require openprint;
require Digest::MD5;
require openprint::Keyword;

require Image::Size;

package openprint::Asset_Type;
our @ISA = qw(openprint::Object);
use vars qw( $debug %fields %transforms %defaults $table $serial );
$debug = 0;
$table = 'asset_types';
$serial = 'asset_types_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
);

package openprint::Asset;
our @ISA = qw(openprint::Object);

use vars qw( $debug %fields %transforms %defaults $table $serial );

$debug = 0;

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
	'attribution'	=>	'attribution',
	'license'		=>	'license',
	'keywords'		=>	undef,
	'optimised'		=>	'optimised',
	'layout'		=>	'layout',
);
%defaults = (
	'data'		=>	undef,
	'type_id'	=>	undef,
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'created_by'	=>	q`$openprint::session{'user_id'}`,
	'company_id'	=>	q`$openprint::session{'company_id'}`,
	'md5'		=>	undef,
	'deleted'	=>	0,
	'optimised'	=>	0,
	'layout'	=>	'',
);
%transforms = (
	'filename'		=>	[ 's/^\s+//', 's/\s+$//', 's/ /_/g' ],
	'name'			=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	'description'	=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	'attribution'	=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	'license'		=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
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

# Will look for, generate thumbnails, returning the on disk path
sub thumbnail_url {
	my $src = $_[0]->on_disk_path();
	if ( ! -e $openprint::config{'AssetPath'}.'/thumbnails/' ) {
		mkdir $openprint::config{'AssetPath'}.'/thumbnails/';
		$openprint::log->error("Unable to create thumbnail path $openprint::config{'AssetPath'}/thumbnails/: $!" );
		return '/images/icons/file.png';
	} # end if

	my $filename = $_[0]->on_disk_filename();
#$openprint::log->debug("Asset:: on_disk_path: $src, Filename: $filename");

	my ( $blah, $extension ) = $filename =~ /(.+)\.([^\.]+)$/;
	if ( sets::isin( lc $extension, [ 'jpg','jpeg','png','gif','bmp' ] ) ) {
		my $dest = $openprint::config{'AssetPath'}.'/thumbnails/'.$filename;
		if ( ! -e $dest ) {
			$openprint::log->debug("Creating thumbnail at 75x $src $dest");
			if ( system(qq`convert -adaptive-resize 75x "$src" "$dest"`) ) {
				$openprint::log->error("ERror creating thumbnail. Reason: $1");
			} # end if convert
		} # end if
#$openprint::log->debug("Return /thumbnails/$filename");
		return '/thumbnails/'.$filename;
	} elsif ( sets::isin( lc $extension, [ '3gp', '3g2', 'asf', 'avi', 'dat', 'divx', 'dsm', 'evo', 'flv', 'm1v', 'm2ts', 'm2v', 'm4a', 'mj2', 'mjpg', 'mjpeg', 'mkv', 'mov', 'moov', 'mp4', 'mpg', 'mpeg', 'mpv', 'nut', 'ogg', 'ogm', 'qt', 'swf', 'ts', 'vob', 'wmv', 'xvid' ] ) ) {
		my $dest = $openprint::config{'AssetPath'}.'/thumbnails/'.$blah.'.jpg';
		if ( ! -e $dest ) {
			#$openprint::log->debug("Creating thumbnail at 75x $src $dest");
			`mplayer -frames 1 -nosound -quiet -zoom -vf scale=75:-3 -vo jpeg:outdir=/tmp -ss 60 $src`;
			`mv /tmp/00000001.jpg $dest`;
			if ( $! ) {
				$openprint::log->error("Unable to create thumbnail at $dest: $!" );
				return '/images/icons/image.png';
			} # end if
		} # end if
		return  '/thumbnails/'.$blah.'.jpg';
	} else {
		if ( -e $openprint::config{'SkinPath'}.'/images/icons/'.(lc $extension).'png' ) {
			return '/images/icons/'.(lc $extension).'.png';
		} # end if
	} # end if
$openprint::log->error("unknown externsion or somerthitng.  Install icons!! for ($extension)");
	return '/images/icons/file.png';
} # end sub thumbnail_url

sub thumbnail_html {
	return sprintf('<img src="%1$s" alt="%2$s" title="%2$s" />', $_[0]->thumbnail_url(), $_[0]->name() );
} # end sub thumbnail_html

sub thumbnail_path {
	my $url = $_[0]->thumbnail_url();
	if ( $url =~ /^\/thumbnails/ ) {
		return $openprint::config{'AssetPath'}.$url;
	} else {
		return $openprint::config{'SkinPath'}.$url;
	} # end if
} # end sub thumbnail_path

sub md5 {
	if ( @_ > 1 ) {
		$_[0]{'md5'} = $_[1];
	} # end if
	if ( ( ! $_[0]{'md5'} ) and $_[0]{'data'} ) {
		$_[0]{'md5'} = Digest::MD5::md5_base64( $_[0]{'data'} );
	} # end if
	return $_[0]{'md5'};	
} # end sub md5

sub can_edit {
	return 1 if $_[0]{'created_by'} == $openprint::session{'user_id'};
	return 0;
} # end sub can_edit

sub can_view {
	my @Albums = openprint::Photo_in_Album->find('asset_id'=>$_[0]{'id'});
	return 1 if ! @Albums;
	foreach my $Album ( @Albums ) {
		return 1 if $Album->can_view();
	} # end foreach
	return 0;
} # end sub can_view

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

# What gets passed in the form element name
sub upload {
	my $upload = $openprint::r->upload($_[0]);
	if ( ! $upload ) {
		return "There was no upload for $_[0]<br/>";
	} # end if
	my $data;
	$upload->slurp( $data );
	my $md5 = Digest::MD5::md5_base64( $data );
	if ( ! $md5 ) {
		return "Unable to MD5?";
	} # end if
	my $Asset = openprint::Asset->find_one('md5'=>$md5);
	if ( ! $Asset ) {
		$Asset = new openprint::Asset();
		$! .= $Asset->save({'filename'=>$upload->filename(),'md5'=>$md5});
		if ( ! $upload->link( $Asset->on_disk_path() ) ) {
			return 'There was an error saving file ' . $upload->filename().' to ' . $Asset->on_disk_path() . ": $!<br/>";
		} # end if
		if ( ( @_ > 1 ) and $_[1] ) {
			# Should be a hash of more attribute
			$Asset->save($_[1]);
		} # end if
	} else {
		if ( ! -e $Asset->on_disk_path() ) {
			if ( ! $upload->link( $Asset->on_disk_path() ) ) {
				return 'There was an error saving file ' . $upload->filename().' to ' . $Asset->on_disk_path() . ": $!<br/>";
			} # end if
		} # end if
	} # end if
	return $Asset;
} # end sub upload

sub Keywords {
	if ( ! $_[0]{'Keywords'} ) {
		@{$_[0]{'Keywords'}} = openprint::Object_Keyword->find( 'object_type'=>'Asset', 'object_id'=>$_[0]->id() );
	} # end if
	return @{$_[0]{'Keywords'}};
} # end sub Keywords

sub keywords {
	if ( @_ > 1 and ( $_[1] ne $_[0]->keywords() ) ) {
		foreach my $word ( split( ' ', $_[1] ) ) {
			my $Keyword = openprint::Keyword->find_one('word lc'=>lc openprint::Keyword->transform('word', $word));
			if ( ! $Keyword ) {
				$Keyword = new openprint::Keyword();
				$Keyword->save({ 'word'=>$word });
			} # end if ! Keyword

			my $OK = openprint::Object_Keyword->find_one( 'keyword_id'=>$Keyword->id(), 'object_type'=>'Asset', 'object_id'=>$_[0]{'id'} );
			if ( ! $OK ) {
				$OK = new openprint::Object_Keyword();
				$OK->save({'keyword_id'=>$Keyword->id(), 'object_type'=>'Asset', 'object_id'=>$_[0]{'id'} });
			} # end if
		} # end foreach
		@{$_[0]{'Keywords'}} = openprint::Object_Keyword->find( 'object_type'=>'Asset', 'object_id'=>$_[0]->id() );
		$_[0]{'keywords'} = undef;
	} # end if
	if ( ! $_[0]{'keywords'} ) {
		$_[0]{'keywords'} = join(' ', map { $_->word() } $_[0]->Keywords() );
	} # end if
	return $_[0]{'keywords'};
} # end sub keywords
sub caption {
	if ( $_[0]{'name'} ) {
		return $_[0]{'name'};
	} # end if
	if ( $_[0]{'filename'} ) {
		return $_[0]{'filename'};
	} # end if
} # end sub caption

sub width {
	if ( ! $_[0]{'width'} ) {
# get the image size, and print it out
		@{$_[0]}{'width','height'} = Image::Size::imgsize( $_[0]->on_disk_path() );
	} # end if
	return $_[0]{'width'};
} # end sub width

sub height {
	if ( ! $_[0]{'height'} ) {
# get the image size, and print it out
		@{$_[0]}{'width','height'} = Image::Size::imgsize( $_[0]->on_disk_path() );
	} # end if
	return $_[0]{'height'};
} # end sub height

sub layout {
	if ( ! $_[0]{'layout'} ) {
		if ( $_[0]->width() > $_[0]->height() ) {
			$_[0]{'layout'} = 'Landscape';
		} else {
			$_[0]{'layout'} = 'Portrait';
		} # end if
	} # end if
	return $_[0]{'layout'};
} # end sub layout

1;
__END__
