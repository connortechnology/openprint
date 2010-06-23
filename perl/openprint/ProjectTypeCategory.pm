package openprint::ProjectTypeCategory;
@ISA = qw( openprint::Object );
require openprint::ProjectType;

use vars qw( %fields %transforms %defaults $table $serial );

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
	my $self = shift;
	
	if ( @_ ) {
		my %params = @_;	
		$params{'category_id'} = $$self{'id'};
		return openprint::ProjectType->find( %params );
	} elsif ( ! $$self{'ProjectTypes'} ) {
		@{$$self{'ProjectTypes'}} = openprint::ProjectType->find( 'category_id'=>$$self{'id'} );
	} # end if
	return @{$$self{'ProjectTypes'}};
} # end sub project_types
1;
__END__
