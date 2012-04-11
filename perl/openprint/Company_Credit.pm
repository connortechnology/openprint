use strict;
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
	if ( ! exists $_[0]{'debt'} ) {
		$_ = q{SELECT SUM(curTotalSale) FROM Orders WHERE CompanyIndex=? AND strStatus IN ('Pending Deposit','In Production','Complete','Shipped','Waiting For Pickup', 'Picked Up' )};
		my ( $debt ) = sql::execute( undef, undef, $_, $_[0]{'company_id'} );
		$_ = q{SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL AND company_id=?};
		my ( $payments ) = sql::execute( undef, undef, $_, $_[0]{company_id} );
		$_[0]{'debt'} = $debt - $payments;
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

sub outstanding_orders {
    my $self = shift;
    $_ = q{SELECT Index FROM Orders WHERE CompanyIndex=?
    AND strStatus IN ('Pending Deposit','In Production','Complete','Shipped','Waiting For Pickup', 'Picked Up' )
    AND ( curTotalSale > (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL AND Payments.order_id=Orders.Index)
    OR (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL AND Payments.order_id=Orders.Index) IS NULL ) ORDER BY Index};
    return sql::execute( undef, undef, $_, $$self{company_id} );
} # end sub outstanding_orders

sub warn_orders {
    my $self = shift;
    $_ = q{SELECT Index FROM Orders WHERE CompanyIndex=?
    AND strStatus IN ('Pending Deposit','In Production','Complete','Shipped','Waiting For Pickup', 'Picked Up' )
    AND ( curTotalSale > (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL and Payments.order_id=Orders.Index)
    OR (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL and Payments.order_id=Orders.Index) IS NULL )
    AND dtmorderdate + '?  days' < NOW() ORDER BY Index};
    return sql::execute( undef, undef, $_, @$self{'company_id','warndays'} );
} # end sub warn_orders

sub denied_orders {
    my $self = shift;
    $_ = q{SELECT Index FROM Orders WHERE CompanyIndex=?
    AND strStatus IN ('Pending Deposit','In Production','Complete','Shipped','Waiting For Pickup', 'Picked Up' )
    AND ( curTotalSale > (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL and Payments.order_id=Orders.Index)
    OR (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL and Payments.order_id=Orders.Index) IS NULL )
    AND dtmorderdate + '? days' < NOW() ORDER BY Index};
    return sql::execute( undef, undef, $_, @$self{'company_id','denydays'} );
} # end sub denied_orders

sub supplier_id {
	if ( @_ > 1 ) {
		$_[0]{'supplier_id'} = $_[1];
	}
	if ( ! $_[0]{'supplier_id'} ) {
		$_[0]{'supplier_id'} = $openprint::config{'Owner'};
	} # end if
	return $_[0]{'supplier_id'};
} # end if supplier_id

1;
__END__
