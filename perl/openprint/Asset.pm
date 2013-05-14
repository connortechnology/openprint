use strict;
require openprint;
require openprint::Keyword;
use Fcntl qw(:flock);

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
	'width'			=>	'width',
	'height'		=>	'height',
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
	'width'		=>	undef,
	'height'	=>	undef,
);
%transforms = (
	width			=>	[ 's/\D//g' ],
	height			=>	[ 's/\D//g' ],
	filename		=>	[ 's/^\s+//', 's/\s+$//', 's/ /_/g' ],
	name			=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	description	=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	attribution	=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
	license		=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
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


sub is_video {
	my $extension;
	if ( ref $_[0] eq 'openprint::Asset' ) {
		my $filename = $_[0]->on_disk_filename();
		( $extension ) = $filename =~ /.+\.([^\.]+)$/;
	} else {
		$extension = $_[0];
	} # end if
	return sets::isin( lc $extension, [ '3gp', '3g2', 'asf', 'avi', 'dat', 'divx', 'dsm', 'evo', 'flv', 'm1v', 'm2ts', 'm2v', 'm4a', 'mj2', 'mjpg', 'mjpeg', 'mkv', 'mov', 'moov', 'mp4', 'mpg', 'mpeg', 'mpv', 'nut', 'ogg', 'ogm', 'qt', 'swf', 'ts', 'vob', 'wmv', 'xvid' ] );
} # end sub is_video

sub is_photo {
	my $extension;
	if ( ref $_[0] eq 'openprint::Asset' ) {
		my $filename = $_[0]->on_disk_filename();
		( $extension ) = $filename =~ /.+\.([^\.]+)$/;
	} else {
		$extension = $_[0];
	} # end if
	return sets::isin( lc $extension, [ 'jpg','jpeg','png','gif','bmp' ] );
} # end sub is_photo

sub sized_url {
	my $size = $_[1];

	my $src = $_[0]->on_disk_path();
	my $path = $openprint::config{'AssetPath'}.'/'.$size.'/';
	if ( $openprint::config{'AssetPath'} ) {
		if ( ! -e $path ) {
			mkdir $path;
			$openprint::log->error("Unable to create path $path: $!" );
			return '/images/icons/file.png';
		} # end if
	} # end if

	my $filename = $_[0]->on_disk_filename();
#$openprint::log->debug("Asset:: on_disk_path: $src, Filename: $filename");

	my ( $blah, $extension ) = $filename =~ /(.+)\.([^\.]+)$/;
	if ( is_photo( $extension ) ) {
		if ( $openprint::config{'AssetPath'} ) {
			my $dest = $path.$filename;
			if ( ! -e $dest ) {
				my $width;
				if ( $size eq 'medium' ) {
					$width = $openprint::config{'Medium_Asset_Width'};
				} elsif ( $size eq 'large' ) {
					$width = $openprint::config{'Large_Asset_Width'};
				} # end if
				if ( ! $width ) {
					$openprint::log->error("No asset size in config for $size");
					return '/assets/'.$filename;
				} # end if	
				$openprint::log->debug("Creating $size at ${width} x $src $dest");
				my ( $stderr, $stdout );
				require IPC::Run3;
				IPC::Run3::run3(qq`convert -adaptive-resize ${width}x "$src" "$dest"`, undef, $stdout, $stderr );
				if ( $? ) {
					$openprint::log->error("ERror creating sized image. Reason: ($?) stdout($stdout) stderr($stderr)");
				} # end if convert
			} # end if
		} # end if
#$openprint::log->debug("Return /thumbnails/$filename");
		return '/assets/'.$size.'/'.$filename;
	} elsif ( is_video( $extension ) ) {
		my $fallback = '/images/icons/'. lc $extension. '.png';
		if ( ! -e $openprint::config{SkinPath}.$fallback ) {
			$fallback = '/images/icons/unknown.png';
		} # end if
		if ( $openprint::config{'AssetPath'} ) {
			if ( ! -e $src ) {
				$openprint::log->error("Src file $src no longer exists! Can't make thumbs");
				return $fallback;
			} # end if

			my $dest = $path.$blah.'.jpg';
			if ( ! -e $dest ) {
				my $width;
				if ( $size eq 'medium' ) {
					$width = $openprint::config{'Medium_Asset_Width'};
				} elsif ( $size eq 'large' ) {
					$width = $openprint::config{'Large_Asset_Width'};
				} elsif ( ! $size ) {
					$size = 'full';
				} # end if
				if ( ! $width ) {
					$openprint::log->error("No asset size in config for $size");
				} # end if	
				$openprint::log->debug("Creating $size at ${width}x $src $dest");
				if ( ! -d "/tmp/$filename" ) {
					if ( ! mkdir "/tmp/$filename" ) {
						$openprint::log->error("Unable to create tmp directory at /tmp/$filename/ to hold medium thumbnail: $!" );
						return $fallback;
					} # end if
				} else {
					$openprint::log->debug("Strange, tmp dir /tmp/$filename shouldnt already exist, but it does.");
				} # end if

				$openprint::log->debug("about to mplayer -frames 1 -nosound -quiet -zoom -vf scale=$width:-3 -vo jpeg:outdir=/tmp/$filename/ -ss 60 $src :");
				if ( $width ) {
					$_ = `mplayer -frames 1 -nosound -quiet -zoom -vf scale=$width:-3 -vo jpeg:outdir="/tmp/$filename/" -ss 60 "$src"`;
				} else {
					$_ = `mplayer -frames 1 -nosound -quiet -zoom -vo jpeg:outdir="/tmp/$filename/" -ss 60 "$src"`;
				} # end if
				#$_ = `ffmpeg  -itsoffset -4  -i $src -vcodec mjpeg -vframes 1 -an -f rawvideo -s 320x240 /tmp/$filename/00000001.jpg`;
				if ( $! ) {
					$openprint::log->error("Unable to create medium thumbnail at /tmp/$filename/: $!" );
					return $fallback;
				} else {
					$openprint::log->debug("command was mplayer -frames 1 -nosound -quiet -zoom -vf scale=$width:-3 -vo jpeg:outdir=/tmp/$filename/ -ss 60 $src : $_ ");
				} # end if
				if ( -e "/tmp/$filename/00000001.jpg" ) {
					$openprint::log->debug("Moving /tmp/$filename/0000001.jpg to $dest");
					`mv "/tmp/$filename/00000001.jpg" $dest`;
					if ( $! ) {
						$openprint::log->error("Unable to mv image  $dest: $!" );
						return $fallback;
					} # end if
					unlink "/tmp/$filename/00000001.jpg";
					rmdir "/tmp/$filename";
				} else {
					$openprint::log->error("Unable to create medium thumbnail at /tmp/$filename/: Wasn't there! $!" );
					$openprint::log->debug("command was mplayer -frames 1 -nosound -quiet -zoom -vf scale=$width:-3 -vo jpeg:outdir=/tmp -ss 60 $src : $_ ");
					return $fallback;
				} # end if
			} # end if
		} # end if
		return  '/assets/'.$size.'/'.$blah.'.jpg';
	} else {
		if ( -e $openprint::config{'SkinPath'}.'/images/icons/'.(lc $extension).'png' ) {
			return '/images/icons/'.(lc $extension).'.png';
		} # end if
	} # end if
$openprint::log->error("unknown externsion or somerthitng.  Install icons!! for ($extension)") if $extension;
	return '';
}  # end sub

sub medium_url {
	return sized_url( $_[0], 'medium' );
} # end sub medium_url
sub small_url {
	return sized_url( $_[0], 'small' );
} # end small_url

# Will look for, generate thumbnails, returning the on disk path
sub thumbnail_url {
	my $src = $_[0]->on_disk_path();
	if ( $openprint::config{'AssetPath'} ) {
		if ( ! -e $openprint::config{'AssetPath'}.'/thumbnails/' ) {
			mkdir $openprint::config{'AssetPath'}.'/thumbnails/';
			$openprint::log->error("Unable to create thumbnail path $openprint::config{'AssetPath'}/thumbnails/: $!" );
			return '/images/icons/file.png';
		} # end if
	} # end if

	my $filename = $_[0]->on_disk_filename();
#$openprint::log->debug("Asset:: on_disk_path: $src, Filename: $filename");

	my ( $blah, $extension ) = $filename =~ /(.+)\.([^\.]+)$/;
	if ( sets::isin( lc $extension, [ 'jpg','jpeg','png','gif','bmp' ] ) ) {
		if ( $openprint::config{'AssetPath'} ) {
			my $dest = $openprint::config{'AssetPath'}.'/thumbnails/'.$filename;
			if ( ! -e $dest ) {
				$openprint::log->debug("Creating thumbnail at 75x $src $dest");
				if ( system(qq`convert -adaptive-resize 75x "$src" "$dest"`) ) {
					$openprint::log->error("ERror creating thumbnail. Reason: $1");
				} # end if convert
			} # end if
		} # end if
#$openprint::log->debug("Return /thumbnails/$filename");
		return '/thumbnails/'.$filename;
	} elsif ( sets::isin( lc $extension, [ '3gp', '3g2', 'asf', 'avi', 'dat', 'divx', 'dsm', 'evo', 'flv', 'm1v', 'm2ts', 'm2v', 'm4a', 'mj2', 'mjpg', 'mjpeg', 'mkv', 'mov', 'moov', 'mp4', 'mpg', 'mpeg', 'mpv', 'nut', 'ogg', 'ogm', 'qt', 'swf', 'ts', 'vob', 'wmv', 'xvid' ] ) ) {
		if ( $openprint::config{'AssetPath'} ) {
			my $dest = $openprint::config{'AssetPath'}.'/thumbnails/'.$blah.'.jpg';
			if ( ! -e $dest ) {
				$openprint::log->debug("Creating thumbnail at 75x $src $dest");
				
				$_ = `mplayer -frames 1 -nosound -quiet -zoom -vf scale=75:-3 -vo jpeg:outdir=/tmp -ss 60 $src`;
				if ( $! ) {
					$openprint::log->error("Unable to create thumbnail at $dest: $!" );
					return '/images/icons/image.png';
				} else {
					$openprint::log->debug($_);
				} # end if
				`mv /tmp/00000001.jpg $dest`;
				if ( $! ) {
					$openprint::log->error("Unable to mv thumbnail  $dest: $!" );
					return '/images/icons/image.png';
				} # end if
			} # end if
		} # end if
		return  '/thumbnails/'.$blah.'.jpg';
	} else {
		if ( -e $openprint::config{'SkinPath'}.'/images/icons/'.(lc $extension).'png' ) {
			return '/images/icons/'.(lc $extension).'.png';
		} # end if
	} # end if
$openprint::log->error("unknown externsion or somerthitng.  Install icons!! for ($extension)") if $extension;
	return '/images/icons/file.png';
} # end sub thumbnail_url

sub large_html {
	return '' if ! $_[0]{'id'};
	return sprintf('<img src="%1$s" alt="%2$s" title="%2$s" />', $_[0]->sized_url('large'), $_[0]->name() );
} # end sub large_html
sub medium_html {
	return '' if ! $_[0]{'id'};
	my $options = join(' ', map { qq`$_="$_[1]{$_}"` } keys %{$_[1]} ) if $_[1];
	return sprintf('<img src="%1$s" alt="%2$s" title="%2$s" %3$s/>', $_[0]->medium_url(), $_[0]->name(), $options );
} # end sub medium_html

sub html {
	return '' if ! $_[0]{'id'};
	return sprintf('<img src="%1$s" alt="%2$s" title="%2$s" />', $_[0]->url(), $_[0]->name() );
} # end sub html
sub thumbnail_html {
	return '' if ! $_[0]{'id'};
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
sub medium_path {
	my $url = $_[0]->medium_url();
	$url =~ s/^\/assets//;
	return $openprint::config{'AssetPath'}.$url;
} # end sub medium_path
sub large_path {
	my $url = $_[0]->sized_url('large');
	$url =~ s/^\/assets//;
	return $openprint::config{'AssetPath'}.$url;
} # end sub medium_path

sub sized_path {
	my $url = $_[0]->sized_url($_[1]);
	$url =~ s/^\/assets//;
	return $openprint::config{'AssetPath'}.$url;
} # end sub sized_path

sub md5 {
	if ( @_ > 1 ) {
		$_[0]{'md5'} = $_[1];
	} # end if
	if ( ( ! $_[0]{'md5'} ) and $_[0]{'data'} ) {
		require Digest::MD5;
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

sub fetch {
	my ( $url ) = @_;

	require LWP::UserAgent;
	require HTTP::Request;

	my $ua = LWP::UserAgent->new;
	$ua->agent("IQ/0.1 ");
# Create a request
	my $req = HTTP::Request->new( GET => $url );
# Pass request to the user agent and get a response back
	my $res = $ua->request($req);
# Check the outcome of the response
	if (! $res->is_success) {
		$openprint::log->debug("No success.");
		return "Failed to get file. URL($url)<br/>";
	} # end if

	require URI;
	require File::Basename;
	require File::Slurp;

	my $URI = URI->new($url);
	my $path = $URI->path();
	my $filename = File::Basename::basename( $path );
$openprint::log->debug("fetch: filename: $filename path: $path from url $url");
	if ( ! $filename ) {
		return "Unable to determine filename from $url";
	} # endi f
		
	require Digest::MD5;
	my $data;
	my $md5 = Digest::MD5::md5_base64( $res->content );
	if ( ! $md5 ) {
		return "Unable to MD5?";
	#} else {
		#$openprint::log->debug("MD5 was $md5");
	} # end if
	my $Asset = openprint::Asset->find_one( md5 => $md5 );
	if ( ! $Asset ) {
		$Asset = new openprint::Asset();
		$! .= $Asset->save({ filename=>$filename, md5=>$md5 });

		if ( ! File::Slurp::write_file($Asset->on_disk_path(), { atomic => 1, err_mode=>'carp' }, $res->content ) ) {
			return 'There was an error saving file ' . $filename.' to ' . $Asset->on_disk_path() . ": $!<br/>";
		} # end if

		$_ = $Asset->save();
		return $_ if $_;
	} else {
		if ( ! -e $Asset->on_disk_path() ) {
			if ( ! File::Slurp::write_file($Asset->on_disk_path(), { atomic => 1, err_mode=>'carp' }, $res->content ) ) {
				return 'There was an error saving file ' . $filename.' to ' . $Asset->on_disk_path() . ": $!<br/>";
			} # end if
		} # end if
	} # end if
	return $Asset;
} # end sub fetch

# What gets passed in the form element name
sub upload {
	my $upload = $openprint::r->upload($_[0]);
	if ( ! $upload ) {
		return "There was no upload for $_[0]<br/>";
	} # end if
	require Digest::MD5;
	my $data;
	$upload->slurp( $data );
	my $md5 = Digest::MD5::md5_base64( $data );
	if ( ! $md5 ) {
		return "Unable to MD5?";
	} else {
		$openprint::log->debug("MD5 was $md5");
	} # end if
	my $Asset = openprint::Asset->find_one( md5 =>$md5);
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
	if ( ! $_[0]{width} ) {
		require Image::Size;
		if ( $_[0]->is_video() ) {
			# get the image size, and print it out
			my $url = $_[0]->sized_url('full');
			$url =~ s/^\/assets//;
			my ( $w, $h, $e ) = Image::Size::imgsize( $openprint::config{AssetPath}.$url );
			if ( ! ( $w and $h ) ) {
				$openprint::log->error("imagesize aerrror $e ");
			} else {
			@{$_[0]}{'width','height'} = ( $w, $h );
			} # end if
$openprint::log->debug("Getting size for video: " . $_[0]->sized_url('full') . " got $_[0]{width}x$_[0]{height}");

		} else {
# get the image size, and print it out
			@{$_[0]}{'width','height'} = Image::Size::imgsize( $_[0]->on_disk_path() );
		} # end if
	} # end if
	return $_[0]{width};
} # end sub width

sub height {
	if ( ! $_[0]{'height'} ) {
		require Image::Size;
		if ( $_[0]->is_video() ) {
			# get the image size, and print it out
			@{$_[0]}{'width','height'} = Image::Size::imgsize( $openprint::config{AssetPath}.$_[0]->sized_url('full') );
		} else {
			# get the image size, and print it out
			@{$_[0]}{'width','height'} = Image::Size::imgsize( $_[0]->on_disk_path() );
		} # end if
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

sub video_url {
	my ( $self, $type ) = @_;
$openprint::log->debug("Calling video_url($type)");
	my $path = $openprint::config{'AssetPath'}.'/videos/';
	if ( $openprint::config{'AssetPath'} ) {
		if ( ! -e $path ) {
			mkdir $path;
			$openprint::log->error("Unable to create path $path: $!" );
			return '/images/icons/file.png';
		} # end if
	} # end if
	my $filename = $_[0]->on_disk_filename();
	my ( $base, $extension ) = $filename =~ /(.+)\.([^\.]+)$/;
	if ( ! is_video( $extension ) ) {
		$openprint::log->error("Called video_url on as asset that is not a video. " . $_[0]->to_string() );
		return;
	} # end if
	my $dest = $path.$base.'.'.$type;
	$self->generate_video( $type );
	return '/assets/videos/'.$base.'.'.$type;
} # end sub video_url

sub video_path( $$ ) {
	my ( $self, $type ) = @_;
	my $filename = $_[0]->on_disk_filename();
	my ( $base, $extension ) = $filename =~ /(.+)\.([^\.]+)$/;
	if ( ! is_video( $extension ) ) {
		$openprint::log->error("Called video_path on as asset that is not a video. " . $_[0]->to_string() );
		return;
	} # end if
	return $openprint::config{AssetPath}.'/videos/'.$base.'.'.$type;
} # end sub video_path

sub generate_video {
	my ( $self, $type ) = @_;
	my $dest = $self->video_path($type);
	my $lock;
	if ( ! open($lock, "> $dest.lck") ) {
		$openprint::log->error("Unable to open semaphore at $dest.lck\n");
		return;
	} # end if
	if ( ! flock($lock, Fcntl::LOCK_EX) ) {
		$openprint::log->error("Unable to lock semaphore\n");
	} # end if
	if ( ! -e $dest ) {
		# Create it
		my $src  = $_[0]->on_disk_path();
		my ( $base, $extension ) = $src =~ /\/([^\/]+)\.([^\.]+)$/;
		if ( $type eq 'mp4' ) {
			my $output = `avconv -i $src -threads 2 -vcodec libx264 -b 1500k -pre:v baseline -g 30 -f mp4 $dest.part`;
			$openprint::log->debug("avconv -i $src -threads 2 -vcodec libx264 -b 1500k -pre:v baseline -g 30 -f mp4 $dest: $output");
			if ( ! -e "$dest.part" ) {
				$openprint::log->debug("avconv didn't do it's thing.");
			} # end if
			`qt-faststart $dest.part $dest`;
			unlink "$dest.part";
		} elsif ( $type eq 'ogg' ) {
			`avconv -i $src -vcodec libtheora -b 1500k -acodec libvorbis -ab 160000 -g 30 -f ogg $dest.part`;
			`mv $dest.part $dest`;
		} elsif ( $type eq 'webm' ) {
		`avconv -i $src -vcodec libvpx -b 1500k -acodec libvorbis -ab 160000 -f webm $dest.part`;
			`mv $dest.part $dest`;
		} else {
			$openprint::log->error("Unknown type in video_url $type");
		} # end if type
	} # end if ! -e $dest
	close($lock);
	unlink $dest.'.lck';
	return $dest;
} # end sub generate_video

sub content_type {
	my $src = @_ > 1 ? $_[1] : $_[0]->on_disk_path();
	my ( $base, $extension ) = $src =~ /([^\/]+)\.([^\.]+)$/;
	if ( $extension eq 'mp4' ) {
		$openprint::log->error('content type for ' . $src . ' ext:' . $extension);
		return 'video/mp4';
	} elsif ( $extension eq 'ogg' ) {
		return 'video/ogg';
	} elsif ( $extension eq 'webm' ) {
		return 'video/webm';
	} elsif ( $extension eq 'avi' ) {
		return 'video/avi';
	} else {
		$openprint::log->error('unimplemented content type for ' . $src . ' ext:' . $extension);
	} # end if
} # end sub content_type
1;
__END__
