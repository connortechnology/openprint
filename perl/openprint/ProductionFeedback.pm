use strict;
require openprint::SignatureCapture;
require openprint::User;

package openprint::ProductionFeedback;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'ProductionFeedback';
$serial = 'ProductionFeedback_id_seq';
%fields = (
	'id'			=>	'id',
	'project_id'	=>	'project_id',
	'service_id'	=>	'service_id',
	'starting_on'	=>	'starting_on',
	'ending_on'		=>	'ending_on',
	'user_id'		=>	'user_id',
	'comment'		=>	'comment',
	'signature_id'	=>	'signature_id',
);
%defaults = (
	'user_id'		=>	undef,
	'service_id'	=>	undef,
	'signature_id'	=>	undef,
	'starting_on'	=>	'NOW()',
	'ending_on'		=>	'NOW()',
);
%transforms = (
	'project_id'	=>	[ 's/\D//g' ],
	'service_id'	=>	[ 's/\D//g' ],
	'user_id'		=>	[ 's/\D//g' ],
	'signature_id'	=>	[ 's/\D//g', ],
);

sub User {
	return new openprint::User( $_[0]{'user_id'} );
} # end sub User

sub Signature {
	return new openprint::SignatureCapture( $_[0]{signature_id} );
} # end sub Signature

1;
__END__
