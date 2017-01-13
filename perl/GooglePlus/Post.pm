use strict;

package GooglePlus::Post;

sub get {
    my $self = $_[0];
    my $url = 'https://plus.google.com/_/stream/getactivity/' . $$self{'user_id'} . '?updateId='.$$self{'id'};

    my $browser = LWP::UserAgent->new;
    my $response = $browser->get($url);
    if ( $response->is_success ) {
        return JSON::decode_json( $response->content );
    } else {
        #error log
    } # end if
} # end sub get


1;
__END__
