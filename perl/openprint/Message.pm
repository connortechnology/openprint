use strict;
package openprint::Message;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );
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
);
%find_fields = (
	'to_id'			=>	'(SELECT to_id FROM Messages_to WHERE message_id=messages.id)',
);
%transforms = (
);
%defaults = (
	'reply_to'	=>	undef,
);
sub From {
	new openprint::User( $_[0]{'from_id'} );
} # end sub From

# returns an array of objects
sub To {
	return () if ! $_[0]{'to_id'};
	return map { new openprint::User( $_ ); } @{$_[0]{'to_id'}};
} # end sub To
 1;
__END__
