package openprint::File;
@ISA = qw( openprint::Object );
use strict;

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

sub load {
    my ( $self, $data ) = @_;
    if ( ! $data ) {
        $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Project_Files WHERE id=?', {}, $$self{id} );
    } # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub save {
	my $self = shift;
	my %sql = (
		);
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('Upload_id_seq')} );
		sql::insert( $openprint::log, $openprint::dbh, 'Project_Files', 'id', $$self{'id'}, %sql );
	} else {
		sql::update( $openprint::log, $openprint::dbh, 'Project_Files', ['id=?', $$self{'id'}], %sql );
	} # end if
} # end sub save

1;
__END__

