use strict;
package openprint::OrderedProject;
our @ISA=qw(openprint::Object);

require openprint::Project;

use vars qw( $debug $table @identified_by %fields %transforms %defaults );

$debug = 1;
$table = 'order_contents';
@identified_by = ( 'project_id', 'order_id' );
%fields = (
	'order_id' => 'orderindex',
	'project_id' => 'lngprojectindex',
	'quantity' =>	'intquantity',
	'quantity_index' =>	'intquantityindex',
	'price'			=>	'cursalesprice',
	'shipping_type'	=>	'shippingtype',
	'requested_for'	=>	'daterequired',
	'duedate'	=>	'duedate',
	'gst'		=>	'dbltax1',
	'hst'		=>	'dbltax2',
	'pst'		=>	'dbltax3',
	'description'	=>	'strdescription',
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

sub shippingtype {
    my ( $self, $new ) = @_;
    if ( $new ) {
        $$self{'shippingtype'} = $new;
    } # end if
    if ( ! $$self{'shippingtype'} ) {
        my $services = $self->Project()->services();
        $$self{'shippingtype'} = join(',', map { $_->ServiceType()->name() } openprint::Project_Service->find('project_id'=>$$self{'project_id'},'category'=>'Shipping') );
    } # end if
    return $$self{'shippingtype'};
} # end sub shippingtype

sub description { 
	if ( @_ > 1 ) {
		$_[0]{'description'} = $_[1];
	} # end if
	if ( ! $_[0]{'description'} ) {
		$_[0]{'description'} = $_[0]->Project()->reference();
	} # end if
	return $_[0]{'description'};
} # end sub description

1;
__END__
