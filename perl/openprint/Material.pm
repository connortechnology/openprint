use strict;
package openprint::Material;
our @ISA = qw( openprint::Object );
use Memoize;

require sql;
require openprint::Object;

require openprint::logs;
require openprint::MaterialSpecification;
require openprint::MaterialCategory;

use vars qw{ $debug $log $dbh %session $table $serial %fields %find_fields %transforms %defaults $cache_field $cached };
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;

$debug = 0;
$cached = 0;
$table = 'materials';
$serial = 'materialindex_seq';

%fields = (
		id				=>	'id',
		name			=>	'name',
		description		=>	'description',
		supplier_id		=>	'supplier_id',
		category_id		=>	'category_id',
		taxexempt1		=>	'taxexempt1',
		taxexempt2		=>	'taxexempt2',
		activity_code	=>	'activity_code',
		);	
%find_fields = (
		category		=>	'(SELECT name FROM Material_Categories WHERE id=category_id)',
		equipment_id	=>	'(SELECT lngequipmentindex FROM tbl_material_prices WHERE lngmaterialindex=materials.id)',
);

%transforms = (
		);

%defaults = (
		supplier_id	=>	undef,
		category_id	=>	undef,
		taxexempt1	=>	q`'N'`,
		taxexempt2	=>	q`'N'`,
		);

$cache_field = 'name';
sub cache_field {
	return 'name';
}
sub delete {
	my $self = shift;

	delete $openprint::Object::cache{'openprint::Material'}{$$self{id}} if $openprint::Object::cache{'openprint::Material'};	

	my $ac = sql::start_transaction( $dbh );
	sql::execute( undef, undef, q{DELETE FROM Material_Specifications WHERE material_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM tbl_Material_Prices WHERE lngMaterialIndex=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM Materials WHERE id=?}, $$self{'id'} );
	openprint::logs::insertLogRecord('8', "Material Id: $$self{'id'} Material Name: $$self{'name'}" );
	sql::end_transaction( $dbh, $ac );

	init_cache();
} # end sub delete

sub prices {
	my $self = shift;

	return openprint::MaterialPrice->find('material_id'=>$$self{id});
} # end sub prices

sub New_Specification {
	my ( $self, $name, $options ) = @_;

	if ( ! $$self{'NewSpecifications'} ) {
		foreach my $Spec ( openprint::MaterialSpecification->find( 'material_id'=>$$self{id}, 'order'=>'equipment_id, min NULLS FIRST' ) ) {
			push @{$$self{'NewSpecifications'}{$$Spec{equipment_id}}{$$Spec{name}}}, $Spec;
		} # end foreach
	} # end if
	if ( ! $$self{'NewSpecifications'} ) {
		$openprint::log->warn("No specfications for " . $self->name() );
		return;
	} # end if
#if ( $debug ) {
	#$openprint::log->debug("Looking for " . $self->name() . " equipment: $$options{equipment_id} range: $$options{range} spec: $name");
#} # end if debug

	if ( $$self{'NewSpecifications'}{$$options{equipment_id}} and $$self{NewSpecifications}{$$options{equipment_id}}{$name}) {
		return $$self{'NewSpecifications'}{$$options{equipment_id}}{$name}[0] if ! defined $$options{range};
		return misc::find_entry( $$options{range}, $$self{'NewSpecifications'}{$$options{equipment_id}}{$name}, $debug );
	} elsif ( $$self{'NewSpecifications'}{''} and $$self{NewSpecifications}{''}{$name}) {
#$log->debug("Look by emptry press");
		return $$self{'NewSpecifications'}{''}{$name}[0] if ! defined $$options{range};
#$log->debug("Calling find_entry $$options{range}");
		my $v = misc::find_entry( $$options{range}, $$self{'NewSpecifications'}{''}{$name}, $debug );
#$log->debug("Returned $v: $$v{value}");
		return $v;
	} # end if 
	$openprint::log->warn("No specfications for " . $self->name() . " Looking for equipment: $$options{equipment_id} spec: $name") if $debug;
	return;

} # end sub New_Specification

sub Specification {
	my ( $self, $name, $range ) = @_;

	if ( ! $$self{'Specifications'} ) {
		foreach my $Spec ( openprint::MaterialSpecification->find( 'material_id'=>$$self{'id'}, 'order'=>'min NULLS FIRST' ) ) {
			push @{$$self{'Specifications'}{$Spec->name()}}, $Spec;
		} # end foreach

	if ( ! $$self{'Specifications'} ) {
		$$self{'Specifications'} = {};
		#$openprint::log->warn("No specfications for " . $self->name() );
		return;
	}
	} # end if
	if ( ! $$self{'Specifications'}{$name} ) {
		#$openprint::log->warn("No specfications for ($name) " . $self->name() );
		return;
	}

	return $$self{'Specifications'}{$name}[0] if ! defined $range;
#$openprint::log->debug("Looking for $name : $range") if $debug;

	return misc::find_entry( $range, $$self{'Specifications'}{$name}, $debug );
} # end sub Specification

sub specification {
	my $Spec = openprint::Material::Specification( @_ );
	return $$Spec{'value'} if $Spec;
} # end sub specification

sub Specifications {
	my $self = shift;
	return openprint::MaterialSpecification->find( 'material_id'=>$$self{'id'}, 'order'=>'name,min NULLS FIRST' );
} # end sub Specifications

sub get_price {
	return if ! $_[0]{id};
	my ( $self, $quantity, $Equipment ) = @_;

	my $Pricelist = openprint::Pricelist::get_current();
	my %price = openprint::pricing::get_best_price_object( $session{'company_id'}, $$self{id}, $$Pricelist{id}, 'openprint::material_priceset', $quantity, $$Equipment{'id'} );
	return if ! %price;

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

sub Category {
	return new openprint::MaterialCategory( $_[0]{'category_id'} );
}

1;
__END__
