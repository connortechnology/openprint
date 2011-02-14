package openprint::Material;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;

require openprint::logs;
require openprint::MaterialSpecification;
require openprint::MaterialCategory;

use vars qw{ $debug $log $dbh %session $table $serial %fields %find_fields %transforms %defaults };
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \$openprint::session;

$table = 'Materials';
$serial = 'MaterialIndex_seq';

$debug = 1;

%fields = (
		'id'				=>	'id',
		'name'				=>	'name',
		'description'		=>	'description',
		'supplier_id'		=>	'supplier_id',
		'category_id'		=>	'category_id',
		'taxexempt1'		=>	'taxexempt1',
		'taxexempt2'		=>	'taxexempt2',
		);	
%find_fields = (
		'category'	=>	'(SELECT name FROM Material_Categories WHERE id=category_id)',
		'equipment_id'	=> '(SELECT lngequipmentindex FROM tbl_material_prices WHERE lngmaterialindex=materials.id)',
);

%transforms = (
		);

%defaults = (
		'supplier_id'	=>	undef,
		'category_id'	=>	undef,
		'taxexempt1'	=>	'N',
		'taxexempt2'	=>	'N',
		);

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

sub Specification {
	my ( $self, $name, $range ) = @_;

	if ( ! $$self{'Specifications'} ) {
		foreach my $Spec ( openprint::MaterialSpecification->find( 'material_id'=>$$self{'id'}, 'order'=>'min' ) ) {
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

	return $$self{'Specifications'}{$name}[0] if ! defined $range;
#$openprint::log->debug("Looking for $name : $range") if $debug;

	return misc::find_entry( $range, $$self{'Specifications'}{$name} );
} # end sub Specification

sub specification {
	my $Spec = openprint::Material::Specification( @_ );
	return $$Spec{'value'} if $Spec;
} # end sub specification

sub Specifications {
	my $self = shift;
	return openprint::MaterialSpecification->find( 'Material'=>$self, 'order'=>'name,min' );
} # end sub Specifications

sub get_price {
	my ( $self, $quantity, $Equipment ) = @_;

	return if ! $$self{'id'};

	my $list_id = openprint::pricing::get_pricelist_id();
	my %price = openprint::pricing::get_best_price_object( $log, $dbh, $session{'company_id'}, $$self{id}, $list_id, 'openprint::material_priceset', $quantity, $$Equipment{'id'} );
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

sub Category {
	return new openprint::MaterialCategory( $_[0]{'category_id'} );
}

1;
__END__
