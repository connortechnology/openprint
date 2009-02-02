package openprint::Imposition;
use vars qw( $AUTOLOAD );

my @fields = (
	'imposition','rows','columns',
	'dutch_rows','dutch_columns', 'dutch_orientation',
	'image_width','image_height', # dimensions + bleed
	'object_width','object_height', # Flat dimensions
	'layout_width','layout_height',
	'runstyle',
	'spread_rows','spread_columns','spreads','spread_size',
	'gutters',
	'image_orientation',
	'paper',
	'Press',
	'grain_direction','rotate_sheet',
	'Total','Comparison',
	'overs',
	'colour_bar_size',
	'colour_bar_orientation',
	'cropmark_top','cropmark_bottom','cropmark_left','cropmark_right',
	'stock_width','stock_height',
	'quantity',
);

use strict;

sub new {
	my $parent = shift;

	my $self = {};
	bless $self, $parent;

	return $self;
} # end sub new

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self);
    my $name = $AUTOLOAD;
    $name =~ s/.*://;

    if ( @_ ) {
		$self->{$name} = shift;
		if ( sets::isin( $name, ['rows','columns','dutch_rows','dutch_columns','spread_rows','spread_columns','spreads','image_width','image_height'] ) ) {
			$$self{'imposition'} = $$self{'rows'} * $$self{'columns'} + $$self{'dutch_rows'} * $$self{'dutch_columns'};
			$$self{'spreads'} = $$self{'spread_rows'} * $$self{'spread_columns'};
			if ( $$self{'image_orientation'} eq 'Vertical' ) {
				$$self{'layout_width'} = $$self{'columns'} * $$self{'image_width'};
				$$self{'layout_height'} = $$self{'rows'} * $$self{'image_height'};
				if ( $$self{'dutch_orientation'} eq 'width' ) {
					$$self{'layout_width'} += $$self{'dutch_columns'} * $$self{'image_height'};
					my $dutch_height = $$self{'dutch_rows'} * $$self{'image_width'};
					$$self{'layout_height'} = $dutch_height if $dutch_height > $$self{'layout_height'};
				} else {
					$$self{'layout_height'} += $$self{'dutch_rows'} * $$self{'image_width'};
					my $dutch_width = $$self{'dutch_columns'} * $$self{'image_height'};
					$$self{'layout_width'} = $dutch_width if $dutch_width > $$self{'layout_width'};
				} # end if
			} elsif ( $$self{'image_orientation'} eq 'Horizontal' ) {
				$$self{'layout_width'} = $$self{'columns'} * $$self{'image_height'};
				$$self{'layout_height'} = $$self{'rows'} * $$self{'image_width'};

				if ( $$self{'dutch_orientation'} eq 'width' ) {
					$$self{'layout_width'} += $$self{'dutch_columns'} * $$self{'image_width'};
					my $dutch_height = $$self{'dutch_rows'} * $$self{'image_height'};
					$$self{'layout_height'} = $dutch_height if $dutch_height > $$self{'layout_height'};
				} else {
					$$self{'layout_height'} += $$self{'dutch_rows'} * $$self{'image_height'};
					my $dutch_width = $$self{'dutch_columns'} * $$self{'image_width'};
					$$self{'layout_width'} = $dutch_width if $dutch_width > $$self{'layout_width'};
				} # end if

			} # end if
			#if ( $$self{'spreads'} ) {
				#$$self{'layout_width'} = $$self{'spread_columns'} * $$self{'layout_width'};
				#$$self{'layout_height'} = $$self{'spread_rows'} * $$self{'layout_height'};
			#} # end if
		} # end if
	} # end if
	return $self->{$name};
} # end sub AUTOLOAD

sub display {
	my $self = shift;
	$openprint::log->debug("Imp: $$self{'columns'}x$$self{'rows'}+$$self{'dutch_columns'}x$$self{'dutch_rows'}:$$self{imposition}out spreads:$$self{'spread_columns'}x$$self{'spread_rows'}=$$self{'spreads'} $$self{runstyle} on: $self->{paper}->{start_width}x$self->{paper}->{start_height} -> $self->{paper}->{width}x$self->{paper}->{height} $$self{Press}->{strid} I: $$self{image_width}x$$self{image_height} L:$$self{layout_width}x$$self{layout_height} $$self{image_orientation} pages: " . $self->page_columns() . 'x' . $self->page_rows() );
} # end sub display

