use strict;
package openprint::SRED_Project;

our @ISA = qw(openprint::Object);
require openprint::Object;
require openprint::User;
require openprint::SRED_Content;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'sred_projects';
$serial = 'sred_projects_id_seq';

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
	'description'	=>	'description',
	'created_on'	=>	'created_on',
	'updated_on'	=>	'updated_on',
	'created_by'	=>	'created_by',
	'deleted'		=>	'deleted',
);

%transforms = (
	'name'			=>	[ 's/^\s+//', 's/\s+$//' ],
);

%defaults = (
	'deleted'	=>	0,
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
);

sub Created_By {
	return new openprint::User( $_[0]{'created_by'} );
} # end sub Created_By

sub Contents {
	my $self = shift;
	my %params = @_;
	$params{'project_id'} = $$self{'id'};
	return openprint::SRED_Content->find(%params);
} # end sub Contents
sub Taxes {
	return ();
}
1;
__END__
