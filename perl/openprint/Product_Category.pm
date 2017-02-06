use strict;
require openprint::Log;
require openprint::Product;
require openprint::ProjectType;
package openprint::Product_Category;
our @ISA = qw( openprint::Object );
use vars qw( $debug $serial $table %fields %transforms %defaults );

$debug = 1;
$serial = 'product_categories_id_seq';
$table = 'Product_Categories';

%fields = (
	id				=>	'id',
	name			=>	'name',
	description		=>	'description',
	projecttype_id	=>	'projecttype_id',
	parent_id		=>	'parent_id',
);

%transforms = (
    name => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
    description => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	parent_id		=>	undef,
	projecttype_id	=>	undef,
);


sub delete {
	my $self = shift;
	return if ! $$self{'id'};
	my $error = '';
	my $ac = sql::start_transaction( $openprint::dbh );
	foreach my $Product ( openprint::Product->find( 'category_id' => $$self{'id'},'deleted'=>[0,1] ) ) {
		$error .= $Product->save({'category_id'=>undef});
	} # end foreach
	$error .= $self->SUPER::delete();
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
	$error .= $self->SUPER::destroy();
	sql::end_transaction( $openprint::dbh, $ac );
	
	# Add record to audit log - action "Delete Product Category".
	new openprint::Log()->save({'action'=>'Delete Product Category', 'note'=> "Product Category ID: $$self{id} Name: $$self{name}"});
	return $error;
} # end sub destroy

sub products {
Carp::cluck("Deprecated call openprint::Product_Category::products");
	return $_[0]->Products();
} # end sub products
sub Products {
	my $self = shift;
	my %params = @_;
	$params{category_id} = $$self{id};

	return openprint::Product->find( %params );
} # end sub products

sub Photos {
    if ( ! $_[0]{'album_id'} ) {
        return ();
    } # end if
    return $_[0]->Album()->Photos( );
} # end sub Photos

sub Album {
    my $Album = new openprint::Photo_Album( $_[0]{'album_id'} );
    if ( ! $Album->id() ) {
        $Album->name('Photos for product '.$_[0]{'name'});
    } # end if
    return $Album;
} # end sub Album

sub url_to {
	return '/product/category_view.html?category_id='.$_[0]{id};
}
sub link_to {
	return sprintf('<a href="/product/category_view.html?category_id=%d">%s</a>', $_[0]{id}, @_ > 1 ? $_[1] : $_[0]{name} );
}
sub Parent {
	return new openprint::Product_Category( $_[0]{parent_id} );
}

sub Categories {
	if ( ! $_[0]{Categories} ) {
		$_[0]{Categories} = [ openprint::Product_Category->find( parent_id=>$_[0]{id} ) ];
	}
	return @{$_[0]{Categories}};
} # end sub Categories

1;
__END__
