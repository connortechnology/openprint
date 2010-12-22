use strict;
package openprint::Photo_in_Album;
our @ISA = qw( openprint::Object );

use openprint ();

use vars qw( $debug $table %fields %transforms %defaults @identified_by );
$debug = 1;
$table = 'photos_in_albums';
%fields = (
	'album_id'	=>	'album_id',
	'asset_id'	=>	'asset_id',
);

@identified_by = ( 'album_id','asset_id' );

# Filenames will be passed in @_
# Filenames will be converted to 
sub handle_upload {
	my $self = shift;
	my $error;
	foreach my $upload_name ( @_ ) {
		my $filename = $openprint::param{$upload_name};
		$filename =~ s/ /_/g;
		my $upload = $openprint::r->upload( $upload_name );
		if ( ! $upload ) {
			return "No upload found for $upload_name";
		} # end if
		if ( ! $upload->link( "$openprint::config{'AssetPath'}/$filename" ) ) {
			$openprint::log->error("There was an error saving file $upload_name: to $openprint::config{'AssetPath'}/$filename : $!");
			$error .= "There was an error saving file $upload_name: $!<br/>";
			next;
		#} else {
			#$$variable{'information'} .= "File $upload_name was uploaded successfully.<br/>";
		} # end if
		my $Asset = new openprint::Asset();
		$Asset->save({
				'user_id'	=>	$openprint::session{'user_id'},
				'filename'	=>	$filename,
				'data'		=>	misc::load_file( $openprint::log, "$openprint::config{'AssetPath'}/$filename" ),
			});
		# We assume that before now, the object was not saved. So this loop will in fact create multiple photos if passed multiple uploads
		$self->save({'asset_id'=>$Asset->id()});
	} # end foreach filename
	return $error;
} # end sub handle_upload

sub thumbnail_url {
	my $Asset = $_[0]->Asset();
	return $Asset->thumbnail_filename();
} # end sub thumbnail_url 

1;
__END__

