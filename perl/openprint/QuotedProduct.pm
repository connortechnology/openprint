package openprint::QuotedProduct;
@ISA = qw(openprint::Product);

use strict;
use openprint ();
use vars qw( $log $dbh %session %config $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
*config = \%openprint::config;

require sql;
require openprint::QuoteLevel;

my $debug = 0;

$table = 'Quoted_Products';
$serial = 'Quoted_Products_id_seq';

%fields = (
			'id'			=>	'id',
			'quantity'		=>	'quantity',
			'markup'		=>	'markup',
			'cost'			=>	'cost',
			'price'			=>	'price',
			'product_id'	=>	'proect_id',
			'quote_id'		=>	'quote_id',
);

%transforms = (
	'quantity'	=> [ 's/[^\d\.\-]//g' ],
	'markup'	=> [ 's/[^\d\.\-]//g' ],
	'price'		=> [ 's/[^\d\.\-]//g' ],
	'cost'		=> [ 's/[^\d\.\-]//g' ],
);

%defaults = (
	'id'		=> undef,
	'markup'	=> undef,
	'price'		=> undef,
	'cost'		=> undef,
);

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM Quoted_Products WHERE 1>0';
	my @values;

	if ( $params{'quote_id'} ) {
		$sql .= ' AND quote_id=?';
		push @values, $params{'quote_id'};
	} # end if
	if ( $params{'product_id'} ) {
		$sql .= ' AND product_id=?';
		push @values, $params{'product_id'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::QuotedProduct::find( $sql)" . $openprint::dbh->errstr);
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("openprint::QuotedProduct::find( $sql) : returned " . @$data );
	} # end if
	return map { new openprint::QuotedProduct( $_->{id}, $_ ); } @$data;
} # end sub find
sub save {
	my ( $self, $hash ) = @_;

	$self->set( $hash ) if $hash;

	my %sql;
	@sql{@fields{keys %fields}} = @$self{keys %fields};

	my $ac = sql::start_transaction( $dbh );

	if ( ! $$self{'id'} ) {

		@sql{'id'} = @$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('tbl_quote_details_id_seq'::text)} );

		if ( my $e = sql::insert( undef, undef, 'tbl_Quote_Details', \%sql ) ) {
			$openprint::dbh->rollback;
			sql::end_transaction( $dbh, $ac );
			return $e;
		} # end if
	} else {
		if ( my $e = sql::update( undef, undef, 'tbl_Quote_Details', ['id=?', $$self{'id'}], \%sql ) ) {
			$dbh->rollback;
			sql::end_transaction( $dbh, $ac );
			return $e;
		} # end if
	} # end if
	$self->load();
	sql::end_transaction( $dbh, $ac );
	return;
} # eend sub save

sub load {
	my ( $self, $data ) = @_;

	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM tbl_quote_details WHERE id=?}, {}, $$self{'id'} );
	} # end if
	if ( ! $data ) {
		$openprint::log->error("Error loading Product $$self{'id'}: ".$openprint::dbh->errstr() );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
	if ( $debug ) {
		$openprint::log->debug("Loaded values of Quoted Product");
		foreach my $k ( keys %fields ) {
			$openprint::log->debug("$k => $$self{$k}");
		} # end foreach
	} # end if
	return;
} # end sub load

sub delete {
	sql::execute( undef, undef, 'DELETE FROM tbl_quote_details WHERE quote_id=? AND project_id=?', $_[0]{'quote_id'}, $_[0]{'project_id'} );
} # end sub delete

sub template_id {
	if ( @_ > 1 ) {
		$_[0]{'template_id'} = $_[1];
	} # end if
	if ( $_[0]{'template_id'} ) {
		return $_[0]{'template_id'};
	} else {
		return $_[0]->Product()->style_id();
	} # end if
} # end sub template_id

sub Template {
	if ( $_[0]{'template_id'} ) {
		return new openprint::QuoteLevel( $_[0]{'template_id'} );
	} else {
		return $_[0]->Product()->Template();
	} # end if
} # end sub Template

sub Product {
	return new openprint::Product( $_[0]{'project_id'} );
} # end sub Product
sub markup {
	my ( $self, $qty_index, $new_value ) = @_;
	if ( defined $new_value ) {
		$$self{'markup'.$qty_index} = $new_value;
	} # end if
	return $$self{'markup'.$qty_index};
} # end sub total
sub price {
	my ( $self, $qty_index, $new_value ) = @_;
	if ( defined $new_value ) {
		$$self{'price'.$qty_index} = $new_value;
	} # end if
	if ( ! (1*$$self{'price'.$qty_index}) ) {
		$$self{'price'.$qty_index} = sprintf('%.2f', $self->Product()->price($qty_index) * ( 1 + $$self{'markup'}/100 ) );
	} # end if
	return $$self{'price'.$qty_index};
} # end sub total
sub quantity {
	my ( $self, $qty_index, $new_value ) = @_;
	if ( defined $new_value ) {
		$$self{'quantity'.$qty_index} = $new_value;
	} # end if
	return $$self{'quantity'.$qty_index};
} # end sub total
1;

__END__
