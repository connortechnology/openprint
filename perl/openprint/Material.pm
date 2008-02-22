package openprint::Material;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;

require openprint::logs;
require openprint::MaterialSpecification;

my $debug = 0;

my %fields = (
		'id'				=>	'id',
		'name'				=>	'name',
		'description'		=>	'description',
		'supplier_id'		=>	'supplier_id',
		'category_id'		=>	'category_id',
		'taxexempt1'		=>	'taxexempt1',
		'taxexempt2'		=>	'taxexempt2',
		);	

my %transforms = (
		);

my %defaults = (
		'supplier_id'	=>	undef,
		'category_id'	=>	undef,
		'taxexempt1'	=>	'N',
		'taxexempt2'	=>	'N',
		);

my %cache;

sub init_cache {
	%cache = map { $_->name(), $_->id() } find();
} # end sub init_cache

sub load {
	my ( $self, $data ) = @_;

	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Materials WHERE id=?', {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load_values

# if we have previously loaded info for this customer, and it hasn't changed, that field will not be saved.
# If we have not previously loaded the info, we will just save it whether it has actually changed or not.
# We do this for efficiency's sake.
sub save {
	my ( $self, $params ) = @_;

	my $change = 1;

	if ( $params ) {
		$change = 0;
		foreach my $field ( keys %{$params} ) {
			if ( defined $fields{$field} ) {

				foreach my $transform ( @{$transforms{$field}} ) {
					eval '$params->{$field} =~ ' . $transform;
				} # end foreach

				if ( $params->{$field} eq '' and exists $defaults{$field} ) {
					$params->{$field} = $defaults{$field};
				} # end if

# if valid db field
				if ( ! defined $$self{$field} or $$self{$field} ne $$params{$field} ) {
# Only make changes to fields that have changed
					$$self{$field} = $$params{$field};
					$change = 1;
				} # end if
			} else {
				$openprint::log->warn("Material::Save::Invalid field requested: ($field)." );
			} # end if
		} # end foreach
	} # end if

	if ( $change ) {
		my %sql;
		foreach my $k ( keys %fields ) {
			$sql{$k} = $$self{$k};
		} # end foreach

		my $ac = sql::start_transaction( $openprint::dbh );
		if ( ! $$self{id} ) {
			@$self{id} = sql::execute( undef, undef, q{SELECT nextval('MaterialIndex_seq')} );
			$sql{id} = $$self{id};
			if ( my $error = sql::insert( undef, undef, 'Materials', \%sql ) ) {
				sql::end_transaction( $openprint::dbh, $ac );
				return $error;
			} # end if
			openprint::logs::insertLogRecord('41', "Material Index: " . $$self{id},); # Add record to audit log - action "New Material".
		} else {
			if ( my $error = sql::update( undef, undef, 'Materials', ['id=?', $$self{id} ], \%sql ) ) {
				sql::end_transaction( $openprint::dbh, $ac );
				return $error;
			} # end if
			openprint::logs::insertLogRecord('42', "Material Index: " . $$self{id},); # Add record to audit log - action "Update Material".
		} # end if
		sql::end_transaction( $openprint::dbh, $ac );
	} # end if
	$self->load();
	return;
} # end sub save

sub delete {
	my $self = shift;

	delete $openprint::Object::cache{'openprint::Material'}{$$self{id}} if $openprint::Object::cache{'openprint::Material'};	

	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( undef, undef, q{DELETE FROM Material_Specifications WHERE material_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM tbl_Material_Prices WHERE lngMaterialIndex=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM Materials WHERE id=?}, $$self{'id'} );
	openprint::logs::insertLogRecord('8', "Material Id: $$self{'id'} Material Name: $$self{'name'}" );
	sql::end_transaction( $openprint::dbh, $ac );

	init_cache();
} # end sub delete

sub prices {
	my $self = shift;

	return openprint::MaterialPrice::find('material_id'=>$$self{id});
} # end sub prices

sub specification {
	my ( $self, $name, $range ) = @_;

	if ( ! $$self{'Specifications'} ) {
		foreach my $Spec ( openprint::MaterialSpecification::find( 'Material'=>$self, 'order'=>'min' ) ) {
			push @{$$self{'Specifications'}{$Spec->name()}}, $Spec;
		} # end foreach
	} # end if

	if ( ! $$self{'Specifications'} ) {
		#$openprint::log->warn("No specfications for " . $self->name() );
		return;
	}
	if ( ! $$self{'Specifications'}{$name} ) {
		#$openprint::log->warn("No specfications for ($name) " . $self->name() );
		return;
	}

	return $$self{'Specifications'}{$name}[0]->value() if ! defined $range;
#$openprint::log->debug("Looking for $name : $range") if $debug;

	$range = 1*$range;
	my $i = 0;
	my $x;
	my $y;
	for ( ; $i < @{$$self{'Specifications'}{$name}}; $i += 1 ) {
		my $Spec = $$self{'Specifications'}{$name}[$i];
	#$openprint::log->debug("Examining: ($$Spec{min}) ($$Spec{max}) ($$Spec{value}) ($$Spec{interpolate}") if $debug;
		return $$Spec{value} if ( 1*$$Spec{min} == $range ) or ( 1*$$Spec{max} == $range );

		return $$Spec{value} if (
				( ! $$Spec{interpolate} )
				and (($$Spec{min} eq '') or ($$Spec{min} <= $range))
				and (($$Spec{max} eq '') or ($$Spec{max} >= $range))
				);

		# first step, find one less than the min
		last if $$Spec{min} > $range;
		#last if ( $Spec->max() eq '' and ! $Spec->interpolate() );
	} # end if
	
	if ( $i and $i <= @{$$self{'Specifications'}{$name}} ) {
		$i -= 1;
		# back up
		$x = $$self{'Specifications'}{$name}[$i];
#$openprint::log->debug("Found spec " . $x->min() . ' ' . $x->max() . ' : ' . $x->value() ) if $debug;
		return if ( ( ! $$x{interpolate} ) and (1*$$x{max}) and ( $$x{max} < $range ) );
	} else {
$openprint::log->debug("Couldn't find monimum") if $debug;
		return;	
	} # end if
	
	for ( ; $i < @{$$self{'Specifications'}{$name}}; $i += 1 ) {
		my $Spec = $$self{'Specifications'}{$name}[$i];
		
		return $$Spec{value} if ( ( ! $$Spec{interpolate} ) and ( $$Spec{max} == $range or $$Spec{max} eq '' ));

		# first step, find one less than the min
		last if $$Spec{max} > $range;
	} # end foreach
	if ( $i and $i < @{$$self{'Specifications'}{$name}} ) {
		# back up
		$y = $$self{'Specifications'}{$name}[$i];
$openprint::log->debug("Found spec max " . $y->min() . ' ' . $y->max() . ' : ' . $y->value() ) if $debug;
	} else {
$openprint::log->debug("Couldn't find maximum") if $debug;
		return;
	} # end if

	my $value;
	if ( $x == $y ) {
		$value = $x->value();
	} elsif ( $x->interpolate() ) {
		$value = $x->value() + ($range - $x->min())*($y->value()-$x->value())/($y->min()-$x->min());
	} # end if
$openprint::log->debug("Returning " . $value);

	return $value;
} # end sub specification

sub Specifications {
	my $self = shift;
	return openprint::MaterialSpecification::find( 'Material'=>$self, 'order'=>'name,min' );
} # end sub Specifications

sub find {
	my %params = @_;
	my $sql = 'SELECT * FROM Materials WHERE 1>0';
	my @values;

	if ( exists $params{'name'} ) {
		# cache optimisation, if we are looking up just by name, then we can do a quick idnex lookup
		if ( ( keys %params ) == 1 ) {
			if ( $cache{$params{name}} ) {
				return ( new openprint::Material( $cache{$params{name}} ) );
			} # end if
		} # end if
		$sql .= ' AND name=?';
		push @values, $params{'name'};
	} # end if
	if ( $params{'name_like'} ) {
		$sql .= ' AND name LIKE ?';
		push @values, $params{'name_like'};
	} # end if
	if ( $params{'category_id'} ) {
		$sql .= ' AND category_id=?';
		push @values, $params{'category_id'};
	} # end if
	if ( $params{'category'} ) {
		$sql .= ' AND category_id=(SELECT id FROM Material_Categories WHERE name=?)';
		push @values, $params{'category'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading Material ($sql) (@values) Reason: " . $openprint::dbh->errstr );
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Material ($sql) (@values) " . @$data );
	} # end if
	return map { new openprint::Material( $_->{id}, $_ ) } @$data;
} # end sub find

sub get_price {
	my ( $self, $quantity, $equipment ) = @_;

	if ( ref $equipment eq 'openprint::Equipment' ) {
		$equipment = $equipment->id();
	} # end if

	my $list_id = openprint::pricing::get_pricelist_id( $openprint::log, $openprint::dbh, $openprint::variable );
	my %price = openprint::pricing::get_best_price_object( $openprint::log, $openprint::dbh, $openprint::session{'company_id'}, $$self{id}, $list_id, 'openprint::material_priceset', $quantity, $equipment );
	return if ! %price;

	my $Pricelist = new openprint::Pricelist( $list_id );
	$price{'currency_id'} = $Pricelist->currency_id();
	openprint::Currency::convert( \%price );

	return %price;
} # end sub get_price

sub next {
	my ($self, $params) = shift;
	my $sql = q{SELECT min(name) FROM Materials WHERE name > ?};
	my @values = ($$self{'name'});
	if ( $params and $$params{category_id} ) {
		$sql .= ' AND category=?';
		push @values, $$params{category_id};
	} # end if
    my ($name) = sql::execute( undef, undef, $sql, @values );
	( $_ ) = sql::execute( undef, undef, q{SELECT id FROM Materials WHERE name=?}, $name );
    return $_;
} # end sub next

sub Next {
	my ($self, $params) = shift;
	return new openprint::Material( $self->next($params) );
} # end sub Next

sub prev {
    my ( $self, $params ) = shift;
	my $sql = q{SELECT max(name) FROM Materials WHERE name < ?};
	my @values = ($$self{'name'});
	if ( $params and $$params{category_id} ) {
		$sql .= ' AND category=?';
		push @values, $$params{category_id};
	} # end if
    my ($name) = sql::execute( undef, undef, $sql, @values );
	( $_ ) = sql::execute( undef, undef, q{SELECT id FROM Materials WHERE name=?}, $name );
    return $_;
} # end sub next

sub Previous {
	my ($self, $params) = shift;
	return new openprint::Material( $self->prev($params) );
} # end sub Next

# Returns a copy of the Material object.
sub copy {
	my $self = shift;
	my $new = new openprint::Material();
	@$new{keys %fields} = @$self{keys %fields};
	delete $$new{id};
	$$new{'name'} = 'Copy of ' . $$new{'name'};

	return $new;
} # end sub copy

1;
__END__
