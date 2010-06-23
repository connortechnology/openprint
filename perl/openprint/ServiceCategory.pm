package openprint::ServiceCategory;
@ISA = qw( openprint::Object );
use openprint ();
require openprint::Service;

use vars qw($log $dbh $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
$table = 'Service_Categories';
$serial = 'Service_Categories_id_seq';

%fields = (
	'id','id',
	'name','name',
);
%transforms = (
);
%defaults = (
);

sub Services {
	my $self = shift;
	
	return openprint::Service->find( 'category_id'=>$$self{'id'} );
} # end sub project_types
1;
__END__
