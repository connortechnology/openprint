package openprint::ServiceCategory;
@ISA = qw( openprint::Object );
require openprint::Service;

use vars qw( %config $log $dbh );
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my @fields = (
	'name',
);

sub find {
	my %params = @_;
	my $sql = q{SELECT * FROM Service_Categories WHERE 1>0};
	my @values;
    if ( $params{name} ) {
        $sql .= ' AND name=?';
        push @values, $params{name};
    } # end if
	if ( $params{'order'} ) {
		$sql .= qq{ ORDER BY $params{'order'} };
	} # end if
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ( ! $data ) and $dbh->errstr ) {
		$log->error("Error loading Service Categories: ($sql) (@values) :" . $dbh->errstr );
		return;
	} # end if
	return map { new openprint::ServiceCategory( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( q{SELECT id, name FROM Service_Categories WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{'id','name'} = @$data{qw/id name/};
} # end sub load

sub save {
	my $self = shift;

	my @sql = map { $_, $$self{$_} } @fields;

	my $ac = sql::start_transaction( $dbh );
	if ( ! $$self{'id'} ) {
		if ( ! ( @$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('Service_Categories_id_seq')} ) ) ) {
			sql::end_transaction( $dbh, $ac );
			return 'Error allocating new Service Category';
		} # end if
		$sql{'id'} = $$self{'id'};

		if ( $_ = sql::insert( undef, undef, 'Service_Categories', \@sql ) ) {
			sql::end_transaction( $dbh, $ac );
			return "Error inserting Service Category $$self{'name'} : $_<br>";
		} # end if
	} else {
		if ( $_ = sql::update( undef, undef, 'Service_Categories', ['id=?', $$self{'id'}], \@sql ) ) {
			sql::end_transaction( $dbh, $ac );
			return "Error updating Service Category $$self{'name'} : $_<br>";
		} # end if
	} # end if
	sql::end_transaction( $dbh, $ac );
	$self->load();
	return;
} # end sub save

sub Services {
	my $self = shift;
	
	return openprint::Service::find( 'category_id'=>$$self{'id'} );
} # end sub project_types
1;
__END__
