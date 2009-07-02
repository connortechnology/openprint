package openprint::File;
@ISA = qw( openprint::Object );
use strict;

use openprint ();
use vars qw( $log $dbh $table $serial %fields %transforms %defaults );

*log = \$openprint::log;
*dbh = \$openprint::dbh;

$table = 'project_files';
$serial = 'project_files_id_seq';
%fields = (
		'project_id'	=>	'project_id',
		'filename'		=>	'filename',
		'description'	=>	'description',
		'id'			=>	'id',
		'upload_id'		=>	'upload_id',
		'size'			=>	'size',
		'deleted'		=>	'deleted',
		);
%transforms = (
);
%defaults = (
);

my $debug = 1;

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
	if ( $params{'filename'} ) {
		$sql .= q{ AND filename=?};
		push @values, $params{'filename'};
	} # end if

	if ( exists $params{'deleted'} ) {
		if ( ref $params{'deleted'} eq 'ARRAY' ) {
			$sql .= ' AND (deleted IS NULL OR deleted IN (' . join(',', map {'?'} @{$params{'deleted'}}) . '))';
			push @values, @{$params{'deleted'}};
		} else {
			$sql .= ' AND deleted=?';
			push @values, $params{'deleted'};
		} # end if
	} else {
		$sql .= ' AND (deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if
	$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
	$sql .= " LIMIT $params{'limit'}" if ( $params{'limit'} );
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->error("Error loading File: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$log->debug("Loading File: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::File( $_->{id}, $_ ); } @$data;
} # end sub find

sub size_text {
	my ( $self ) = @_;
	return misc::format_bytes( $$self{'size'} );
} #end sub size_text

1;
__END__

