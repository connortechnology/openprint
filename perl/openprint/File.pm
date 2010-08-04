package openprint::File;
@ISA = qw( openprint::Object );
use strict;

use vars qw( $debug $table $serial %fields %transforms %defaults );

$debug = 1;
$table = 'project_files';
$serial = 'project_files_id_seq';
%fields = (
	'id'	=>	'id',
	'project_id'	=>	'project_id',
	'filename'		=>	'filename',
	'description'	=>	'description',
	'upload_id'		=>	'upload_id',
	'deleted'		=>	'deleted',
	'size'			=>	'size',
);
%defaults = (
	'deleted'		=>	0,
);

sub find {
	my %params = @_;
	my $sql = q{SELECT * FROM Project_Files WHERE 1>0};
	my @values;
	if ( $params{'upload_id'} ) {
		$sql .= q{ AND upload_id=?};
		push @values, $params{'upload_id'};
	} # end if
	if ( $params{'project_id'} ) {
		$sql .= q{ AND project_id=?};
		push @values, $params{'project_id'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
	$sql .= " LIMIT $params{'limit'}" if ( $params{'limit'} );
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading File: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading File: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::File( $_->{id}, $_ ); } @$data;
} # end sub find

1;
__END__
