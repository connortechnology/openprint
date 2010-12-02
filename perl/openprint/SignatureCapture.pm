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
	'additional_image_data'	=>	'additional_image_data',
	'additional_image_type'	=>	'additional_image_type',
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
		my $tmp_filename = '/tmp/'.$$self{'project_id'}.'_'.$$self{'service_id'}.'_'.$$self{'id'};

		misc::save_file( $openprint::log, $tmp_filename.'.bmp', $$self{'image_data'} );
		# Convert to gif
		my $Image = Image::Magick->new('format'=>'bmp');
		$_ = $Image->Read($tmp_filename.'.bmp');
		if ( $_ ) {
			$openprint::log->error("Read: " . $_);
			return '';
		} # end if
		unlink $tmp_filename.'.bmp';
		#$Image->Write('gif:'.$tmp_filename.'.gif');
		$Image->magick('gif');
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
sub additional_file_path {
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
		my $tmp_filename = '/tmp/'.$$self{'project_id'}.'_'.$$self{'service_id'}.'_'.$$self{'id'}.'_additional';

		misc::save_file( $openprint::log, $tmp_filename.'.bmp', $$self{'additional_image_data'} );
		# Convert to gif
		my $Image = Image::Magick->new('format'=>'bmp');
		$_ = $Image->Read($tmp_filename.'.bmp');
		if ( $_ ) {
			$openprint::log->error("Read: " . $_);
			return '';
		} # end if
		unlink $tmp_filename.'.bmp';
		#$Image->Write('gif:'.$tmp_filename.'.gif');
		$Image->magick('gif');
		my @blobs = $Image->ImageToBlob();
        if ( ! @blobs ) {
            $openprint::log->error("No blobs");
        } # end if

		$_ = $self->save({'additional_image_data'=>$blobs[0],'additional_image_type'=>'gif'});
		$openprint::log->error($_) if $_;
	} # end if
	return '' if ! $$self{'additional_image_data'};
	my $filename = '/images/SignatureCapture/'.$$self{'project_id'}.'/'.$$self{'service_id'}.'/'.$$self{'id'}.'_additional.gif';
	misc::save_file( $openprint::log, $openprint::config{'SkinPath'}.$filename, $$self{'additional_image_data'} );
	return $filename;
} # end sub additional_file_path

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
