use strict;
package openprint::Conversation;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );
$debug = 1;
$table = 'conversations';
$serial = 'conversations_id_seq';

%fields = (
	'id'    		=>  'id',
	'subject'		=>	'subject',
	'created_on'	=>	'created_on',
	'created_by'	=>	'created_by',
);
%find_fields = (
);
%transforms = (
    'subject' => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	'created_on'	=>	q`'NOW()'`,
	'created_by'	=>	q`$session{'user_id'}`,
);

# returns an array of objects
sub To {
	my ( $self, $params ) = @_;
	if ( $_[0]{'id'} ) {
		my $Last_Message = openprint::Message->find_one('conversation_id'=>$_[0]{'id'});
		$$params{'message_id'} = $$Last_Message{'id'};
		return openprint::Message_To->find($params);
	} # end if
	return ();
} # end sub To

 1;
__END__
