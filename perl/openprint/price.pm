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
		'dblCost',				( $self->{Cost} eq '' ? undef : $self->{Cost} ),
		'dblMarkup',			( $self->{Markup} eq '' ? undef : $self->{Markup} ),
		'dblPrice',				( $self->{Price} eq '' ? undef : $self->{Price} )
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
	$self->{Discountable} = shift;
}
sub setEquipment {
	my $self = shift;
	$self->{equipment_index} = shift;
}

sub setMin {
	my $self = shift;
	$_ = shift;
	#$_ =~ s/[\D\-]//g;
	$self->{min} = $_;
}

sub setMax {
	my $self = shift;
	$_ = shift;
	#$_ =~ s/[\D\-]//g;
	$self->{max} = $_;
}

sub setUnits {
	my $self = shift;
	$self->{units} = shift;
}

sub setCost {
    my $self = shift;
    $_ = shift;
    $_ =~ s/([^\d\.])//g;
    $self->{Cost} = $_;
}

sub setMarkup {
    my $self = shift;
    $_ = shift;
    $_ =~ s/\%//g;
    $self->{Markup} = $_;
}

sub setPrice {
    my $self = shift;
    $_ = shift;
    $_ =~ s/([^\d\.])//g;
    $self->{Price} = $_;
}

sub copy {
	my $self = shift;
	my $src = shift;

	setEquipment( $self, $src->{equipment_index} );
	setMin( $self, $src->{min} );
	setMax( $self, $src->{max} );
	setUnits( $self, $src->{units} );
	setCost( $self, $src->{Cost} );
	setMarkup( $self, $src->{Markup} );
	setPrice( $self, $src->{Price} );
	setDiscountable( $self, $src->{Discountable} );
} # end sub copy

1;

__END__
~       
