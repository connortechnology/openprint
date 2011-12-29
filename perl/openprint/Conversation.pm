use strict;
package openprint::Conversation;
our @ISA = qw( openprint::Object );

require openprint::Message_To;
require openprint::Message;

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
	if ( @_ > 1 ) {
		$_[0]{'To'} = $_[1];
	} # endif
	if ( $_[0]{'id'} and ! $_[0]{'To'} ) {
		my $Last_Message = openprint::Message->find_one('conversation_id'=>$_[0]{'id'});
		my $params = {};
		$$params{'message_id'} = $$Last_Message{'id'};
		@{$_[0]{'To'}} = openprint::Message_To->find($params);
	} # end if
	return $_[0]{'To'} ? @{$_[0]{'To'}} : ();
} # end sub To

sub Messages {
	return openprint::Message->find('conversation_id'=>$_[0]{'id'});
} # end sub Messages
 1;
__END__
