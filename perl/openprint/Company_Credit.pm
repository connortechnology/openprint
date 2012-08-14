use strict;
require openprint::Currency;
require openprint::Order;
require openprint::Company;
require openprint::User;
require misc;
package openprint::Company_Credit;
our @ISA = qw( openprint::Object );

use vars qw( $debug $table %fields %transforms %defaults @identified_by );

$debug = 1;
$table = 'company_credit';
@identified_by = ( 'company_id','supplier_id' );

# COD and #DOWNpayment are percentages.  
%fields = (
		'limit'			=>	'dbllimit',
		'hold'			=>	'hold',
		'denydays'		=>	'denydays',
		'warndays'		=>	'warndays',
		'downpayment'	=>	'downpayment',
		'cod'			=>	'cod',
		'company_id'	=>	'company_id',
		'supplier_id'	=>	'supplier_id',
		);	

%transforms = (
		'hold'      	=>  [ 's/[^YN]//g' ],
		'limit'			=>	[ 's/[^\d\.]//g' ],
		'denydays'		=>	[ 's/\D//g' ],
		'warndays'		=>	[ 's/\D//g' ],
		'downpayment'	=>	[ 's/[^\d\.]//g' ],
		'cod'			=>	[ 's/[^\d\.]//g' ],
		);
%defaults = (
	'supplier_id'		=>	undef,
	'limit'				=>	undef,
	'denydays'			=>	undef,
	'warndays'			=>	undef,
	'downpayment'		=>	undef,
	'cod'				=>	undef,
);

sub debt {
	if ( ! exists $_[0]{debt} ) {
		$_[0]{debt} = misc::sum( map { $_->total() - $_->paid() } openprint::Order->find(
					company_id		=>	$_[0]{company_id},
					supplier_id		=>	$_[0]{supplier_id},
					'status not in'	=>	['Cancelled','Incomplete','Deleted']
					) );
	} # end if
	return $_[0]{'debt'};
} # end sub debt

sub remaining {
	my $self = shift;

	my $debt = $self->debt();
	my $limit = $$self{'limit'};

	if ( $limit < $debt ) {
		return openprint::Currency::format(0);
	} # end if
	return openprint::Currency::format( $limit - $debt );
} # end sub remaining

sub outstanding_Orders {
	if ( ! $_[0]{'outstanding_Orders'} ) {
   $_[0]{'outstanding_Orders'} = [ openprint::Order->find(
	
        'company_id'    =>	$_[0]{company_id},
		'supplier_id'	=>	$_[0]{supplier_id},
        'status not in' =>  [ 'Cancelled','Deleted','Incomplete' ],
        'owing_>'   =>  0,
        'order'     => 'created_on',
        ) ];
	} # end if
	return @{$_[0]{'outstanding_Orders'}};
} # end sub outstanding_Orders

sub outstanding_orders {
	return map { $_->id() } $_[0]->outstanding_Orders();
} # end sub outstanding_orders

sub warn_orders {
    my $self = shift;
    $_ = q{SELECT Index FROM Orders WHERE CompanyIndex=?
    AND strStatus IN ('Pending Deposit','In Production','Complete','Shipped','Waiting For Pickup', 'Picked Up' )
    AND ( curTotalSale > (SELECT SUM(amount) FROM Payments WHERE deleted=false AND completed=true and Payments.order_id=Orders.Index)
    OR (SELECT SUM(amount) FROM Payments WHERE deleted=false AND completed=true and Payments.order_id=Orders.Index) IS NULL )
    AND dtmorderdate + '?  days' < NOW() ORDER BY Index};
    return sql::execute( undef, undef, $_, @$self{'company_id','warndays'} );
} # end sub warn_orders

sub denied_orders {
    my $self = shift;
    $_ = q{SELECT Index FROM Orders WHERE CompanyIndex=?
    AND strStatus IN ('Pending Deposit','In Production','Complete','Shipped','Waiting For Pickup', 'Picked Up' )
    AND ( curTotalSale > (SELECT SUM(amount) FROM Payments WHERE deleted=false AND completed=true and Payments.order_id=Orders.Index)
    OR (SELECT SUM(amount) FROM Payments WHERE deleted=false AND completed=true and Payments.order_id=Orders.Index) IS NULL )
    AND dtmorderdate + '? days' < NOW() ORDER BY Index};
    return sql::execute( undef, undef, $_, @$self{'company_id','denydays'} );
} # end sub denied_orders

sub Supplier {
	return new openprint::Company( $_[0]->supplier_id() );
} # end sub Supplier

sub Company {
	return new openprint::Company( $_[0]{'company_id'} );
} # end sub Company

sub to_string {
	return sprintf('for %s: hold %s, warn after %d, deny after %d, limit %s, downpayment %d%, cod %d%', $_[0]->Supplier()->name(), 
		$_[0]{hold}, $_[0]{warndays},$_[0]{denydays},openprint::Currency::format($_[0]{limit}),$_[0]{downpayment},$_[0]{cod} );
} # end sub to_string

1;
__END__
