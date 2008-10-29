package openprint::ServicePrice;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;
require openprint::logs;
use openprint;
use vars qw( %variable %session %param %config $log $dbh %fields %transforms %defaults );
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;


%fields = (
	'owner_id'		=>	'owner_id',
	'pricelist_id'	=>	'pricelist_id',
	'service_id'	=>	'service_id',
	'equipment_id'	=>	'equipment_id',
	'min'			=>	'min',
	'max'			=>	'max',
	'units'			=>	'units',
	'cost'			=>	'cost',
	'markup'		=>	'markup',
	'price'			=>	'price',
	'discountable'	=>	'discountable',
	'interpolate'	=>	'interpolate',
);

sub find {
	my %params = @_;
	my $sql = 'SELECT * FROM Service_Prices WHERE 1>0';
	my @values;

	if ( $params{'pricelist_id'} ) {
		$sql .= ' AND pricelist_id=?';
		push @values, $params{'pricelist_id'};
	} # end if
	if ( $params{'Pricelist'} ) {
		$sql .= ' AND pricelist_id=?';
		push @values, $params{'Pricelist'}->id();
	} # end if
	if ( $params{'service_id'} ) {
		$sql .= ' AND service_id=?';
		push @values, $params{'service_id'};
	} # end if
	if ( $params{'Service'} ) {
		$sql .= ' AND service_id=?';
		push @values, $params{'Service'}->id();
	} # end if
	if ( $params{'equipment_id'} ) {
		$sql .= ' AND equipment_id=?';
		push @values, $params{'equipment_id'};
	} # end if
	if ( $params{'Equipment'} ) {
		if ( $params{'Equipment'}->id() ) {
			$sql .= ' AND equipment_id=?';
			push @values, $params{'Equipment'}->id();
		} else {
			$sql .= ' AND equipment_id IS NULL';
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading Service Price ($sql) (@values) Reason: " . $openprint::dbh->errstr );
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Service Price ($sql) (@values) " . @$data );
	} # end if
	return map { new openprint::ServicePrice( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Service_Prices WHERE id=?', {}, $$self{'id'} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};

} # end sub load

sub delete {
	my $self = shift;

	sql::execute( undef, undef, 'DELETE FROM Service_Prices WHERE id=?', $$self{'id'} );
	openprint::logs::insertLogRecord('13', "Service Price ID: " . $$self{'id'},);
} # end sub delete

sub save {
	my ( $self, $param ) = @_;

	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('serviceprices_id_seq')} );
		sql::insert( undef, undef, 'Service_Prices',
				'id',				$$self{'id'},
				'pricelist_id',		$$self{'pricelist_id'},
				'service_id',		$$self{'service_id'},
				'equipment_id', 	$$self{'equipment_id'} eq '' ? undef : $$self{'equipment_id'},
				'min',			$$self{'min'} eq '' ? undef : $$self{'min'},
				'max',			$$self{'max'} eq '' ? undef : $$self{'max'},
				'units',			$$self{'units'},
				'cost',				1*$$self{'cost'},
				'markup',			1*$$self{'markup'},
				'price',			1*$$self{'price'},
				'discountable',	$$self{'discountable'},
				);
	} else {
		sql::update( undef, undef, 'Service_Prices', ['id=?', $$self{'id'}],
				'pricelist_id',		$$self{'pricelist_id'},
				'service_id',		$$self{'service_id'},
				'equipment_id', 	$$self{'equipment_id'} eq '' ? undef : $$self{'equipment_id'},
				'min',			$$self{'min'} eq '' ? undef : $$self{'min'},
				'max',			$$self{'max'} eq '' ? undef : $$self{'max'},
				'units',			$$self{'units'},
				'cost',				1*$$self{'cost'},
				'markup',			1*$$self{'markup'},
				'price',			1*$$self{'price'},
				'discountable',	$$self{'discountable'},
				);
	} # end if
} # end sub save

sub next {
	my $self = shift;
	return new openprint::ServicePrice( sql::execute( undef,undef, q{SELECT MIN(Index) WHERE Index > ?}, $$self{'id'} ) );
} # end sub next

1;

__END__
~       
