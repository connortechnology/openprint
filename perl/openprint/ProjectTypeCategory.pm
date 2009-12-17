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

sub find {
	my %params = @_;
	my $sql = q{SELECT * FROM ProjectType_Categories WHERE 1>0};
	my @values;
	if ( $params{'order'} ) {
		$sql .= qq{ ORDER BY $params{'order'} };
	} # end if
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading ProjectTypeCategories: ($sql) (@values)");
		return;
	} # end if
	return map { new openprint::ProjectTypeCategory( $_->{id}, $_ ) } @$data;
} # end sub find

sub ProjectTypes {
	my $self = shift;
	
	if ( ! $$self{'ProjectTypes'} ) {
		@{$$self{'ProjectTypes'}} = openprint::ProjectType::find( 'category_id'=>$$self{'id'} );
	} # end if
	return @{$$self{'ProjectTypes'}};
} # end sub project_types
