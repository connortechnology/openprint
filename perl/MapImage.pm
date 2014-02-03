package MapImage;

use Apache2::Request;    # instead of CGI, it's MUCH faster, and does nice things.
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(OK);# Offers OK, Error,etc for web server.
use Apache2::Log;
use Apache2::ServerUtil ();
use Apache2::RequestIO ();

use Image::Magick;

use strict;
use openprint;
use vars qw( $r %variable %session %param %config $log $dbh );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*r = \$openprint::r;

sub create_image {
	my ($path, $Location) = @_;

	my $image = new Image::Magick;
	if ( ! -e join('/', $path, $Location->Parent()->name().'.gif') ) {
		$r->log->debug("No template at " . join('/', $path, $Location->Parent()->name().'.gif') );
		return;
	} # en dif
	$image->Read(join('/', $path, $Location->Parent()->name().'.gif'));

	my $output_path = join('/', $path, $Location->Parent()->name());
	if ( ! -e $output_path ) {
		$r->log->debug("makeing $output_path");
		if ( ! mkdir $output_path ) {
			$r->log->error("Unable to mkdir $output_path $!");
			return;
		}
	}
	$r->log->debug("Drawing location");
	$image->Draw(stroke=>'red', primitive=>'rectangle', points=>join(',',map{$_-1} split(',',$Location->coordinates())));
	my $e = $image->Write( join('/', $path, $Location->Parent()->name(),$Location->name().'.gif' ) );
	$r->log->error($e) if $e;
	undef $image;
} # end sub create_image

sub handler {
# this module just generates barcodes
	my $request = shift;
	$r = Apache2::Request->new( $request );
	$r->content_type('image/gif');
	$r->no_cache(1);
	$log = $r->log;
	$dbh = sql::open_sql( $log, 
			'database'	=> $r->dir_config('db_name'),
			'driver'	=> $r->dir_config('db_driver'), 
			'host'		=> $r->dir_config('db_host'),
			'login'		=> $r->dir_config('db_user'),
			'password'	=> $r->dir_config('db_password'),
			);

	my @path = split('/', $r->filename);
	my $filename = pop @path;

	my ( $selected ) = $filename =~ /^(.*).gif$/;
	if ( $selected eq 'map' ) {
		my $path = join('/', @path );
		my $location_id = $r->param('location_id');
		my $Location = new openprint::Location( $location_id );
$r->log->debug( "Location: " . $Location->name() . ':' . $Location->coordinates() );
		my $l_level = 0;
		my $P = $Location;
		while ( $P->parent_id() ) {
			$P = $P->Parent();
			$l_level += 1;
		} # end while 

		my $level = $r->param('level');
		$level = 1 if ! $level;
		$level = $l_level if $level > $l_level;

		my $Root = $Location;
		while ( $level <= $l_level ) {
			last if ! $Root->Parent();
			$Root = $Root->Parent();
			$level += 1;
		} # end while
		
		my $image = new Image::Magick;
		if ( ! -e join('/', $path, $Root->name().'.gif') ) {
			$r->log->debug("No template at " . join('/', $path, $Root->name().'.gif') );
			return;
		} # end if
		$image->Read(join('/', $path, $Root->name().'.gif'));

		my @coordinates = split( ',', $Location->coordinates() );
		my ( $lx1,$ly1,$lx2,$ly2) = @coordinates;

		my $L = $Location;
		
		while ( $L->parent_id() and ( $L->parent_id() != $Root->id() ) ) {
			my @c2;

			my $P = $L->Parent();

			my $pi = new Image::Magick;
			$pi->Read(join('/', $path, $P->Parent()->name().'.gif'));
			$log->debug("Scaling from: " . $P->name() . ' to ' . $P->Parent()->name() );
			my ( $pw, $ph ) = $pi->Get( 'width','height' );
			#my ( $px1, $py1, $px2, $py2 ) = split(',', $P->coordinates() );
			my ( $x1, $y1, $x2, $y2 ) = split(',', $P->coordinates() );

			#$r->log->debug("Scaling ( ($x2-$x1) / $pw ) x ( ($y2-$y1) / $ph )");
			my $x_ratio = ($x2-$x1)/$pw;
			my $y_ratio = ($y2-$y1)/$ph;
			#$r->log->debug("Scaling to ($x1,$py1)x($px2,$py2)->($x1,$y1)x($x2,$y2)");

			$log->debug(sprintf('Scaling box to (%d,%d)->(%d,%d)', $x1, $y1, $x1*$x_ratio, $y1*$y_ratio) );
			$log->debug(sprintf('Scaling highlight to (%d,%d)x(%d,%d)->(%d,%d)x(%d,%d)', $lx1, $ly1, $lx2,$ly2, $lx1*$x_ratio, $ly1*$y_ratio, $lx2*$x_ratio, $ly2*$y_ratio) );
			$lx1 = sprintf('%.0f', $lx1*$x_ratio );
			$ly1 = sprintf('%.0f', $ly1*$y_ratio );
			$lx2 = sprintf('%.0f', $lx2*$x_ratio );
			$ly2 = sprintf('%.0f', $ly2*$y_ratio );
			$x1 = sprintf('%.0f', $x1*$x_ratio );
			$y1 = sprintf('%.0f', $y1*$y_ratio );

			$lx1 += $x1;
			$lx2 += $y1;
			$ly1 += $x1;
			$ly2 += $y1;
			#$r->log->debug("Scaling to ($px1,$py1)x($px2,$py2)->($x1,$y1)x($x2,$y2)");

			$L =  $L->Parent();
		} # end while
			@coordinates = map { $_ < 1 ? 1 : $_ } ( $lx1, $ly1, $lx2, $ly2 );
#$r->log->debug("Drawing Coordinates: " . join(',', @coordinates ) );

		$image->Draw(stroke=>'red', primitive=>'rectangle', points=>join(',', map{$_-1} @coordinates));
		if ( $r->param('width') and $r->param('height') ) {
		$image->Resize( geometry=>sprintf('%dx%d', $r->param('width'), $r->param('height') ), blur=>1,filter=>'Cubic' );
		} elsif ( $r->param('width') ) {
		$image->Resize( geometry=>$r->param('width'), filter=>'Cubic' );
		} 
		print $image->ImageToBlob();
		undef $image;

	} else {
		$log->debug("Path: ".$r->filename." Filename: $filename, selected: $selected");
		if ( ! $selected ) {
			if ( ! -e $r->filename ) {
		$log->debug("Trying to make " . $r->filename );
				if ( ! mkdir $r->filename ) {
					$r->log->error("Unable to mkdir ".$r->filename . ':' . $!);
				}
				return;
			}
		}
		
		my @Locations = openprint::Location->find('name'=>$selected);
		if ( @Locations and $Locations[0]->parent_id() ) {
			pop @path;
			my $path = join('/', @path );
			my $Location = $Locations[0];

			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks);
			if ( ! -e $r->filename ) {
				create_image( $path, $Location );
			} else {
		$r->log->debug("Stat");
				($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($r->filename);
				my $updated_on = Date::Parse::str2time($Location->updated_on());
		$r->log->debug("Stat: $mtime <=> $updated_on"  );
				if ( ! $updated_on or ( $mtime < $updated_on) ) {
					create_image( $path, $Location );
				} # end if image is older than data
			} # end if file exists
		} # end if
#$r->send_http_header();
		$r->sendfile( $r->filename );
	} # end if

	return Apache2::Const::OK;
} # end sub handler

1;

__END__
