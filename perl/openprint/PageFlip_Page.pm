package openprint::PageFlip_Page;
@ISA = qw( openprint::Object );

use Image::Magick;
use openprint ();

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use vars qw( $table $serial %fields %defaults %transforms );
$table = 'pageflip_page';
$serial = 'pageflip_page_id_seq';

%fields = (
	'id'			=>	'id',
	'pageflip_id'	=>	'pageflip_id',
	'filename'		=>	'filename',
	'page'			=>	'page',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'clip_box'		=>	'clip_box',
	'width'			=>	'width',
	'height'		=>	'height',
);

sub getImage {
	my ( $self ) = @_;
	if ( open(IMAGE, $config{'PageFlipDir'}.'/HR/'.$self->filename() ) ) {
		my $Image = Image::Magick->new;
		$Image->Read(file=>\*IMAGE);
		close(IMAGE);
		return $Image;
	} else {
		$openprint::log->error('Unable to open PageFlip image at '. $config{'PageFlipDir'}.'/LR/'.$self->filename() );
		return;
	} # end if
} # end sub getImage

sub dst_filename {
	return sprintf('>%s_%dx%d.jpg', $_[0]->get('filename','width','height') );
} # end sub dst_filename

sub writeImage {
	my ( $self ) = @_;
	my $Image = $self->getImage();
	$Image->AdaptiveResize('width'=>$$self{'width'}, 'height'=>$$self{'height'});
	$Image->Crop('width'=>$$self{'crop_right'}-$$self{'crop_left'}, 'height' => $$self{'crop_bottom'} - $$self{'crop_top'}, 'x'=>$$self{'crop_left'}, 'Y'=>$$self{'crop_right'}, 'gravity'=>'NorthWest' );
	open(IMAGE, '>'.$self->dst_filename());
	$Image->Write(file=>\*IMAGE, filename=>$self->dst_filename());
	close(IMAGE);
} # end sub writeImage 

sub src_width {
	my ( $self ) = @_;
	if ( ! $$self{'src_width'} ) {
		my $Image = $self->getImage();
		@$self{'src_width','src_height'} = $Image->Get('width','height');
	} # end if
	return $$self{'src_width'};
} # end sub src_width
sub src_height {
	my ( $self ) = @_;
	if ( ! $$self{'src_height'} ) {
		my $Image = $self->getImage();
		@$self{'src_width','src_height'} = $Image->Get('width','height');
	} # end if
	return $$self{'src_height'};
} # end sub src_height

1;
__END__
