use strict;
require openprint::Log;
require openprint::Product;
require openprint::ProjectType;
package openprint::Product_Category;
our @ISA = qw( openprint::Object );
use vars qw( $debug $serial $table %fields %transforms %defaults );

$debug = 0;
$serial = 'product_categories_id_seq';
$table = 'Product_Categories';

%fields = (
		'id'				=>	'id',
		'name'				=>	'name',
		'description'		=>	'description',
		'projecttype_id'	=>	'projecttype_id',
);

%defaults = (
		'projecttype_id'	=>	undef,
);


sub delete {
	my $self = shift;
	return if ! $$self{'id'};
	my $error = '';
	my $ac = sql::start_transaction( $openprint::dbh );
	foreach my $Product ( openprint::Product->find( 'category_id' => $$self{'id'},'deleted'=>[0,1] ) ) {
		$error .= $Product->save({'category_id'=>undef});
	} # end foreach
	$error .= $self->SUPER::destroy() ;
	sql::end_transaction( $openprint::dbh, $ac );
	
	# Add record to audit log - action "Delete Product Category".
	new openprint::Log()->save({'action'=>'Delete Product Category', 'note'=> "Product Category ID: $$self{id} Name: $$self{name}"});
	return $error;
} # end sub delete

sub destroy {
	my $self = shift;
	return if ! $$self{'id'};
	my $error = '';
	my $ac = sql::start_transaction( $openprint::dbh );
	foreach my $Product ( openprint::Product->find( 'category_id' => $$self{'id'},'deleted'=>[0,1] ) ) {
		$error .= $Product->save({'category_id'=>undef});
	} # end foreach
	$error .= $self->SUPER::destroy() ;
	sql::end_transaction( $openprint::dbh, $ac );
	
	# Add record to audit log - action "Delete Product Category".
	new openprint::Log()->save({'action'=>'Delete Product Category', 'note'=> "Product Category ID: $$self{id} Name: $$self{name}"});
	return $error;
} # end sub destroy

sub products {
	my $self = shift;
	my %params = @_;
	$params{'category_id'} = $$self{'id'};

	return openprint::Product->find( %params );
} # end sub products

sub ProjectType {
	my $self = shift;

	return new openprint::ProjectType( $$self{projecttype_id} );
	
} # end sub Type

1;
__END__
