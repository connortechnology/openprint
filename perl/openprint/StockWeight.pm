package openprint::StockWeight;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $table $serial %fields %transforms %defaults );

$table = 'paperweights';
$serial= 'paperweight_id_seq';
%fields = (
    'id'    =>  'id',
    'shortname' =>  'shortname',
    'longname'  =>  'longname',
);
%transforms = (
    'shortname' => [ 's/^\s+//', 's/\s+$//' ],
    'longname' => [ 's/^\s+//', 's/\s+$//' ],
);
%defaults = (
);

require sql;

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM PaperWeights WHERE 1>0';
	my @values;

	if ( $params{'papers'} ) {
		$sql .= ' AND id IN (?)';
		push @values, [map { $_->name_id(); } @{$params{'papers'}}];
	} # end if
	if ( $params{'project_type'} ) {
		$sql .= ' AND id IN (SELECT DISTINCT name_id FROM papers WHERE id IN (SELECT lngPaperIndex FROM Paper_Recommendations WHERE lngprojecttypeindex=?))';
		push @values, $params{'project_type'}->id();
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::StockWeight::find( $sql)" . $openprint::dbh->errstr);
	} else {
		return map { new openprint::StockWeight( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

1;

__END__
