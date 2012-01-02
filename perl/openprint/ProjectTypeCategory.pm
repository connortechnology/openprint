use strict;
package openprint::ProjectTypeCategory;
our @ISA = qw( openprint::Object );
require openprint::ProjectType;

use vars qw( $debug %fields %transforms %defaults $table $serial );

$debug = 1;
$table =  'projecttype_categories';
$serial = 'projecttype_categories_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
	'sort'	=>	'sort',
);
%transforms = (
    'name' => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	'sort'	=>	undef,
);

sub ProjectTypes {
	my $self = shift;
	
	if ( @_ ) {
		my %params = @_;	
		$params{'category_id'} = $$self{'id'};
		return openprint::ProjectType->find( %params );
	} elsif ( ! $$self{'ProjectTypes'} ) {
		@{$$self{'ProjectTypes'}} = openprint::ProjectType->find( 'category_id'=>$$self{'id'} );
	} # end if
	return @{$$self{'ProjectTypes'}};
} # end sub ProjectTypes

1;
__END__
