use strict;
package openprint::Project_Service;
our @ISA = qw(openprint::Object);

use openprint ();

require openprint::Project;
require openprint::User;
require openprint::ServiceType;

use vars qw( $log $dbh $debug %fields %find_fields %transforms %defaults $table $serial @identified_by );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

%fields = (
	'service_iid'	=>	'lngserviceindex',
	'project_id'	=>	'lngprojectindex',
	'operator_id'	=>	'operator_id',
	'status'		=>	'strstatus',
	'servicetype_id'	=>	'servicetype_id',
	'created_on'	=>	'dtmlastmodified',
);
%find_fields = (
    'category'  =>  '(SELECT ServiceType_Categories.name FROM ServiceType_Categories,Service_Types WHERE ServiceType_Categories.id=Service_Types.category_id AND Service_Types.id=servicetype_id)',
);
%transforms = (
);
%defaults = (
	'operator_id'	=>	undef,
	'created_on'	=>	'NOW()',
);
$table = 'tbl_project_contents';
$serial = 'ContentsServiceIndex_seq';
@identified_by = ( 'project_id', 'service_id' );

sub Project {
	return new openprint::Project( $_[0]{'project_id'} );
} # end sub Project

sub Operator {
	return new openprint::User( $_[0]{'operator_id'} );
} # end sub Operator

sub specs {
	if ( ! $_[0]{'specs'} ) {
		$_[0]{'specs'} = openprint::service::get_specs_ref( $_[0]->Project(), $_[0]{'id'} );
	} # end if
	return $_[0]{'specs'};
} # end sub specs

1;
__END__

