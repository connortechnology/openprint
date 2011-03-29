package openprint::Location;
@ISA = qw( openprint::Object );

use strict;
use openprint ();
use vars qw( %variable $log $dbh $debug );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
$debug = 1;

require sql;

sub find {
	if ( $_[0] eq 'openprint::Location' ) {
		shift;
	} # end if
	my %params = @_;
	if ( $params{'id'} ) {
		return new openprint::Location( $params{'id'} );
	} else {
		my @values;
		my $sql;
		$sql = q{SELECT * FROM Locations WHERE 1>0};
		if ( exists $params{'parent_id'} ) {
			if ( $params{'parent_id'} ) {
				$sql .= q{ AND parent_id=?};
				push @values, $params{'parent_id'};
			} else {
				$sql .= q{ AND parent_id IS NULL};
			} # end if
		} # end if
		if ( exists $params{'parent_id_is_null'} ) {
			if ( $params{'parent_id_is_null'} ) {
				$sql .= q{ AND parent_id IS NULL};
			} else {
				$sql .= q{ AND parent_id IS NOT NULL};
			} # end if
		} # end if
		if ( $params{'name'} ) {
			$sql .= q{ AND lower(name) = lower(?)};
			push @values, $params{'name'};
		} # end if
		if ( $params{'order_by'} ) {
			$sql .= " ORDER BY $params{'order_by'}";
		} # en if
		if ( $params{'order'} ) {
			$sql .= " ORDER BY $params{'order'}";
		} # en if
		my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
		if ( ! $data ) {
			$openprint::log->error( "Error loading Location: ($sql) (@values)" );
			return;
		} elsif ( $debug ) {
			$openprint::log->debug( "loading Location: ($sql) (@values) " . @$data );
		} # end if
		return map { new openprint::Location( $_->{id}, $_ ) } @$data;
	} # end if

} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $dbh->selectrow_hashref( 'SELECT * FROM Locations WHERE id=?',{}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub save {
	my $self = shift;

	my @sql = ( 
		'name',		$$self{'location'},
		'parent_id',$$self{'parent_id'},
		'name',		$$self{'name'},
		'coordinates',	$$self{'coordinates'},
		'updated_on', 'NOW()',
		);
		
	my $ac = sql::start_transaction( $dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('Location_id_seq')} );
		if ( my $error = sql::insert( undef, undef, 'Locations', [@sql, 'id', $$self{'id'}] ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( undef, undef, 'Locations', ['id=?', $$self{'id'}], \@sql ) ) {
			sql::end_transaction( $dbh, $ac );
			return $error;
		} # end if
	} # end if

	sql::end_transaction( $dbh, $ac );
	$self->load();
	return;
} # end sub save

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, q{DELETE FROM Locations WHERE id=?}, $$self{'id'} );
	sql::end_transaction( $dbh, $ac );
} # end sub delete

sub children {
	return openprint::Location::find( 'parent_id' => $_[0]{'id'} );
} # end sub children

sub get_all_children {
	my $self = shift;
	my @results;
	
	foreach my $child ( $self->children() ) {
		# Prevent infinite loop
		next if sets::isin( $child->id(), [ map { $_->id() } @results ] );
		push @results, $child, $child->get_all_children();
	} # end foreach child
	return @results;
} # end sub get_all_children

sub parent {
	my $self = shift;
	return new openprint::Location( $$self{'parent_id'}) if $$self{'parent_id'};
} # end sub parent
sub Parent {
	my $self = shift;
	return new openprint::Location( $$self{'parent_id'}) if $$self{'parent_id'};
} # end sub parent
sub Root {
	my $self = shift;
	my $P = $self;
	while ( $P->parent_id() ) {
		$P = $P->Parent();
	} # end while 
	return $P;
} # end sub Root

1;
__END__
