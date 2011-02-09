package openprint::Imposition;
use vars qw( $AUTOLOAD );


my @fields = (
	'start_imposition','start_columns','start_rows',
	'imposition','rows','columns',
	'dutch_rows','dutch_columns', 'dutch_orientation',
	'image_width','image_height', # dimensions + bleed
	'object_width','object_height', # Flat dimensions
	'layout_width','layout_height',
	'cut_off',
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
	'quantity',
	'bleed_size',
	'specs',
	'pages',
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
		if ( sets::isin( $name, ['rows','columns','dutch_rows','dutch_columns','spread_rows','spread_columns','spreads','image_width','image_height','spread_size'] ) ) {
			$$self{'imposition'} = $$self{'rows'} * $$self{'columns'} + $$self{'dutch_rows'} * $$self{'dutch_columns'};
			$$self{'spreads'} = $$self{'spread_rows'} * $$self{'spread_columns'};
			$$self{'pages'} = $$self{'spreads'} * $$self{'spread_size'};
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
	my ( $self, $prefix ) = @_;
	#$openprint::log->debug(sprintf('Imp %s: %dx%dout %dx%d+%dx%d:%dout spreads:%dx%d=%d pages:%dx%d=%d %s on: %sx%s %.3fx%.3f %s I: %.3fx%.3f L:%.3fx%.3f %s %s minimum: %s', $prefix,
	#@$self{'quantity','start_imposition','columns','rows','dutch_columns','dutch_rows','imposition','spread_columns','spread_rows','spreads'},$self->page_columns(), $self->page_rows(), $self->pages(), $$self{'runstyle'}, $$self{paper}->{start_width},$$self{paper}->{start_height},$self->{paper}->{width},$self->{paper}->{height},$$self{Press}->{strid}, @$self{'image_width','image_height','layout_width','layout_height','image_orientation'},$self->grain_direction(), $$self{paper}->minimum_order() ) );
	$openprint::log->debug(sprintf('Imp %s: %dx%d+%dx%d:%dout pages:%dx%d=%d %s on: %sx%s %s %s', $prefix,
	@$self{'columns','rows','dutch_columns','dutch_rows','imposition'},$self->page_columns(), $self->page_rows(), $self->pages(), $$self{'runstyle'}, $self->{paper}->{width},$self->{paper}->{height},$$self{Press}->{strid}, $$self{'Price'} ? $$self{'Price'} : '' ) );
} # end sub display

sub get {
	my ( $self, @fields ) = @_;
	return map { $self->$_ } @fields;
} # end sub get

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
	my $copy = new openprint::Imposition();
	@$copy{@fields} = @{$_[0]}{@fields};
	$$copy{paper} = $$copy{paper}->clone() if $$copy{paper};
	return $copy
} # end copy

sub Paper {
	return $_[0]{'paper'};
} # end sub Paper

sub load_used {
	my ( $self, $specs, $qty_index ) = @_;

	$$self{'runstyle'} = $$specs{'ddmRunStyleUsed'} ? $$specs{'ddmRunStyleUsed'} : $$specs{'ddmRunStyle'.$qty_index};
	$$self{'image_orientation'} = $$specs{'hdnImageOrientationUsed'} ? $$specs{'hdnImageOrientationUsed'} : $$specs{'hdnImageOrientation'.$qty_index};
	$$self{'imposition'} = $$specs{'txtImpositionUsed'} ? $$specs{'txtImpositionUsed'} : $$specs{'txtImposition'.$qty_index};
	$$self{'rows'} = $$specs{'hdnImpositionRowsUsed'} ? $$specs{'hdnImpositionRowsUsed'} : $$specs{'hdnImpositionRows'.$qty_index};
	$$self{'columns'} = $$specs{'hdnImpositionColumnsUsed'} ? $$specs{'hdnImpositionColumnsUsed'} : $$specs{'hdnImpositionColumns'.$qty_index};
	$$self{'dutch_rows'} = $$specs{'hdnImpositionDutchRowsUsed'} ? $$specs{'hdnImpositionDutchRowsUsed'} : $$specs{'hdnImpositionDutchRows'.$qty_index};
	$$self{'dutch_columns'} = $$specs{'hdnImpositionDutchColumnsUsed'} ? $$specs{'hdnImpositionDutchColumnsUsed'} : $$specs{'hdnImpositionDutchColumns'.$qty_index};
	$$self{'dutch_orientation'} = $$self{'image_orientation'} eq 'Vertical' ? 'Horizontal' : 'Vertical';
	$$self{'bleed_size'} = $$specs{'ddmBleedSize'.$qty_index};

} # edn sub load_used