sub set {
	my $self = shift;
	my %hash = @_;
	foreach my $key ( keys %hash ) {
		$$self{$key} = $hash{$key} if ( sets::isin( $key, \@fields ) );
	} # end foreach
	$self->{'imposition'} = $$self{'rows'} * $$self{'columns'} + $$self{'dutch_rows'} * $$self{'dutch_columns'};
	if ( $$self{'image_orientation'} eq 'Vertical' ) {
		$$self{'layout_width'} = $$self{'columns'} * $$self{'image_width'};
		$$self{'layout_height'} = $$self{'rows'} * $$self{'image_height'};
		if ( $$self{'dutch_orientation'} eq 'width' ) {
			$$self{'layout_width'} += $$self{'dutch_columns'} * $$self{'image_height'};
			my $dutch_height = $$self{'dutch_rows'} * $$self{'image_width'};
			$$self{'layout_height'} = $dutch_height if $dutch_height > $$self{'layout_height'};
		} else {
			$$self{'layout_height'} += $$self{'dutch_rows'} * $$self{'image_width'};
			my $dutch_width = $$self{'dutch_columns'} * $$self{'image_height'};
			$$self{'layout_width'} = $dutch_width if $dutch_width > $$self{'layout_width'};
		} # end if

	} elsif ( $$self{'image_orientation'} eq 'Horizontal' ) {
		$$self{'layout_width'} = $$self{'columns'} * $$self{'image_height'};
		$$self{'layout_height'} = $$self{'rows'} * $$self{'image_width'};
		if ( $$self{'dutch_orientation'} eq 'width' ) {
			$$self{'layout_width'} += $$self{'dutch_columns'} * $$self{'image_width'};
			my $dutch_height = $$self{'dutch_rows'} * $$self{'image_height'};
			$$self{'layout_height'} = $dutch_height if $dutch_height > $$self{'layout_height'};
		} else {
			$$self{'layout_height'} += $$self{'dutch_rows'} * $$self{'image_height'};
			my $dutch_width = $$self{'dutch_columns'} * $$self{'image_width'};
			$$self{'layout_width'} = $dutch_width if $dutch_width > $$self{'layout_width'};
		} # end if

	} # end if

} # end sub set

sub get {
    my $self = shift;

    return map { $self->$_() } @_;
} # end sub get

sub copy {
	my $self = shift;
	my $copy = new openprint::Imposition();
	foreach my $field ( @fields ) {
		$$copy{$field} = $$self{$field};
	} # end foreach
	$$copy{paper} = $$copy{paper}->clone() if $$copy{paper};
	return $copy
} # end copy

sub Paper {
	my $self = shift;
	return $$self{'paper'};
} # end sub Paper

sub load {
	my ( $self, $specs, $qty_index ) = @_;

	$$self{'paper'} = openprint::Paper::load_from_signature( undef, $specs, $qty_index ) if ! $$self{'paper'};

	$$self{'object_width'} = $$specs{'txtWidth'};
	$$self{'object_height'} = $$specs{'txtHeight'};
	$$self{'image_width'} = $$specs{'txtImageWidth'.$qty_index};
	$$self{'image_width'} = $$self{'object_width'} if ! $$self{'image_width'};
	$$self{'image_height'} = $$specs{'txtImageHeight'.$qty_index};
	$$self{'image_height'} = $$self{'object_height'} if ! $$self{'image_height'};

	$$self{'imposition'} = $$specs{'txtImposition'.$qty_index};
	$$self{'rows'} = $$specs{'hdnImpositionRows'.$qty_index};
	$$self{'columns'} = $$specs{'hdnImpositionColumns'.$qty_index};
	$$self{'dutch_rows'} = $$specs{'hdnImpositionDutchRows'.$qty_index};
	$$self{'dutch_columns'} = $$specs{'hdnImpositionDutchColumns'.$qty_index};
	$$self{'dutch_orientation'} = $$specs{'hdnImageOrientation'.$qty_index} eq 'Vertical' ? 'Horizontal' : 'Vertical';

	#'layout_width','layout_height',
#,'rotate_sheet',
	$$self{'runstyle'} = $$specs{'ddmRunStyle'.$qty_index};
	$$self{'image_orientation'} = $$specs{'hdnImageOrientation'.$qty_index};
	$$self{'grain_direction'} = $$specs{'rdbGrainDirection'.$qty_index};

	if ( $$self{'image_orientation'} eq 'Vertical' ) {
		$$self{'layout_width'} = $$self{'columns'} * $$self{'image_width'};
		$$self{'layout_height'} = $$self{'rows'} * $$self{'image_height'};
		my $dutch_width = $$self{'dutch_columns'} * $$self{'image_height'};
		if ( $$self{'layout_width'} + $dutch_width > $self->paper()->width() ) {
			$$self{'dutch_orientation'} = 'height';
			$$self{'layout_height'} += $$self{'dutch_rows'} * $$self{'image_width'};
		} else {
			$$self{'dutch_orientation'} = 'width';
			$$self{'layout_width'} += $dutch_width;
		} # end if
	} elsif ( $$self{'image_orientation'} eq 'Horizontal' ) {
		$$self{'layout_width'} = $$self{'columns'} * $$self{'image_height'};
		$$self{'layout_height'} = $$self{'rows'} * $$self{'image_width'};
		my $dutch_width = $$self{'dutch_columns'} * $$self{'image_width'};
		if ( $$self{'layout_width'} + $dutch_width > $self->paper()->width() ) {
			$$self{'dutch_orientation'} = 'height';
			$$self{'layout_height'} += $$self{'dutch_rows'} * $$self{'image_height'};
		} else {
			$$self{'dutch_orientation'} = 'width';
			$$self{'layout_width'} += $dutch_width;
		} # end if
	} # end if
	if ( $$specs{'txtSignatureType'} ) {
		$$self{'spreads'} = $$specs{'txtSignatureSpreadQuantity'.$qty_index};
		$$self{'spread_rows'} = $$specs{'SpreadRows'.$qty_index};
		$$self{'spread_columns'} = $$specs{'SpreadCols'.$qty_index};
		$$self{'layout_width'} = $$self{'spread_columns'} * $$self{'layout_width'};
		$$self{'layout_height'} = $$self{'spread_rows'} * $$self{'layout_height'};
		$$self{'spread_size'} = $$specs{'txtSpreadSize'};
	} else {
		$$self{'spread_rows'} = int($$specs{'txtWidth'} / $$specs{'txtFinalWidth'}) if $$specs{'txtFinalWidth'};
		$$self{'spread_columns'} = int($$specs{'txtHeight'} / $$specs{'txtFinalHeight'}) if $$specs{'txtFinalHeight'};
		$$self{'spread_size'} = $$self{'spread_rows'} * $$self{'spread_columns'} * 2;
		$$self{'spread_rows'} = 1;
		$$self{'spread_columns'} = 1;
		$$self{'spreads'} = 1;
	} # end if

}

