package openprint::Product;
@ISA = qw( openprint::Object );

use strict;
require openprint::ProductCategory;
require openprint::logs;

require sql;

my $debug = 0;

use vars qw( %fields %defaults %transforms );
%fields = (
	'name'			=>	'name',
	'description'	=>	'description',
	'weight'		=>	'weight',
	'taxexempt1'	=>	'taxexempt1',
	'taxexempt2'	=>	'taxexempt2',
	'sort'			=>	'sort',
	'category_id'	=>	'category_id',
	'project_id'	=>	'project_id',
	'deleted'		=>	'deleted',
);

%transforms = (
);
%defaults = (
	'weight'		=>	undef,
	'taxexempt1'	=>	'N',
	'taxexempt2'	=>	'N',
	'sort'			=>	undef,
	'category_id'	=>	undef,
	'project_id'	=>	undef,
	'deleted'		=>	0,
);

sub find {
	my %params = @_;

	my @values;
	my $sql = 'SELECT * FROM Products WHERE 1>0';
	if ( $params{'id'} ) {
		$sql .= ' AND id=?';
		push @values, $params{'id'};
	} # end if
		
	if ( $params{'name'} ) {
		$sql .= ' AND name=?';
		push @values, $params{'name'};
	} # end if
	if ( $params{'category_id'} ) {
		$sql .= ' AND category_id=?';
		push @values, $params{'category_id'};
	} # end if

	if ( exists $params{'deleted'} ) {
		if ( $params{'deleted'} ) {
			$sql .= ' AND (deleted=? OR deleted IS NULL)', $params{'deleted'};
		} else {
			$sql .= ' AND deleted=?', $params{'deleted'};
		} # end if
	} else {
		$sql .= ' AND (deleted=false OR deleted IS NULL)';
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->error("Error loading Products: ($sql) (@values)");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Products: ($sql) (@values) " . @$data );
	} # end if
	return map { new openprint::Product( $_->{id}, $_ ); } @$data;
} # end sub find

sub delete {
	my $self = shift;
	sql::update( undef, undef, 'Products', ['id=?', $$self{id}], 'deleted', 1 );
} # end sub delete

sub destroy {
	my $self = shift;
	my $ac = sql::start_transaction( $openprint::dbh );
	foreach my $Price ( openprint::ProductPrice::find( 'Product' => $self ) ) {
		$Price->delete();
	} # end foreach

	sql::execute( undef, undef, q{DELETE FROM Product_Specifications WHERE product_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM Products WHERE id=?}, $$self{'id'} );
	sql::end_transaction( $openprint::dbh, $ac );
	
	# Add record to audit log - action "Delete Product".
	openprint::logs::insertLogRecord('17', "Product ID: " . $$self{'id'} . " Name: " . $$self{'name'},);
} # end sub destroy

# Returns a copy of the paper object.
# Will also save the data to db
sub copy {
	my $self = shift;
	my $Product = new openprint::Product( );
	@$Product{keys %fields} = @$self{keys %fields};
	$$Product{'name'} = 'Copy of '.$$Product{'name'};
	return $Product;
} # end sub copy

sub prices {
	my $self = shift;
	if ( ! exists $$self{'Prices'} ) {
		@{$$self{'Prices'}} = openprint::ProductPrice::find( 'product_id',	$$self{'id'});
	} # end if
	return @{$$self{'Prices'}};
} # end sub prices
sub Prices {
	my $self = shift;
	return $self->prices();
} # end sub Prices

