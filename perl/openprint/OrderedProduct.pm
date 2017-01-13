package openprint::OrderedProduct;
@ISA=qw(openprint::Object);

use strict;
require openprint::Product;
require openprint::Project;
require openprint::Order;

use vars qw( $debug $serial $table $log $dbh %fields %transforms %defaults );

$debug = 0;
$serial = 'ordered_products_id_seq';
$table = 'ordered_products';

%fields = (
	id => 'id',
	order_id => 'order_id',
	product_id => 'product_id',
	project_id	=> 'project_id',
	quantity		=> 'quantity',
	price			=> 'price',
	shipping_type	=> 'shipping_type',
	requested_for	=> 'requested_for',
	comments		=>	'comments',
);

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( undef, undef, 'DELETE FROM ORdered_products WHERE id=?', $$self{id} );
	$self->Project()->delete() if $$self{project_id};
	sql::end_transaction( $openprint::dbh, $ac );
	return;
} # end sub delete

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Ordered_Products WHERE order_id=? AND product_id=?', {}, @$self{'order_id','product_id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub copy {
	my ( $self ) = @_;
	my $New = new openprint::OrderedProduct();
	@$New{ keys %fields} = @$self{keys %fields};
	delete $$New{id};
	delete $$New{project_id};
	return $New;
} # end sub copy

sub Project {
	my ( $self ) = @_;
	if ( $$self{project_id} ) {
		return new openprint::Project( $$self{project_id} );
	} # end if
	if ( $self->Product()->project_id() ) {
		$openprint::log->debug("Creating proejct from template: " . $self->Product()->project_id() );
		my $Project = new openprint::Project( $self->Product()->project_id() )->copy();
		$Project->predefined(0);
		$Project->reference( $self->Product()->name() );
		$Project->user_id( $openprint::session{user_id} );
		$Project->company_id( $openprint::session{company_id} );
		$Project->currency_id( $self->Order()->currency_id() );
		$Project->status('Unordered'); # To prevent deleted status
			$Project->save();
		$$self{project_id} = $Project->id();
		my $e = $self->save();
		$openprint::log->error( $e ) if $e;
		return $Project;
	} # end if
} # end sub Project

sub Order {
	return new openprint::Order( $_[0]{order_id} );
} # end sub Order

sub Product {
	return new openprint::Product( $_[0]{product_id} );
} # end sub Product

sub price {
	my ( $self, $new_price ) = @_;
	
	if ( defined $new_price ) {
		$$self{price} = $new_price;
	} elsif ( ! $$self{price} ) {
		my %Price = $self->Product()->get_price( $$self{quantity} );
		$$self{price} = $Price{Price};
	} # end if
	return $$self{price};
} # end sub price

sub total {
	return $_[0]->price() * $_[0]->quantity();
}

sub Currency {
	if ( $_[0]{project_id} ) {
		return $_[0]->Project()->Currency();
	} elsif ( $_[0]{order_id} ) {
		return $_[0]->Order()->Currency();
	}
}
sub currency_id {
	if ( $_[0]{project_id} ) {
		return $_[0]->Project()->currency_id();
	} elsif ( $_[0]{order_id} ) {
		return $_[0]->Order()->currency_id();
	}
	return;
}

sub shippingtype {
    my ( $self, $new ) = @_;
    if ( $new ) {
        $$self{shippingtype} = $new;
    } # end if
    if ( ! $$self{shippingtype} ) {
		if ( $$self{project_id} ) {
			my $services = $self->Project()->services();
			$$self{shippingtype} = join(',', map { $_->ServiceType()->name() } openprint::Project_Service->find('project_id'=>$$self{project_id},'category'=>'Shipping') );
		} # end if
    } # end if
    return $$self{shippingtype};
} # end sub shippingtype

sub requested_for {
	if ( @_ > 1 ) {
		$_[0]{requested_for} = $_[1];
	} # end if
	if ( ! $_[0]{requested_for} ) {
#$openprint::log->debug("Calcing requested_fro");
		my $days = 7; # Default to 7, I don't know why, just chose it.
		if ( $_[0]{project_id} ) {
			my $Project = $_[0]->Project();
			my $services = $Project->services('Turnaround');
			if ( $$services{Turnaround} ) {
	#$openprint::log->debug("Have turnaround_id ");
				my $Turnaround = $Project->Service( @{$$services{Turnaround}} );
	#$openprint::log->debug("Turnaround: " . $Turnaround);
				if ( $Turnaround ) {
					my $specs = $Turnaround->specs();
					$openprint::log->debug("Turnaround specs; $specs $$specs{TurnaroundDays}days");
					$days = $$specs{TurnaroundDays} if $$specs{TurnaroundDays};
				} else {
					$openprint::log->debug("No Turnaround");
				} # end if
			} # end if
		} # end if
		$_[0]{requested_for} = sprintf('%.4d-%.2d-%.2d', misc::add_delta_business_days( Date::Calc::Today(), $days ) );
	} # end if
	return $_[0]{requested_for};
} # end sub erquested_for

sub quantity_index {
return 1;
}

1;
__END__
