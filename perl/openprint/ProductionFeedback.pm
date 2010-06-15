package openprint::ProductionFeedback;
@ISA = qw(openprint::Object);

use strict;

require sql;
require openprint::Object;
use openprint ();

use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;
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
);
%defaults = (
	'user_id'		=>	undef,
);
%transforms = (
	'project_id'	=> [ 's/\D//g' ],
	'service_id'	=> [ 's/\D//g' ],
	'user_id'		=> [ 's/\D//g' ],
);

sub User {
	return new openprint::User( $_[0]{'user_id'} );
} # end sub User

1;

__END__
~       
