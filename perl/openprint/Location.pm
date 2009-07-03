package openprint::Location;
@ISA = qw( openprint::Object );

use strict;
use openprint ();
use vars qw( %variable %cache $log $dbh );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;

sub find {
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
		if ( $params{'name'} ) {
			$sql .= q{ AND lower(name) = lower(?)};
			push @values, $params{'name'};
		} # end if
		#$_ .= " AND owner_id=$params{'owner_id'}" if $params{'owner_id'};
		if ( $params{'order_by'} ) {
		$sql .= " ORDER BY $params{'order_by'}";
		} # en if
		if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
		} # en if
		my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
		return map { new openprint::Location( $_->{id}, $_ ) } @$data;
	} # end if

} # end sub find

sub copy {
	my $self = shift;
	my $new = new openprint::Location();
	@$new{'location'} = @$self{'location'};
	%{$$new{'Paper'}} = %{$$self{'Paper'}};
	return $new;
} # end sub copy

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
	my $self = shift;
	return openprint::Location::find( 'parent_id' => $$self{'id'} );
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