sub load {
	my ( $self, $specs, $qty_index ) = @_;

	$$self{'specs'} = $specs;
	$$self{'paper'} = openprint::Paper::load_from_signature( undef, $specs, $qty_index ) if ! $$self{'paper'};
	if ( ! $$self{'Press'} ) {
		my @Presses = openprint::Equipment->find('strid'=>$$specs{'ddmPress'.$qty_index});
		$$self{'Press'} =  $Presses[0];
	} # end if

	$$self{'object_width'} = $$specs{'txtWidth'};
	$$self{'object_height'} = $$specs{'txtHeight'};
	$$self{'image_width'} = $$specs{'txtImageWidth'.$qty_index};
	$$self{'image_width'} = $$self{'object_width'} if ! $$self{'image_width'};
	$$self{'image_height'} = $$specs{'txtImageHeight'.$qty_index};
	$$self{'image_height'} = $$self{'object_height'} if ! $$self{'image_height'};

	$$self{'imposition'} = $$specs{'txtImposition'.$qty_index};
	$$self{'start_columns'} = $$self{'columns'} = $$specs{'hdnImpositionColumns'.$qty_index};
	$$self{'start_rows'} = $$self{'rows'} = $$specs{'hdnImpositionRows'.$qty_index};
	#$$self{'columns'} = $$self{'imposition'} / $$self{'rows'} if $$self{'rows'} and ! $$self{'columns'};
	#$$self{'rows'} = $$self{'imposition'} / $$self{'columns'} if $$self{'columns'} and ! $$self{'rows'};
	$$self{'dutch_rows'} = $$specs{'hdnImpositionDutchRows'.$qty_index};
	$$self{'dutch_columns'} = $$specs{'hdnImpositionDutchColumns'.$qty_index};
	$$self{'dutch_orientation'} = $$specs{'hdnImageOrientation'.$qty_index} eq 'Vertical' ? 'Horizontal' : 'Vertical';
	$$self{'cut_off'} = $$specs{'CutOff'.$qty_index};

	#'layout_width','layout_height',
#,'rotate_sheet',
	$$self{'runstyle'} = $$specs{'ddmRunStyle'.$qty_index};
	$$self{'runstyle'} = 'Sheet Work' if ! $$self{'runstyle'};
	$$self{'image_orientation'} = $$specs{'hdnImageOrientation'.$qty_index};
	$$self{'grain_direction'} = $$specs{'rdbGrainDirection'.$qty_index};
	$$self{'bleed_size'} = $$specs{'ddmBleedSize'.$qty_index};

	if ( ! $$self{'image_orientation'} ) {
		# Guess the image orientation
		if ( 
				( $$self{'image_width'} * $$self{'columns'} < $self->Paper()->width() )
				and 
				( $$self{'image_height'} * $$self{'rows'} < $self->Paper()->height() )
		   ) {
			$$self{'image_orientation'} = 'Vertical';
		} else {
			$$self{'image_orientation'} = 'Horizontal';
		} # end if
	} # end if

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
		#$$self{'layout_width'} = $$self{'spread_columns'} * $$self{'layout_width'};
		#$$self{'layout_height'} = $$self{'spread_rows'} * $$self{'layout_height'};
		$$self{'spread_size'} = $$specs{'txtSpreadSize'};
		#$$self{'image_width'} = $$self{'spread_columns'} * $$self{'image_width'};
		#$$self{'image_height'} = $$self{'spread_rows'} * $$self{'image_height'};

	} else {
		$$self{'spread_rows'} = sprintf('%.0f', $$specs{'txtWidth'} / $$specs{'txtFinalWidth'}) if $$specs{'txtFinalWidth'};
		$$self{'spread_columns'} = sprintf('%.0f',$$specs{'txtHeight'} / $$specs{'txtFinalHeight'}) if $$specs{'txtFinalHeight'};

		if ( 0 ) {
			$$self{'spreads'} = $$self{'spread_rows'} * $$self{'spread_columns'};
			$$self{'spread_size'} = 2;
		} else {
			# This is the alternate way of doing it, this makes more sense, but it screws something up.  I can never remember what.
			$$self{'spread_size'} = $$self{'spread_rows'} * $$self{'spread_columns'} * 2;
			$$self{'spread_rows'} = 1;
			$$self{'spread_columns'} = 1;
			$$self{'spreads'} = 1;
		} # end if
	} # end if
	return $self;
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
	$$specs{'rdbGrainDirection'.$qty_index} = $self->grain_direction() if ! $$specs{'chkOverrideGrainDirection'.$qty_index};
	my $Paper = $self->Paper();
	if ( $Paper and ($Paper->type() eq 'Roll') and $Paper->height() ) {
		$$specs{'CutOff'.$qty_index} = $Paper->height();
	} else {
		$$specs{'CutOff'.$qty_index} = '';
	} # end if
} # end sub Save

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
	my $height = $$self{'layout_height'} + $$self{'grip'} + $$self{'cropmark_top'} + $$self{'cropmark_bottom'} + ( $$self{'colour_bar_orientation'} eq 'Width' ? $$self{'colour_bar_size'} : 0 );
