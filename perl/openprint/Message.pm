use strict;
package openprint::Message;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );
$debug = 1;
$table = 'messages';
$serial = 'messages_id_seq';

%fields = (
	'id'    		=>  'id',
	'subject'		=>	'subject',
	'body'			=>	'body',
	'from_id'		=>	'from_id',
	'reply_to'		=>	'reply_to',
	'created_on'	=>	'created_on',
	'sent_on'		=>	'sent_on',
	'conversation_id'	=>	'conversation_id',
);
%find_fields = (
	'to_id'			=>	'(SELECT user_id FROM Message_to WHERE message_id=messages.id AND deleted!=true)',
);
%transforms = (
);
%defaults = (
	'reply_to'	=>	undef,
	'created_on'	=>	q`'NOW()'`,
	'sent_on'	=>	undef,
	'conversation_id'	=>	undef,
	'from_id'		=>	q`$session{'user_id'}`,
);
sub From {
	new openprint::User( $_[0]{'from_id'} );
} # end sub From

# returns an array of objects
sub To {
	my ( $self, $params ) = @_;
	$$params{'message_id'} = $$self{'id'};
	return openprint::Message_To->find($params);
} # end sub To

sub Who {
	my ( $self, $params ) = @_;
	$$params{'message_id'} = $$self{'id'};
	return ( $self->From(), map { new openprint::User( $_->user_id() ) } openprint::Message_To->find($params) );
} # end sub Who
 1;
__END__
