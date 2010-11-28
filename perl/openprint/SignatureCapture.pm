use strict;
package openprint::SignatureCapture;
our @ISA = qw( openprint::Object );
use openprint ();
use Image::Magick;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'signaturecapture';
$serial = 'signaturecapture_id_seq';
%fields = (
	'id'	=>	'id',
	'project_id'	=>	'project_id',
	'image_data'	=>	'image_data',
	'service_id'	=>	'service_id',
	'deleted'		=>	'deleted',
	'created_on'	=>	'created_on',
	'type'			=>	'type',
);
%defaults = (
	'deleted'		=>	0,
);

sub file_path {
	my $self = $_[0];
	# Not only returns the path relative to url root, but also makes sure that the image is there. o
	if ( ! -e $openprint::config{'SkinPath'}.'/images/SignatureCapture/' ) {
		mkdir $openprint::config{'SkinPath'}.'/images/SignatureCapture/';
	} # end if
	if ( ! -e $openprint::config{'SkinPath'}.'/images/SignatureCapture/'.$$self{'project_id'} ) {
		mkdir $openprint::config{'SkinPath'}.'/images/SignatureCapture/'.$$self{'project_id'};
	} # end if
	if ( ! -e $openprint::config{'SkinPath'}.'/images/SignatureCapture/'.$$self{'project_id'}.'/'.$$self{'service_id'} ) {
		mkdir $openprint::config{'SkinPath'}.'/images/SignatureCapture/'.$$self{'project_id'}.'/'.$$self{'service_id'};
	} # end if
	if ( $self->type() eq 'bmp' ) {
		# Convert to gif
		my $Image = Image::Magick->new(magick=>'bmp','depth'=>24, 'width'=>220);
		$_ = $Image->BlobToImage($$self{'image_data'});
		if ( $_ ) {
			$openprint::log->error($_);
			return;
		} # end if
		$_ = $Image->Set('magick'=>'gif','depth'=>1);
		if ( $_ ) {
			$openprint::log->error($_);
			return;
		} # end if
		my @blobs = $Image->ImageToBlob();
		if ( ! @blobs ) {
			$openprint::log->error("No blobs");
		} # end if
		$_ = $self->save({'image_data'=>$blobs[0],'type'=>'gif'});
		$openprint::log->error($_) if $_;
	} # end if
	misc::save_file( $openprint::log, $openprint::config{'SkinPath'}.'/images/SignatureCapture/'.$$self{'project_id'}.'/'.$$self{'service_id'}.'/'.$$self{'id'}.'.gif', $$self{'image_data'} );
	return '/images/SignatureCapture/'.$$self{'project_id'}.'/'.$$self{'service_id'}.'/'.$$self{'id'}.'.gif';
} # end sub file_path

sub type {
	if ( @_ > 1 ) {
		$_[0]{'type'} = $_[1];
	}
	if ( ! $_[0]{'type'} ) {
		if ( $_[0]{'image_data'} =~ /^GIF/ ) {
			$_[0]{'type'} = 'gif';
		} elsif ( $_[0]{'image_data'} =~ /^BM/ ) {
			$_[0]{'type'} = 'bmp';
		} # end if
	} # end if
}

1;
__END__
