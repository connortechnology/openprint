package openprint::ProjectType_Default;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use vars qw( $debug $table $serial %fields %transforms %defaults %find_fields );


$debug = 1;

$table = 'tbl_projecttype_defaults';
$serial = 'tbl_projecttype_defaults_id_seq';

%fields = (
	'id'				=>	'id',
	'projecttype_id'	=>	'lngprojecttypeindex',
	'name'				=>	'strfieldname',
	'value'				=>	'strdefaultvalue',
);
%find_fields = (
	'projecttype'		=>	'(SELECT name FROM project_types WHERE id=lngprojecttypeindex)',
);

%transforms = (
	'id'				=>	[ 's/\D//g' ],
	'projecttype_id'	=>	[ 's/\D//g' ],
);

%defaults = (
);

1;
__END__
