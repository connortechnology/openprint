package openprint::OrderedProject;
@ISA=qw(openprint::Object);

use strict;
require openprint::Project;

use vars qw( $debug $table $serial %fields %defaults %transforms );
$debug = 1;
$table = 'orer_contents';
$serial = 'ordered_project_id_seq';

%fields = (
	'id'			=>	'id',
	'order_id'		=>	'orderindex',
	'project_id'	=>	'projectindex',
	'quantity'		=>	'quantity',
	'price'			=>	'price',
	'shipping_type'	=>	'shipping_type',
	'requested_for'	=>	'requested_for',
	'gst'			=>	'gst',
	'hst'			=>	'hst',
	'pst'			=>	'pst',
);

sub Project {
	my $self = shift;
	return new openprint::Project( $$self{'project_id'} );
} # end sub Project

sub price {
	my $self = shift;

	if ( ! $$self{price} ) {
		my %Price = $self->Project()->get_price( $$self{quantity} );
		$$self{price} = $Price{Price};
	} # end if
	return $$self{price};
} # end sub price

1;
__END__
