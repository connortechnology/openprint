use strict;
package openprint::MaterialPrice;
our @ISA = qw( openprint::Object );

require sql;
require openprint::Object;
require openprint::logs;
use Math::Round qw(nearest);


use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'tbl_material_prices';
$serial = 'materialprices_id_seq';

%fields = (
	'id'			=>  'id',
	'pricelist_id'	=>	'lnglistindex',
	'material_id'	=>	'lngmaterialindex',
	'equipment_id'	=>	'lngequipmentindex',
	'min'			=>	'lngmin',
	'max'			=>	'lngmax',
	'units'			=>	'strunits',
	'cost'			=>	'dblcost',
	'markup'		=>	'dblmarkup',
	'price'			=>	'dblprice',
	'discountable'	=>	'ysndiscountable',
	'interpolate'	=>	'interpolate',
);

%defaults = (
	'min'	=>	undef,
	'max'	=>	undef,
	'cost'	=>	undef,
	'markup'	=>	undef,
	'price'		=>	undef,
	'discountable'	=>	1,
	'interpolate'	=>	0,
);

%transforms = (
	'min'	=>	[ 's/[^\d\.\-]//g' ],
	'max'	=>	[ 's/[^\d\.\-]//g' ],
	'cost'	=>	[ 's/[^\d\.\-]//g' ],
	'markup'	=>	[ 's/[^\d\.\-]//g' ],
	'price'	=>	[ 's/[^\d\.\-]//g' ],
);

sub find {
	if ( $_[0] eq 'openprint::MaterialPrice' ) {
		shift;
	}
	my %params = @_;
	my $sql = 'SELECT * FROM tbl_Material_Prices WHERE 1>0';
	my @values;

	if ( $params{'pricelist_id'} ) {
		$sql .= ' AND lnglistindex=?';
		push @values, $params{'pricelist_id'};
	} # end if
	if ( $params{'Pricelist'} ) {
		$sql .= ' AND lnglistindex=?';
		push @values, $params{'Pricelist'}->id();
	} # end if
	if ( $params{'material_id'} ) {
		$sql .= ' AND lngmaterialindex=?';
		push @values, $params{'material_id'};
	} # end if
	if ( $params{'Material'} ) {
		$sql .= ' AND lngmaterialindex=?';
		push @values, $params{'Material'}->id();
	} # end if
	if ( $params{'equipment_id'} ) {
		$sql .= ' AND lngEquipmentIndex=?';
		push @values, $params{'equipment_id'};
	} # end if
	if ( $params{'Equipment'} ) {
		if ( $params{'Equipment'}->id() ) {
		$sql .= ' AND lngEquipmentIndex=?';
		push @values, $params{'Equipment'}->id();
		} else {
		$sql .= ' AND lngEquipmentIndex IS NULL';
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading Material Price ($sql) (@values) Reason: " . $openprint::dbh->errstr );
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Material Price ($sql) (@values) " . @$data );
	} # end if
	return map { new openprint::MaterialPrice( $_->{id}, $_ ) } @$data;
} # end sub find

sub delete {
	my $self = shift;

	sql::execute( undef, undef, 'DELETE FROM tbl_Material_Prices WHERE id=?', $$self{'id'} );
	openprint::logs::insertLogRecord('13', "Material Price ID: " . $$self{'id'},);
} # end sub delete

sub next {
	my $self = shift;
	return new openprint::MaterialPrice( sql::execute( undef,undef, q{SELECT MIN(Index) WHERE Index > ?}, $$self{'id'} ) );
} # end sub next

sub markup {
    if ( @_ > 1 ) {
        $_[0]{'markup'} = $_[1];
		$_[0]{'markup'} =~ s/[^\d\.\-]//g;
        $_[0]->price( undef );
    } # end if
    return $_[0]{'markup'};
} # end sub markup
sub cost {
    if ( @_ > 1 ) {
        $_[0]{'cost'} = $_[1];
		$_[0]{'cost'} =~ s/[^\d\.\-]//g;
        $_[0]->price( undef );
    } # end if
    return $_[0]{'cost'};
} # end sub cost
sub price {

    if ( @_ > 1 ) {
        $_[0]{'price'} = $_[1];
    } # end if
	my $self = $_[0];
    if ( ! defined $_[0]{'price'} ) {
        $_[0]{'price'} = Math::Round::nearest( .01, $_[0]{'cost'} * ( 1+($_[0]{'markup'}/100) ) );
    } # end if
    return $_[0]{'price'};
} # end sub price


sub Equipment {
	return new openprint::Equipment( $_[0]{'equipment_id'} );
} # end sub Equipment


1;

__END__
~       
