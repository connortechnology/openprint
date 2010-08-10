package openprint::OrderedProject;
@ISA=qw(openprint::Object);

use strict;
require openprint::Project;

use vars qw( $debug $table $serial %fields %defaults %transforms );
$debug = 1;
$table = 'order_contents';
$serial = 'ordered_project_id_seq';

%fields = (
	'id'			=>	'id',
	'order_id'		=>	'orderindex',
	'project_id'	=>	'lngprojectindex',
	'quantity'		=>	'intquantity',
	'qty_index'		=>	'intquantityindex',
	'price'			=>	'cursalesprice',
	'shipping_type'	=>	'shipping_type',
	'requested_for'	=>	'requested_for',
);

sub Project {
	my $self = shift;
	return new openprint::Project( $$self{'project_id'} );
} # end sub Project

sub price {
	my $self = $_[0];

	if ( @_ > 1 ) {
		$$self{'price'} = $_[1];
	} # end if

	if ( ! $$self{price} ) {
		$$self{price} = $self->Project()->price( $self->qty_index() );
	} # end if
	return $$self{price};
} # end sub price

sub quantity {
	if ( @_ > 1 ) {
		$_[0]{'quantity'} = $_[1];
	} # end if
	if ( ! $_[0]{'quantity'} ) {
		$_[0]{'quantity'} = $_[0]->Project()->quantity( $_[0]->qty_index() );
	} # end if
	return $_[0]{'quantity'};
} # end sub quantity

1;
__END__