#$openprint::log->warn("Height: $height");
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
	$$self{'start_columns'} = $$self{'columns'} if ! $$self{'start_columns'};
	$$self{'start_rows'} = $$self{'rows'} if ! $$self{'start_rows'};
	if ( $$self{'rotate_sheet'} ) {
		$$self{'paper'}->height( @_ ) if @_;
		return $self->Paper()->height() / ( $$self{'start_columns'} / $$self{'columns'} );
	} else {
		$$self{'paper'}->width( @_ ) if @_;
		return $self->Paper()->width() / ( $$self{'start_columns'} / $$self{'columns'} );
	} # end if
} # end sub sheet_width

sub sheet_height {
	my $self = shift;
	$$self{'start_columns'} = $$self{'columns'} if ! $$self{'start_columns'};
	$$self{'start_rows'} = $$self{'rows'} if ! $$self{'start_rows'};
	if ( $$self{'rotate_sheet'} ) {
		$$self{'paper'}->width( @_ ) if @_;
		return $self->Paper()->width() / ( $$self{'start_rows'} / $$self{'rows'} );
	} else {
		$$self{'paper'}->height( @_ ) if @_;
		if ( ! $self->Paper()->height() ) {
			return $$self{'cut_off'} / ( $$self{'start_rows'} / $$self{'rows'} );
		} else {
			return $self->Paper()->height() / ( $$self{'start_rows'} / $$self{'rows'} );
		} # end if
	} # end if
} # end sub sheet_height

sub pages {
	return $_[0]{'pages'};
	#return $_[0]{'pages'} ? $_[0]{'pages'} : $_[0]{'spreads'} * $_[0]{'spread_size'};
}

sub grain_direction {
	my $self = shift;
	if ( ! $$self{'grain_direction'} ) {
		if ( $$self{'rotate_sheet'} ) {
			if ( $$self{'image_orientation'} eq 'Vertical' ) {
				$$self{'grain_direction'} = $self->Paper()->grain_direction() eq 'width' ? 'height' : 'width';
			} else {
				$$self{'grain_direction'} = $self->Paper()->grain_direction();
			} # end if
		} else {
			if ( $$self{'image_orientation'} eq 'Vertical' ) {
				$$self{'grain_direction'} = $self->Paper()->grain_direction();
			} else {
				$$self{'grain_direction'} = $self->Paper()->grain_direction() eq 'width' ? 'height' : 'width';
			} # end if
		} # end if
	} # end if
	return $$self{'grain_direction'};
} # end sub grain_direction

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

sub to_string {
	if ( ! $_[0]{'to_string'} ) {
		$_[0]{'to_string'} = sprintf('%s %dx%d+%dx%d=%dout %dx%d=%dp %sx%s %s', $_[0]->Press()->id(), $_[0]->get('columns','rows','dutch_columns','dutch_rows','imposition','page_columns','page_rows','pages', 'sheet_width','sheet_height', 'image_orientation') );
	}
	return $_[0]{'to_string'};
} # end sub to_string

1;

__END__
~       