sub used_width {
	my $self = shift;
	my $width = $$self{'layout_width'} + $$self{'gutters'} + $$self{'cropmark_left'} + $$self{'cropmark_right'} + ( $$self{'colour_bar_orientation'} eq 'Length' ? $$self{'colour_bar_size'} : 0 );
	if ( ($$self{runstyle} eq 'Perfecting' ) and $$self{Press} and $$self{paper} ) {
		if ( $$self{paper}->perfecting() ne 'Y' ) {
			if ( $$self{columns} % 2 ) {
			$width += $$self{Press}->specification('Perfecting Double Gutter Size') - $$self{Press}->specification('Perfecting Single Gutter Size');
			} # end if
		} # end if
	} # end if
	return $width;
}
sub used_height {
    my $self = shift;
    return $$self{'layout_height'} + $$self{'grip'} + $$self{'cropmark_top'} + $$self{'cropmark_bottom'} + ( $$self{'colour_bar_orientation'} eq 'Width' ? $$self{'colour_bar_size'} : 0 );
}

sub object_area {
	my $self = shift;
	return $$self{'object_width'} * $$self{'object_height'} * $$self{'imposition'} * $$self{'spreads'};
}
sub layout_area {
	my $self = shift;
	return $$self{'layout_width'} * $$self{'layout_height'};
}
sub page_columns {
        my $self = shift;

        if ( $$self{'spread_size'} == 4 and $$self{'image_orientation'} eq 'Vertical' ) {
                return $$self{'spread_columns'} * 2;
        } else {
                return $$self{'spread_columns'};
        } # end if
} # end sub page_columns

sub page_rows {
        my $self = shift;

        if ( $$self{'spread_size'} == 4 and $$self{'image_orientation'} eq 'Horizontal' ) {
                return $$self{'spread_rows'} * 2;
        } else {
                return $$self{'spread_rows'};
        } # end if
} # end sub page_rows

sub sheet_width {
	my $self = shift;
	if ( $$self{'rotate_sheet'} ) {
		$$self{'paper'}->height( @_ ) if @_;
		return $self->Paper()->height();
	} else {
		$$self{'paper'}->width( @_ ) if @_;
		return $self->Paper()->width();
	} # end if
} # end sub sheet_width
sub sheet_height {
	my $self = shift;
	if ( $$self{'rotate_sheet'} ) {
		$$self{'paper'}->width( @_ ) if @_;
		return $self->Paper()->width();
	} else {
		$$self{'paper'}->height( @_ ) if @_;
		return $self->Paper()->height();
	} # end if
} # end sub sheet_height

sub pages {
	my $self = shift;
	return $$self{'spreads'} * $$self{'spread_size'};
}

sub grain_direction {
    my $self = shift;
    if ( $$self{'rotate_sheet'} ) {
        if ( $$self{'image_orientation'} eq 'Vertical' ) {
            return 'width';
        } else {
            return 'height';
        } # end if
    } else {
        if ( $$self{'image_orientation'} eq 'Vertical' ) {
            return 'height';
        } else {
            return 'width';
        } # end if
    } # end if
} # end sub grain_direction


1;

__END__
~       
