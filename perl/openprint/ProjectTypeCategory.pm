use strict;
package openprint::ProjectTypeCategory;
our @ISA = qw( openprint::Object );
require openprint::ProjectType;

use vars qw( $debug %fields %transforms %defaults $table $serial );

$debug = 1;
$table =  'ProjectType_Categories';
$serial = 'ProjectType_Categories_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'sort'	=>	'sort',
);
%transforms = (
);
%defaults = (
	'sort'	=>	undef,
);

sub ProjectTypes {
	my %params;
	if ( @_ > 1 ) {
		if ( ref $_[1] eq 'HASH' ) {
			%params = %{$_[1]}
		} else {
			shift @_;
			%params = @_;
		} # end if
	} # en dif	
	$params{category_id} = $_[0]{id};
	return openprint::ProjectType->find(%params);
} # end sub ProjectTypes

1;
__END__
