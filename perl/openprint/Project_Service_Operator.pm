use strict;
package openprint::Project_Service_Operator;
our @ISA = qw(openprint::Object);

require openprint;
require openprint::Project;
require openprint::User;
require openprint::ServiceType;

use vars qw( $debug %fields %find_fields %transforms %defaults $table $serial );

$debug = 0;
%fields = (
	id					=>	'id',
	service_id	=>	'service_id',
	user_id			=>	'user_id',
	role_id			=>	'role_id',
);
%find_fields = (
);
%transforms = (
);
%defaults = (
	role_id	=>	undef,
);
$table = 'project_service_operators';
$serial = 'project_service_operators_id_seq';

sub Project {
	return $_[0]->Service()->Project();
} # end sub Project

sub Service {
	return openprint::Service->find_one(service_id=>$_[0]{service_id});
}

sub User {
	return new openprint::User( $_[0]{user_id} );
} # end sub 

1;
__END__
