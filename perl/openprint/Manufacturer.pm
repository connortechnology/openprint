package openprint::Manufacturer;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $table $serial %fields %transforms %defaults );

$table = 'manufacturers';
$serial= 'manufacturers_id_seq';
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
require openprint::Object;

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM Manufacturers WHERE 1>0';
	my @values;

	if ( $params{'name'} ) {
		$sql .= ' AND shortname=?';
		push @values, $params{'name'};
	} # end if
	if ( $params{'shortname'} ) {
		$sql .= ' AND shortname=?';
		push @values, $params{'shortname'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::Manufacturer::find( $sql)" . $openprint::dbh->errstr);
	} else {
		return map { new openprint::Manufacturer( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

1;

__END__
