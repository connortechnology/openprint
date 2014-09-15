package openprint::price;

use strict;

sub new {
	my ( $type, $log, $dbh, $group ) = @_;
	my $self = {};
	bless $self, $type;

	$self->{log} = $log;
	$self->{dbh} = $dbh;
	$self->{group} = $group;

	return $self;
}

sub save {
	my $self = shift;

	sql::insert( $self->{log}, $self->{dbh}, 'tbl_Prices',
		'lngListIndex',			$self->{group}->{list_id},
		'lngIndex',				$self->{group}->{product_index},
		'lngEquipmentIndex',	$self->{equipment_index},
		'lngMin',				( $self->{min} eq '' ? undef : $self->{min} ),
		'lngMax',				( $self->{max} eq '' ? undef : $self->{max} ),
		'strUnits',				( $self->{units} eq '' ? undef : $self->{units} ),
		'dblCost',				( $self->{cost} eq '' ? undef : $self->{cost} ),
		'dblMarkup',			( $self->{markup} eq '' ? undef : $self->{markup} ),
		'dblPrice',				( $self->{price} eq '' ? undef : $self->{price} )
	);
} # end sub save

sub set {
	my $self = shift;
	#$self->{log}->debug("In Set");
	setEquipment( $self, shift );
	setMin( $self, shift );
	setMax( $self, shift );
	setUnits( $self, shift );
	setCost( $self, shift );
	setMarkup( $self, shift );
	setPrice( $self, shift );
	setDiscountable( $self, shift );
} # end sub set

sub setDiscountable {
	my $self = shift;
	$self->{discountable} = shift;
}
sub setEquipment {
	my $self = shift;
	$self->{equipment_id} = shift;
}

sub setMin {
	$_[0]{min} = $_[1];
}

sub setMax {
	$_[0]{max} = $_[1];
}

sub setUnits {
	my $self = shift;
	$self->{units} = shift;
}

sub setCost {
    $_[1] =~ s/([^\d\.])//g;
    $_[0]{cost} = $_[1];
}

sub setMarkup {
    $_[1] =~ s/\%//g;
    $_[0]{markup} = $_[1];
}

sub setPrice {
    $_[1] =~ s/([^\d\.])//g;
    $_[0]->{price} = $_[1];
}

sub copy {
	my $self = shift;
	my $src = shift;

	setEquipment( $self, $src->{equipment_id} );
	setMin( $self, $src->{min} );
	setMax( $self, $src->{max} );
	setUnits( $self, $src->{units} );
	setCost( $self, $src->{cost} );
	setMarkup( $self, $src->{markup} );
	setPrice( $self, $src->{price} );
	setDiscountable( $self, $src->{discountable} );
} # end sub copy

1;

__END__
~       
