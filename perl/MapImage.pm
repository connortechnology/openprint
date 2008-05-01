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
	my $output_path = join('/', $path, $Location->parent()->name());
	if ( ! -e join('/', $path, $Location->parent()->name().'.png') ) {
		$r->log->debug("No template at " . join('/', $path, $Location->parent()->name().'.png') );
		return;
	} # en dif
		
	$image->Read(join('/', $path, $Location->parent()->name().'.png'));
	$r->log->debug("$output_path");
	if ( ! -e $output_path ) {
		$r->log->debug("makeing $output_path");
		if ( ! mkdir $output_path ) {
			$r->log->error("Unable to mkdir $output_path");
			return;
		}
	}
	$r->log->debug("Drawing location");
	$image->Draw(stroke=>'red', primitive=>'rectangle', points=>join(',',map{$_-1} split(',',$Location->coordinates())));
	my $e = $image->Write( join('/', $path, $Location->parent()->name(),$Location->name().'.png' ) );
	$r->log->error($e) if $e;
} # end sub create_image

sub handler {
# this module just generates barcodes
	my $request = shift;
	$r = Apache2::Request->new( $request );
	$r->content_type('image/png');
	$dbh = sql::open_sql( $log, 
			'database'	=> $r->dir_config('db_name'),
			'driver'	=> $r->dir_config('db_driver'), 
			'host'		=> $r->dir_config('db_host'),
			'login'		=> $r->dir_config('db_user'),
			'password'	=> $r->dir_config('db_password'),
			);

	my @path = split('/', $r->filename);
	my $filename = pop @path;
	my $template = pop @path;
	my $path = join('/', @path);

	my ( $selected ) = $filename =~ /^(.*).png$/;
	$r->log->debug("Path: ".$r->filename." Filename: $filename, selected: $selected");
	if ( ! $selected ) {
		if ( ! -e $r->filename ) {
	$r->log->debug("Trying to make " . $r->filename );
			if ( ! mkdir $r->filename ) {
				$r->log->error("Unable to mkdir ".$r->filename . ':' . $!);
			}
			return;
		}
	}
		
	my @Locations = openprint::Location::find('name'=>$selected);
	if ( @Locations and $Locations[0]->parent_id() ) {
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

	return Apache2::Const::OK;
} # end sub handler

1;

__END__
