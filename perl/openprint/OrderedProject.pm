use strict;
package openprint::OrderedProject;
our @ISA=qw(openprint::Object);

require openprint::Project;

use vars qw( $debug $table @identified_by %fields %transforms %defaults );
$debug = 1;
$table = 'order_contents';
@identified_by = ( 'project_id', 'order_id' );

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
sub delete {
	my $self = shift;

	my $error;
	my $ac = sql::start_transaction( $openprint::dbh );
	my $Project = $self->Project();
	$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Removed from order $$self{order_id}" );
	$Project->docket( '' );
	$Project->order_id( '' );
	$error .= $Project->save();
	$Project->update_status();
	sql::execute( undef, undef, q{DELETE FROM Order_Contents WHERE OrderIndex=? AND lngProjectIndex=?}, @$self{'order_id','project_id'});
	$error .= $openprint::dbh->errstr();
	sql::end_transaction( $openprint::dbh, $ac );
	return $error;
} # end sub delete

1;
__END__
