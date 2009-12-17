package openprint::MaterialCategory;
@ISA = qw( openprint::Object );
require openprint::Material;

use strict;

use openprint;

use vars qw( $table $serial $log $dbh %fields );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'Material_Categories';
$serial = 'material_categories_id_seq';
%fields = (
	'id'	=>	'id',
	'name'	=>	'name',
);

sub find {
	my %params = @_;
	my $sql = q{SELECT * FROM Material_Categories WHERE 1>0};
	my @values;
	if ( $params{name} ) {
		$sql .= ' AND name=?';
		push @values, $params{name};
	} # end if
	if ( $params{'order'} ) {
		$sql .= qq{ ORDER BY $params{'order'} };
	} # end if
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->error("Error loading Material Categories: ($sql) (@values)");
		return;
	} # end if
	return map { new openprint::MaterialCategory( $_->{id}, $_ ) } @$data;
} # end sub find

sub Materials {
	my $self = shift;
	return openprint::Material::find( 'category_id'=>$$self{'id'} );
} # end sub project_types

 1;
__END__
