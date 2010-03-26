package openprint::Project_Service;
@ISA = qw(openprint::Object);

use strict;
use openprint ();

require openprint::Project;
require openprint::User;

use vars qw( $log $dbh %fields %transforms %defaults $table $serial @identified_by );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

%fields = (
	'id'			=>	'lngserviceindex',
	'project_id'	=>	'lngprojectindex',
	'operator_id'	=>	'operator_id',
	'status'		=>	'strstatus',
	'servicetype_id'	=>	'servicetype_id',
	'created_on'	=>	'dtmlastmodified',
);
%transforms = (
);
%defaults = (
	'operator_id'	=>	undef,
	'created_on'	=>	'NOW()',
);
$table = 'tbl_project_contents';
$serial = 'ContentsServiceIndex_seq';
@identified_by = ( 'project_id', 'id' );

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

