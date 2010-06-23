package openprint::StockMaterial;
@ISA = qw(openprint::Object);

use strict;

require sql;

use vars qw( $table $serial %fields %transforms %defaults );
$table = 'StockMaterials';
$serial= 'stockmaterials_id_seq';
%fields = ( 'name'=>'name' );
%transforms = ();
%defaults = ();

sub find {
	my $self = shift;
	my %params = @_;

	my $sql = 'SELECT * FROM StockMaterials WHERE 1>0';
	my @values;

	if ( $params{'papers'} ) {
		$sql .= ' AND id IN (?)';
		push @values, [map { $_->material_id(); } @{$params{'papers'}}];
	} # end if
	if ( $params{'project_type'} ) {
		$sql .= ' AND id IN (SELECT DISTINCT material_id FROM papers WHERE id IN (SELECT lngPaperIndex FROM Paper_Recommendations WHERE lngprojecttypeindex=?))';
		push @values, $params{'project_type'}->id();
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::StockMaterial->find( $sql)" . $openprint::dbh->errstr);
	} else {
		return map { new openprint::StockMaterial( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

1;

__END__
