package openprint::Upload;
@ISA = qw( openprint::Object );
use strict;

require openprint::Company;
require openprint::File;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 1;
$table = 'uploads';
$serial = 'upload_id_seq';
%fields = (
	'id'			=>	'id',
	'start'			=>	'start',
	'size'			=>	'size',
	'total'			=>	'total',
	'finished'		=>	'finished',
	'company_id'	=>	'company_id',
	'user_id'		=>	'user_id',
	'file_path'		=>	'file_path',
	'company'		=>	'company',
	'type'			=>	'type',
);
%defaults = (
	'start'	=>	q`'NOW()'`,
	'size'	=>	undef,
	'total'	=>	undef,
	'finished'	=>	0,
);


sub find {
	my %params = @_;
	my $sql = q{SELECT * FROM Uploads WHERE 1>0};
	my @values;
	if ( $params{'company_id'} ) {
		$sql .= q{ AND company_id=?};
		push @values, $params{'company_id'};
	} # end if
	if ( $params{'started_on_start'} and $params{'started_on_end'} ) {
		$sql .= q{ AND (start BETWEEN ? AND ?)};
		push @values, $params{'started_on_start'},$params{'started_on_end'};
	} elsif ( $params{'started_on_start'} ) {
		$sql .= q{ AND started_on >= ?};
		push @values, $params{'started_on_start'};
	} elsif ( $params{'started_on_end'} ) {
		$sql .= q{ AND started_on <= ?};
		push @values, $params{'started_on_end'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
	$sql .= " LIMIT $params{'limit'}" if ( $params{'limit'} );
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading Upload: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Upload: ($sql) (@values) (".@$data.')');
	} # end if
	return map { new openprint::Upload( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
    my ( $self, $data ) = @_;
    if ( ! $data ) {
        $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Uploads WHERE id=?', {}, $$self{id} );
    } # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub Company {
	my $self = shift;
	return new openprint::Company($$self{company_id});
} # end sub Company

sub User {
	my $self = shift;
	return new openprint::User($$self{user_id});
} # end sub User

sub Files {
	my $self = shift;
	return openprint::File::find('upload_id'=>$$self{id});
} # end sub

1;
__END__

