use strict;
package openprint::Material;
our @ISA = qw( openprint::Object );

require sql;
require openprint::Object;

require openprint::Log;
require openprint::MaterialSpecification;
require openprint::MaterialCategory;
require openprint::Manufacturer;

use vars qw{ $debug $log $dbh %session $table $serial %fields %find_fields %transforms %defaults $cache_field $cached };
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;

$debug = 0;
$cached = 0;
$table = 'materials';
$serial = 'materials_id_seq';

%fields = (
		id				=>	'id',
		name			=>	'name',
		description		=>	'description',
		supplier_id		=>	'supplier_id',
		supplier		=>	undef,
		category_id		=>	'category_id',
		category		=>	undef,
		taxexempt1		=>	'taxexempt1',
		taxexempt2		=>	'taxexempt2',
		activity_code	=>	'activity_code',
		manufacturer_id	=>	'manufacturer_id',
		);	
%find_fields = (
		category		=>	'(SELECT name FROM Material_Categories WHERE id=category_id)',
		equipment_id	=>	'(SELECT lngequipmentindex FROM tbl_material_prices WHERE lngmaterialindex=materials.id)',
);

%transforms = (
		name		=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
		description	=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
		);

%defaults = (
		supplier_id	=>	undef,
		category_id	=>	undef,
		taxexempt1	=>	q`'N'`,
		taxexempt2	=>	q`'N'`,
		manufacturer_id	=>	undef,
		);

$cache_field = 'name';
sub cache_field {
	return 'name';
}
sub delete {
	my $self = shift;

	delete $openprint::Object::cache{'openprint::Material'}{$$self{id}} if $openprint::Object::cache{'openprint::Material'};	

	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, q{DELETE FROM Material_Specifications WHERE material_id=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM tbl_Material_Prices WHERE lngMaterialIndex=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM Materials WHERE id=?}, $$self{id} );
	(new openprint::Log())->save({action=>'Delete', Object=>$self, note=>"Material Id: $$self{id} Material Name: $$self{name}"});
	sql::end_transaction( $dbh, $ac );

} # end sub delete

sub prices {
	my $self = shift;

	return openprint::MaterialPrice->find('material_id'=>$$self{id});
} # end sub prices

sub New_Specification {
	my ( $self, $name, $options ) = @_;

	if ( ! $$self{NewSpecifications} ) {
		foreach my $Spec ( openprint::MaterialSpecification->find( 'material_id'=>$$self{id}, 'order'=>'equipment_id, min NULLS FIRST' ) ) {
			push @{$$self{NewSpecifications}{$$Spec{equipment_id}}{$$Spec{name}}}, $Spec;
		} # end foreach
	} # end if
	if ( ! $$self{NewSpecifications} ) {
		$openprint::log->warn("No specfications for " . $self->name() );
		return;
	} # end if
#if ( $debug ) {
	#$openprint::log->debug("Looking for " . $self->name() . " equipment: $$options{equipment_id} range: $$options{range} spec: $name");
#} # end if debug

	if ( $$self{NewSpecifications}{$$options{equipment_id}} and $$self{NewSpecifications}{$$options{equipment_id}}{$name}) {
		return $$self{NewSpecifications}{$$options{equipment_id}}{$name}[0] if ! defined $$options{range};
		return misc::find_entry( $$options{range}, $$self{NewSpecifications}{$$options{equipment_id}}{$name}, $debug );
	} elsif ( $$self{NewSpecifications}{''} and $$self{NewSpecifications}{''}{$name}) {
#$log->debug("Look by emptry press");
		return $$self{NewSpecifications}{''}{$name}[0] if ! defined $$options{range};
#$log->debug("Calling find_entry $$options{range}");
		my $v = misc::find_entry( $$options{range}, $$self{NewSpecifications}{''}{$name}, $debug );
#$log->debug("Returned $v: $$v{value}");
		return $v;
	} # end if 
	$openprint::log->warn("No specfications for " . $self->name() . " Looking for equipment: $$options{equipment_id} spec: $name") if $debug;
	return;

} # end sub New_Specification

sub Specification {
	#my ( $self, $name, $range ) = @_;

	if ( ! $_[0]{Specifications} ) {
		foreach my $Spec ( openprint::MaterialSpecification->find( material_id=>$_[0]{id}, order=>'min NULLS FIRST' ) ) {
			push @{$_[0]{Specifications}{$Spec->name()}}, $Spec;
		} # end foreach
		if ( ! $_[0]{Specifications} ) {
#$openprint::log->warn("No specfications for " . $self->name() );
			$_[0]{Specifications} = {};
			return;
		}
	} # end if

	if ( ! $_[0]{Specifications}{$_[1]} ) {
		#$openprint::log->warn("No specfications for ($name) " . $self->name() );
		return;
	}

	return $_[0]{Specifications}{$_[1]}[0] if ! defined $_[2];
#$openprint::log->debug("Looking for $name : $range") if $debug;

	return misc::find_entry( $_[2], $_[0]{Specifications}{$_[1]}, $_[3] );
} # end sub Specification

