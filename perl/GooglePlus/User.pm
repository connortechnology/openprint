use strict;
use LWP;
use JSON;

package GooglePlus::User;

sub get_stream {
	my $self = $_[0];
	my $url = 'https://plus.google.com/_/stream/getactivities/' . $$self{'id'} . '/?sp=%5B1%2C2%2C%22' . $$self{'id'}. '%22%2Cnull%2Cnull%2Cnull%2Cnull%2C%22social.google.com%22%2C%5B%5D%5D';
	
	my $browser = LWP::UserAgent->new;
	my $response = $browser->get($url);
	if ( $response->is_success ) {
		return JSON::decode_json( $response->content );
	} else {
		#error log
	} # end if
} # end sub get_stream

1;
__END__
