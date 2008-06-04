package openprint::Imposition;
use vars qw( $AUTOLOAD );


my @fields = (
	'start_imposition',
	'imposition','rows','columns',
	'dutch_rows','dutch_columns', 'dutch_orientation',
	'image_width','image_height', # dimensions + bleed
	'object_width','object_height', # Flat dimensions
	'layout_width','layout_height',
	'runstyle',
	'spread_rows','spread_columns','spreads','spread_size',
	'grip','gutters',
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
	$openprint::log->debug(sprintf('Imp: %dout %dx%d+%dx%d:%dout spreads:%dx%d=%d pages:%dx%d=%d %s on: %sx%s %.3fx%.3f %s I: %.3fx%.3f L:%.3fx%.3f %s',
	@$self{'start_imposition','columns','rows','dutch_columns','dutch_rows','imposition','spread_columns','spread_rows','spreads'},$self->page_columns(), $self->page_rows(), $self->pages(), $$self{'runstyle'}, $$self{paper}->{start_width},$$self{paper}->{start_height},$self->{paper}->{width},$self->{paper}->{height},$$self{Press}->{strid}, @$self{'image_width','image_height','layout_width','layout_height','image_orientation'}) );
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
		$$self{'pages'} = $$specs{'PageQuantity'.$qty_index};
		$$self{'spreads'} = $$specs{'PageQuantity'.$qty_index} / $$specs{'txtSpreadSize'};
		$$self{'spread_rows'} = $$specs{'SpreadRows'.$qty_index};
		$$self{'spread_columns'} = $$specs{'SpreadCols'.$qty_index};
		$$self{'layout_width'} = $$self{'spread_columns'} * $$self{'layout_width'};
		$$self{'layout_height'} = $$self{'spread_rows'} * $$self{'layout_height'};
		$$self{'spread_size'} = $$specs{'txtSpreadSize'};
		#$$self{'image_width'} = $$self{'spread_columns'} * $$self{'image_width'};
		#$$self{'image_height'} = $$self{'spread_rows'} * $$self{'image_height'};

	} else {
		$$self{'spread_rows'} = sprintf('%.0f', $$specs{'txtWidth'} / $$specs{'txtFinalWidth'}) if $$specs{'txtFinalWidth'};
		$$self{'spread_columns'} = sprintf('%.0f',$$specs{'txtHeight'} / $$specs{'txtFinalHeight'}) if $$specs{'txtFinalHeight'};
		$$self{'spread_size'} = $$self{'spread_rows'} * $$self{'spread_columns'} * 2;
		$$self{'spread_rows'} = 1;
		$$self{'spread_columns'} = 1;
		$$self{'spreads'} = 1;
	} # end if

} # end sub load

sub save {
	my ( $self, $specs, $qty_index ) = @_;
	$$specs{'txtImposition'.$qty_index} = $self->imposition();
	$$specs{'hdnImpositionRows'.$qty_index} = $self->rows();
	$$specs{'hdnImpositionColumns'.$qty_index} = $self->columns();
	$$specs{'hdnImpositionDutchRows'.$qty_index} = $self->dutch_rows();
	$$specs{'hdnImpositionDutchColumns'.$qty_index} = $self->dutch_columns();
	$$specs{'hdnImageOrientation'.$qty_index} = $self->image_orientation();
	$$specs{'page_columns'.$qty_index} = $self->page_columns();
	$$specs{'page_rows'.$qty_index} = $self->page_rows();
	$$specs{'SpreadRows'.$qty_index} = $self->spread_rows();
	$$specs{'SpreadCols'.$qty_index} = $self->spread_columns();
	$$specs{'ddmRunStyle'.$qty_index} = $self->runstyle();
	$$specs{'txtImageWidth'.$qty_index} = $self->image_width();
	$$specs{'txtImageHeight'.$qty_index} = $self->image_height();
	$$specs{'txtLayoutWidth'.$qty_index} = $self->layout_width();
	$$specs{'txtLayoutHeight'.$qty_index} = $self->layout_height();
	$$specs{'rdbGrainDirection'.$qty_index} = $self->grain_direction();
} # end sub Save

sub used_width {
	my $self = shift;
	return $$self{'layout_width'} + $$self{'gutters'} + $$self{'cropmark_left'} + $$self{'cropmark_right'} + ( $$self{'colour_bar_orientation'} eq 'Length' ? $$self{'colour_bar_size'} : 0 );
}
sub used_height {
    my $self = shift;
	my $height = $$self{'layout_height'} + $$self{'grip'} + $$self{'cropmark_top'} + $$self{'cropmark_bottom'} + ( $$self{'colour_bar_orientation'} eq 'Width' ? $$self{'colour_bar_size'} : 0 );
$openprint::log->warn("Height: $height");
    return $height;
} # end sub used_height

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

sub page_width {
	return $_[0]{spread_size} == 4 ? $_[0]{object_width}/2 : $_[0]{object_width};
}
sub page_height {
	return $_[0]{object_height};
}
sub sheet_width {
	my $self = shift;
	if ( $$self{'rotate_sheet'} ) {
		return $self->paper()->height();
	} else {
		return $self->paper()->width();
	} # end if
} # end sub sheet_width
sub sheet_height {
	my $self = shift;
	if ( $$self{'rotate_sheet'} ) {
		return $self->paper()->width();
	} else {
		return $self->paper()->height();
	} # end if
} # end sub sheet_height

sub pages {
	my $self = shift;
	return $$self{'spreads'} * $$self{'spread_size'};
}

sub equals {
	my ( $i1, $i2 ) = @_;
	return 0 if $i1->Press()->id() != $i2->Press()->id();
	return 0 if $$i1{'runstyle'} ne $$i2{'runstyle'};
	return 0 if $$i1{'imposition'} != $$i2{'imposition'};
	return 0 if $$i1{'columns'} != $$i2{'columns'};
	return 0 if $$i1{'spreads'} != $$i2{'spreads'};
	return 0 if $$i1{'paper'}->width() != $$i2{'paper'}->width();
	return 0 if $$i1{'paper'}->height() != $$i2{'paper'}->height();
	return 1;
}

1;

__END__
~       