sub save {
	my ( $self, $param ) = @_;

	$self->set( $param ) if $param;

	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$k} = $$self{$k};
	} # end foreach

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('Product_Id_seq')} );
		$sql{'id'} = $$self{'id'};
		if ( my $error = sql::insert( undef, undef, 'Products', %sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
		
		# Add record to audit log - action "New Product".
		openprint::logs::insertLogRecord('58', "Product ID: " . $$self{'id'} . " Name: " . $$self{'name'},);
	} else {
		if ( my $error = sql::update( undef, undef, 'Products', ['id=?', $$self{'id'}], \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
		
		# Add record to audit log - action "Update Product".
		openprint::logs::insertLogRecord('59', "Product ID: " . $$self{'id'} . " Name: " . $$self{'name'},);
	} # end if

	$_ = q{SELECT name, value FROM Product_Specifications WHERE product_id=?};
	my %specs = sql::execute( $openprint::log, $openprint::dbh, $_, $$self{'id'});
	foreach my $spec ( keys %{$$self{'Specifications'}} ) {
		if ( exists $specs{$spec} ) {
			if ( $specs{$spec} ne $$self{'Specifications'}{$spec} ) {
				sql::update( undef, undef, 'Product_Specifications', ['product_id=? AND Name=?', $$self{'id'}, $spec ], 
					'Value', $$self{'Specifications'}{$spec} );
			} else {
				$openprint::log->debug(" equal ( $specs{$spec} ) = ( $$self{'Specifications'}{$spec} )" );
			} # end if
			delete $specs{$spec};
		} else {
			sql::insert( undef, undef, 'Product_Specifications', 'product_id', $$self{'id'},
					'Name', $spec, 'Value', $$self{'Specifications'}{$spec} );
		} # end if
	} # end foreach
	foreach my $spec ( keys %specs ) {
		sql::execute( undef, undef, q{DELETE FROM Product_Specifications WHERE product_id=? AND name=?}, $$self{'id'}, $spec );
	} # end foreach
	sql::end_transaction( $openprint::dbh, $ac );

	$self->load();

	#foreach my $Price ( $self->prices() ) {
		#if ( $$Price{'ProductIndex'} != $$self{'id'} ) {
			#$$Price{'ProductIndex'} = $$self{'id'};
			#$$Price{'id'} = undef;
		#} # end if
		#$Price->save();
	#} # end foreach

	return '';
} # end sub save

sub load {
	my ( $self, $data ) = @_;

	if ( ! $$self{'id'} ) {
		$openprint::log->warn("Called Product::load without id");
		return;
	} # end if
	
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Products WHERE id=?', {}, $$self{'id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};

	$_ = q{SELECT name, value FROM Product_Specifications WHERE product_id=?};
	%{$$self{'Specifications'}} = sql::execute( $openprint::log, $openprint::dbh, $_, $$self{'id'});
} # end sub load

sub category {
	my $self = shift;
	return new openprint::ProductCategory( $$self{'category_id'} );
} # end sub category

sub get_price {
	my ( $self, $qty ) = @_;

	my $list_id = openprint::pricing::get_pricelist_id( $openprint::log, $openprint::dbh );

	my %price = openprint::pricing::get_best_price_object( $openprint::log, $openprint::dbh, $openprint::session{'company_id'}, $$self{'id'}, $list_id, 'openprint::product_priceset', $qty, undef );
	if ( ! %price ) {
$openprint::log->debug("Looking for a price $qty");
		foreach my $Price ( openprint::ProductPrice::find('product_id'=>$$self{'id'},'pricelist_id'=>$list_id,'order'=>'min desc') ) {
$openprint::log->debug("Looking at $$Price{min}");
			next if $$Price{'min'} > $qty;
			next if ! $$Price{'min'};
			if ( ! ( $qty % $$Price{'min'} ) ) {
				$price{'Price'} = $$Price{'price'} * $qty / $$Price{'min'};
			} # end if
		} # end foreach Price
	} # end if
	my $Pricelist = new openprint::Pricelist( $list_id );
	$price{currency_id} = $Pricelist->currency_id();
	openprint::Currency::convert( \%price );
	return %price;
} # end sub get_price

sub specifications {
	my $self = shift;
	return $$self{'Specifications'};
} # end sub specifications

sub specification {
	my $self = shift;
	my $spec = shift;
	return $$self{'Specifications'}{$spec};
} # end sub

sub add_specification {
	my $self = shift;
	my $spec = shift;
	return $$self{'Specifications'}{$spec} = shift;
} # end sub add_specification
sub del_specification {
	my $self = shift;
	my $spec = shift;
	delete $$self{'Specifications'}{$spec};
} # end sub del_specification

sub next {
	my $self = shift;
	my ( $id ) = sql::execute( undef, undef, q{SELECT id FROM Products WHERE name > (SELECT name FROM Products WHERE Id=?) ORDER BY name LIMIT 1}, $$self{'id'} );
	$id = $$self{'id'} if ! $id;
	
	return new openprint::Product( $id );
} # end sub next 
sub previous {
	my $self = shift;
	my ( $id ) = sql::execute( undef, undef, q{SELECT id FROM Products WHERE name < (SELECT name FROM Products WHERE Id=?) ORDER BY name DESC LIMIT 1}, $$self{'id'} );
	$id = $$self{'id'} if ! $id;
	
	return new openprint::Product( $id );
} # end sub previous

1;
__END__
