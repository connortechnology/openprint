package openprint::ServiceType_Default;
@ISA = qw(openprint::Object);
require openprint::Object;

use strict;
use vars qw( $debug $table $serial %fields %transforms %defaults );


$debug = 1;

$table = 'tbl_service_defaults';
$serial = 'tbl_Service_Defaults_lngID_seq';

%fields = (
	'id'				=>	'lngindex',
	'servicetype_id'	=>	'lngservicetypeindex',
	'name'				=>	'strfieldname',
	'value'				=>	'strdefaultvalue',
);

%transforms = (
	'id'				=>	[ 's/\D//g' ],
	'servicetype_id'	=>	[ 's/\D//g' ],
);

%defaults = (
);

1;
__END__