sub specification {
	my $Spec = openprint::Material::Specification( @_ );
	return $$Spec{value} if $Spec;
} # end sub specification

sub Specifications {
	return openprint::MaterialSpecification->find( material_id=>$_[0]{id}, order=>'name,min NULLS FIRST' );
} # end sub Specifications

sub get_price {
	return if ! $_[0]{id};
	my ( $self, $quantity, $Equipment ) = @_;

	my $Pricelist = $openprint::Pricelist ? $openprint::Pricelist : openprint::Pricelist::get_current();
	my %price = openprint::pricing::get_best_price_object( $session{company_id}, $$self{id}, $$Pricelist{id}, 'openprint::material_priceset', $quantity, $$Equipment{id} );
	return if ! %price;

	$price{currency_id} = $Pricelist->currency_id();
	openprint::Currency::convert( \%price ) if $$Pricelist{currency_id} != $openprint::session{Pricelist_id};

	return %price;
} # end sub get_price

sub get_Price {
	return if ! $_[0]{id};
	my ( $self, $quantity, $Equipment ) = @_;

	my $Pricelist = $openprint::Pricelist ? $openprint::Pricelist : openprint::Pricelist::get_current();
	my %price = openprint::pricing::get_best_price_object( $session{company_id}, $$self{id}, $$Pricelist{id}, 'openprint::material_priceset', $quantity, $$Equipment{id} );
	return if ! %price;

	$price{currency_id} = $Pricelist->currency_id();
	openprint::Currency::convert( \%price ) if $$Pricelist{currency_id} != $openprint::session{Pricelist_id};

	return \%price;
}

sub next {
	my ($self, $params) = shift;
	my $sql = q{SELECT min(name) FROM Materials WHERE name > ?};
	my @values = ($$self{name});
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
	my @values = ($$self{name});
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

sub Category {
	return new openprint::MaterialCategory( $_[0]{category_id} );
}

sub minimum_order {
	return undef;
}

sub Manufacturer {
    return openprint::Manufacturer( $_[0]{manufacturer_id} );
}
sub manufacturer {
    if ( defined $_[1] ) {
        $_[1] = openprint::Manufacturer->transform( 'name', $_[1] );
        if ( ! $_[0]{custom} ) {
            my $Manufacturer = openprint::Manufacturer->find_one('name lc'=> lc $_[1] );
            if ( $Manufacturer ) {
                @{$_[0]}{'manufacturer_id','manufacturer'} = @$Manufacturer{'id','name'};
            } else {
                @{$_[0]}{'manufacturer_id','manufacturer'} = ( undef, $_[1] );
            } # end if
        } else {
            $_[0]{manufacturer} = $_[1];
            $_[0]{manufacturer_id} = undef;
        } # end if
    } elsif ( $_[0]{manufacturer_id} and ! $_[0]{manufacturer} ) {
        $_[0]{manufacturer} = new openprint::Manufacturer( $_[0]{manufacturer_id} )->name();
    } # end if
    return $_[0]{manufacturer};
} # end sub manufacturer

sub Unit_Of_Measure_Purchase {
	'';
} # end sub  Unit_Of_Measure_Purchase
sub Unit_Of_Measure_Costing {
	'';
} # end sub  Unit_Of_Measure_Costing

sub link_to {
	if ( $openprint::session{user_type} eq 'A' ) {
		return sprintf('<a href="/administrator/materials/edit.html?material_id=%d">%s</a>', $_[0]{id}, ( @_ > 1 ? $_[1] : $_[0]{name} ) );
	} else {
		return @_ > 1 ? $_[1] : $_[0]{name};
	}
}
sub category {
    my ( $self, $category ) = @_;

    if ( defined $category ) {
        $category =~ s/^\s*(.*)\s*$/$1/;
        @$self{'category_id','category'} = sql::execute( undef, undef, q{SELECT id, name FROM Material_Categories WHERE lower(name)=?}, lc $category );
        if ( ! $$self{category_id} ) {
            $$self{category} = $category;
        } # end if
    } elsif ( $$self{category_id} and ! $$self{category} ) {
        $$self{category} = new openprint::MaterialCategory( $$self{category_id} )->name();
    } # end if
    return $$self{category};
} # end sub category

sub supplier {
	if ( ( ! $_[0]{supplier} ) and $_[0]{supplier_id} ) {
		my $Supplier = new openprint::Company( $_[0]{supplier_id} );
		$_[0]{supplier} = $Supplier->name();
	}
	return $_[0]{supplier};
}
		
		


1;
__END__
