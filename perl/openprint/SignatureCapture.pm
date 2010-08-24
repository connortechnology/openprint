package openprint::SignatureCapture;
@ISA = qw( openprint::Object );
use strict;

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
);
%defaults = (
	'deleted'		=>	0,
);

sub file_path {
	# Not only returns the path relative to url root, but also makes sure that the image is there. o
	if ( ! -e $config{'SkinPath'}.'/images/SignatureCapture/' ) {
		mkdir $config{'SkinPath'}.'/images/SignatureCapture/';
	} # end if
	if ( ! -e $config{'SkinPath'}.'/images/SignatureCapture/'.$$self{'project_id'} ) {
		mkdir $config{'SkinPath'}.'/images/SignatureCapture/'.$$self{'project_id'};
	} # end if
	misc::save_file( $openprint::log, $config{'SkinPath'}.'/images/SignatureCapture/'.$$self{'project_id'}.'/'.$$self{'service_id'}.'.bmp', $$self{'image_data'} );
	return '/images/SignatureCapture/'.$$self{'project_id'}.'/'.$$self{'service_id'}.'.bmp';
} # end sub file_path

1;
__END__
