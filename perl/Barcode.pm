package Barcode;

use Apache2::Request;    # instead of CGI, it's MUCH faster, and does nice things.
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(OK);# Offers OK, Error,etc for web server.
use Apache2::Log;
use Apache2::ServerUtil ();
use Apache2::RequestIO ();

use GD::Barcode::UPCE;
use GD::Barcode;
use Barcode::Code128;
use Image::Magick;

use strict;

sub handler {
	# this module just generates barcodes
	my $request = shift;
	my $r = Apache2::Request->new( $request );
   $r->content_type('image/png');
    my $no_text = 0;
    if ( $r->param('NoText') == 1 ) {
        $no_text = 1;
    } # end if

    my $height;
    if ( $r->param('Height') > 0 ) {
        $height = $r->param('Height');
    } # end if
    my $codetype = $r->param('type');
    $codetype = 'Code39' if ! $codetype;
	my $code = $r->param('code');
	my $barcode;
	my $blob;
	if ( $codetype eq 'Code39' ) {
		$code = "*$code*";
		$barcode = GD::Barcode->new($codetype, $code );
		if ( ! $barcode ) {
			$r->log->debug("Error generating barcode: " . $GD::Barcode::errStr );
			return Apache2::Const::OK;
		} # end if
		$blob = $barcode->plot(NoText=>$no_text, Height => $height )->png;
	} elsif ( $codetype eq 'Code128' ) {
		$barcode = new Barcode::Code128;
		$blob = $barcode->png($code, {'height'=>$height,'border'=>0, 'font_align'=>'center','show_text'=>!$no_text,'transparent_text'=>1});
	} # end if

	if ( $r->param('Rotate') ) {
		my $image=Image::Magick->new(magick=>'png');
		$image->BlobToImage($blob);
		$image->Rotate(degrees=>$r->param('Rotate'));
		$blob = $image->ImageToBlob();
	} # end if
	#$r->log->debug("Sending image for barcode $code " . length $blob);
	#$r->send_http_header();
    print $blob;
	return Apache2::Const::OK;
} # end sub handler

1;

__END__
