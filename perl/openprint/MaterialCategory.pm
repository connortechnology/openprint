package openprint::MaterialCategory;
@ISA = qw( openprint::Object );
require openprint::Material;

my @fields = (
	'name',
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
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading Material Categories: ($sql) (@values)");
		return;
	} # end if
	return map { new openprint::MaterialCategory( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT id, name FROM Material_Categories WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{'id','name'} = @$data{qw/id name/};
} # end sub load

sub save {
	my $self = shift;

	my @sql = map { $_, $$self{$_} } @fields;

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		if ( ! ( @$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('Material_Categories_id_seq')} ) ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return 'Error allocating new Material Category';
		} # end if
		$sql{'id'} = $$self{'id'};

		if ( $_ = sql::insert( $openprint::log, $openprint::dbh, 'Material_Categories', \@sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return "Error inserting Material Category $$self{'name'} : $_<br>";
		} # end if
	} else {
		if ( $_ = sql::update( $openprint::log, $openprint::dbh, 'Material_Categories', ['id=?', $$self{'id'}], \@sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return "Error updating Material Category $$self{'name'} : $_<br>";
		} # end if
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return;
} # end sub save

sub Materials {
	my $self = shift;
	
	return openprint::Material::find( 'category_id'=>$$self{'id'} );
} # end sub project_types
 1;
__END__
