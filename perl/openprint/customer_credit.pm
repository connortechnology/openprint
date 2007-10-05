package openprint::customer_credit;

use strict;

my %fields = (
		'Limit'			=>	'dblLimit',
		'Hold'			=>	'Hold',
		'DenyDays'		=>	'DenyDays',
		'WarnDays'		=>	'WarnDays',
		'Downpayment'	=>	'Downpayment',
		);	

my %transforms = (
		'Hold'      =>  's/[^YN]//g',
		'Limit'			=>	's/[^\d\.]//g',
		'DenyDays'		=>	's/\D//g',
		'WarnDays'		=>	's/\D//g',
		'Downpayment'	=>	's/[^\d\.]//g',
		);

sub new {
	my ( $parent, $customer_index, $supplier_index ) = @_;
	my $self = {};
	bless $self;

	$self->{customer_index} = $customer_index;
	$self->{supplier_index} = $supplier_index;

	return $self;
} # end sub new

sub get {
	my $self = shift;
	my @requested_fields = @_;

	my @get_fields = ();

	foreach my $field ( @requested_fields ) {
		if ( defined $fields{$field} ) {
			if ( defined $self->{values}->{$field} ) {
				# means we have already loaded the value for this one
			} else {
				# need to load it	
				push @get_fields, $field;
			} # end if	
		} else {
			$openprint::log->warn("Customer_Credit::Get::Invalid field requested: ($field)." );
		} # end if
	} # end foreach 

	if ( $$self{'customer_index'} ) {
		# Load in the needed fields
		$self->load_values( @get_fields );
	} # end if
	my $values = $self->{values};
	return @$values{@requested_fields};
} # end sub get

sub load_values {
	my ( $self, @get_fields ) = @_;
	my $values = $self->{values};

	if ( @get_fields ) {
		$_ = "SELECT " . join( ',',@fields{@get_fields}) . ' FROM Company_Credit WHERE company_id = ' . $self->{customer_index};
			#"AND lngSupplierIndex = '" . $self->{supplier_index} . "'\n";
		@$values{@get_fields} = sql::execute( undef, undef, $_ );
	} # end if

} # end sub load_values

sub set {
	my ( $self, $params ) = @_;
	my @set_fields = ();
	my $values = $self->{values};

	foreach my $field ( keys %{$params} ) {
		if ( defined $fields{$field} ) {
			if ( $transforms{$field} ) {
				eval '$params->{$field} =~ ' . $transforms{$field};
			} # end if
			# if valid db field
			if ( $values->{$field} ne $params->{$field} ) {
				# Only make changes to fields that have changed
				$values->{$field} = $params->{$field};	# update cache
				push @set_fields, $fields{$field}, $params->{$field};	#mark for sql updating
			} # end if
		} else {
			$openprint::log->warn("Customer_Credit::Set::Invalid field requested: ($field)." );
		} # end if
	} # end foreach

	if ( @set_fields ) {
		sql::execute( undef, undef, 'DELETE FROM Company_Credit WHERE company_id=?', $self->{customer_index} );
		sql::insert( undef, undef, 'Company_Credit', [ 'company_id', $self->{customer_index}, @set_fields ] );
	} # end if

} # end sub get

sub debt {
    my $self = shift;
    $_ = q{SELECT SUM(curTotalSale) FROM Orders WHERE CompanyIndex=? AND strStatus IN ('Pending Deposit','In Production','Complete','Shipped','Waiting For Pickup', 'Picked Up' )};
    my ( $debt ) = sql::execute( undef, undef, $_, $$self{'customer_index'} );
    $_ = q{SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL AND company_id=?};
    my ( $payments ) = sql::execute( undef, undef, $_, $self->{customer_index} );

    return $debt - $payments;
} # end sub get_debt
sub remaining {
	my $self = shift;

	my $debt = $self->debt();
	my $limit = $self->value('Limit');

	if ( $limit < $debt ) {
		return '$0.00';
	} # end if
	return sprintf( '$%.2f', $limit - $debt );
} # end sub remaining

sub value {
    my $self = shift;
    my $name = shift;
    return $self->{values}->{$name};
}

sub outstanding_orders {
    my $self = shift;
    $_ = q{SELECT Index FROM Orders WHERE CompanyIndex=?
    AND strStatus IN ('Pending Deposit','In Production','Complete','Shipped','Waiting For Pickup', 'Picked Up' )
    AND ( curTotalSale > (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL AND Payments.order_id=Orders.Index)
    OR (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL AND Payments.order_id=Orders.Index) IS NULL ) ORDER BY Index};
    return sql::execute( undef, undef, $_, $$self{customer_index} );
} # end sub outstanding_orders

sub warn_orders {
    my $self = shift;
    $_ = q{SELECT Index FROM Orders WHERE CompanyIndex=?
    AND strStatus IN ('Pending Deposit','In Production','Complete','Shipped','Waiting For Pickup', 'Picked Up' )
    AND ( curTotalSale > (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL and Payments.order_id=Orders.Index)
    OR (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL and Payments.order_id=Orders.Index) IS NULL )
    AND dtmorderdate + '?  days' < NOW() ORDER BY Index};
    return sql::execute( undef, undef, $_, $self->{customer_index}, $self->{values}{'WarnDays'} );
} # end sub warn_orders

sub denied_orders {
    my $self = shift;
    $_ = q{SELECT Index FROM Orders WHERE CompanyIndex=?
    AND strStatus IN ('Pending Deposit','In Production','Complete','Shipped','Waiting For Pickup', 'Picked Up' )
    AND ( curTotalSale > (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL and Payments.order_id=Orders.Index)
    OR (SELECT SUM(curAmount) FROM Payments WHERE strSessionID IS NULL and Payments.order_id=Orders.Index) IS NULL )
    AND dtmorderdate + '? days' < NOW() ORDER BY Index};
    return sql::execute( undef, undef, $_, $self->{customer_index}, $self->{values}{'DenyDays'} );
} # end sub denied_orders

sub fields {
    return keys %fields;
}

1;

__END__

