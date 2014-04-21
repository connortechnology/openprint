use strict;
use Carp qw( cluck );

package openprint::Imposition;
require Math::Round;
use vars qw( $AUTOLOAD );

my @fields = (
	'start_imposition','start_columns','start_rows',
	'versions','imposition','rows','columns',
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
	'quantity','width_folds','height_folds',
	'bleed_size',
	'specs',
	'pages',
	'stock_weight',
	'sides',
	'Project',
	'printing_type',
);

sub new {
	my $self = {};
	bless $self, $_[0];

	return $self;
} # end sub new

sub AUTOLOAD {
    my $name = $AUTOLOAD;
    $name =~ s/.*://;
#$openprint::log->debug("Imposition::AUTOLOAD::$name");

    if ( @_ > 1 ) {
		$_[0]{$name} = $_[1];
		if ( sets::isin( $name, ['rows','columns','dutch_rows','dutch_columns','spread_rows','spread_columns','spreads','image_width','image_height','spread_size'] ) ) {
			$_[0]{'imposition'} = $_[0]{'rows'} * $_[0]{'columns'} + $_[0]{'dutch_rows'} * $_[0]{'dutch_columns'};
			$_[0]{'spreads'} = $_[0]{'spread_rows'} * $_[0]{'spread_columns'};
			$_[0]{'pages'} = $_[0]{'spreads'} * $_[0]{'spread_size'};
			if ( $_[0]{'image_orientation'} eq 'Vertical' ) {
				$_[0]{'layout_width'} = $_[0]{'columns'} * $_[0]{'image_width'};
				$_[0]{'layout_height'} = $_[0]{'rows'} * $_[0]{'image_height'};
				if ( $_[0]{'dutch_orientation'} eq 'width' ) {
					$_[0]{'layout_width'} += $_[0]{'dutch_columns'} * $_[0]{'image_height'};
					my $dutch_height = $_[0]{'dutch_rows'} * $_[0]{'image_width'};
					$_[0]{'layout_height'} = $dutch_height if $dutch_height > $_[0]{'layout_height'};
				} else {
					$_[0]{'layout_height'} += $_[0]{'dutch_rows'} * $_[0]{'image_width'};
					my $dutch_width = $_[0]{'dutch_columns'} * $_[0]{'image_height'};
					$_[0]{'layout_width'} = $dutch_width if $dutch_width > $_[0]{'layout_width'};
				} # end if
			} elsif ( $_[0]{'image_orientation'} eq 'Horizontal' ) {
				$_[0]{'layout_width'} = $_[0]{'columns'} * $_[0]{'image_height'};
				$_[0]{'layout_height'} = $_[0]{'rows'} * $_[0]{'image_width'};

				if ( $_[0]{'dutch_orientation'} eq 'width' ) {
					$_[0]{'layout_width'} += $_[0]{'dutch_columns'} * $_[0]{'image_width'};
					my $dutch_height = $_[0]{'dutch_rows'} * $_[0]{'image_height'};
					$_[0]{'layout_height'} = $dutch_height if $dutch_height > $_[0]{'layout_height'};
				} else {
					$_[0]{'layout_height'} += $_[0]{'dutch_rows'} * $_[0]{'image_height'};
					my $dutch_width = $_[0]{'dutch_columns'} * $_[0]{'image_width'};
					$_[0]{'layout_width'} = $dutch_width if $dutch_width > $_[0]{'layout_width'};
				} # end if
			} # end if
			#if ( $$self{'spreads'} ) {
				#$$self{'layout_width'} = $$self{'spread_columns'} * $$self{'layout_width'};
				#$$self{'layout_height'} = $$self{'spread_rows'} * $$self{'layout_height'};
			#} # end if
	#} else {
#$openprint::log->debug("optimise $name" . ( @_ > 1 ? 'set to ' . $_[1] : '' ) );
		} # end if
	} # end if
	return $_[0]{$name};
} # end sub AUTOLOAD

sub display {
	my ( $self, $prefix ) = @_;
	my $Paper = $$self{'paper'} ? $$self{paper} : new openprint::Paper();
	#$openprint::log->debug(sprintf('Imp %s: %dx%dout %dx%d+%dx%d:%dout spreads:%dx%d=%d pages:%dx%d=%d %s on: %sx%s %.3fx%.3f %s I: %.3fx%.3f L:%.3fx%.3f %s %s minimum: %s', $prefix,
	#@$self{'quantity','start_imposition','columns','rows','dutch_columns','dutch_rows','imposition','spread_columns','spread_rows','spreads'},$self->page_columns(), $self->page_rows(), $self->pages(), $$self{'runstyle'}, $$self{paper}->{start_width},$$self{paper}->{start_height},$self->{paper}->{width},$self->{paper}->{height},$$self{Press}->{strid}, @$self{'image_width','image_height','layout_width','layout_height','image_orientation'},$self->grain_direction(), $$self{paper}->minimum_order() ) );
my ( $caller, undef, $line ) = caller;
	$openprint::log->debug(sprintf('Imp %s: %d %dx%d+%dx%d:%dout%s pages:%dx%d=%d %s on: %sx%s->%sx%s=%dsq min: %s %s %s versions: %d specs: %s from %s:%d', $prefix,
	@$self{'quantity','columns','rows','dutch_columns','dutch_rows','imposition','image_orientation'},$self->page_columns(), $self->page_rows(), $self->pages(), $$self{'runstyle'}, @$Paper{'start_width','start_height','width','height'}, $Paper->area(),$$Paper{'minimum_order'}, $$self{Press}->{strid}, ( $$self{'Price'} ? $$self{'Price'} : '' ), $$self{versions}, $$self{specs}, $caller, $line ) );
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
	my $src = $_[0];
	my $copy = new openprint::Imposition();
	@$copy{@fields} = @$src{@fields};
	$$copy{paper} = $$copy{paper}->clone() if $$copy{paper};
	return $copy
} # end copy

sub Paper {
	if ( @_ > 1 ) {
		$_[0]{'paper'} = $_[1];
	} 
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
	if ( ! $$self{'Press'} ) {
		if ( $$specs{'UsePress'} ) {
			$$self{'Press'} = openprint::Equipment->find_one('strid'=>$$specs{'UsePress'});
			if ( ! $$self{'Press'} ) {
				# This can happen when a press is deleted
				$openprint::log->debug("No Press found for $qty_index " . $$specs{'UsePress'} );
			} # end if
		} # end if
		if ( ! $$self{'Press'} ) {
			if ( ! $$specs{'ddmPress'.$qty_index} ) {
				#$openprint::log->error("No ddmPress for $qty_index");
			} else {
				$$self{'Press'} = openprint::Equipment->find_one('strid'=>$$specs{'ddmPress'.$qty_index});
				if ( ! $$self{'Press'} ) {
					$openprint::log->error("No Press found for $qty_index " . $$specs{'ddmPress'.$qty_index} );
				} # end if
			} # end if
		} # end if
		if ( ! $$self{'Press'} ) {
			$$self{'Press'} = new openprint::Equipment();
		} # end 
	} # end if
	$$self{'paper'} = openprint::Paper::load_from_signature( undef, $specs, $qty_index ) if ! $$self{'paper'};
} # end sub load_used


# Passing in the Project helps us load the paper by recommendation
sub load {
	my ( $self, $specs, $qty_index, $Project ) = @_;

	$$self{specs} = $specs;
	$$self{paper} = openprint::Paper::load_from_signature( $Project, $specs, $qty_index ) if ! $$self{'paper'};
	if ( ! $$self{'Press'} ) {
		if ( ! $$specs{'ddmPress'.$qty_index} ) {
			$openprint::log->error("No ddmPress for $qty_index for signature $$specs{SignatureIndex}");
		} else {
#Carp::cluck("Loading press in Imposition::load");
			$$self{'Press'} = openprint::Equipment->find_one('strid'=>$$specs{'ddmPress'.$qty_index});
			if ( ! $$self{'Press'} ) {
				$openprint::log->error("No Press found for $qty_index " . $$specs{'ddmPress'.$qty_index} );
			} # end if
		} # end if
		$$self{'Press'} = new openprint::Equipment() if ! $$self{'Press'};
	} # end if
	$$self{SignatureIndex} = $$specs{SignatureIndex};

	$$self{'object_width'} = $$specs{'txtWidth'};
	$$self{'object_height'} = $$specs{'txtHeight'};
	$$self{'image_width'} = $$specs{'txtImageWidth'.$qty_index};
	$$self{'image_width'} = $$self{'object_width'} if ! $$self{'image_width'};
	$$self{'image_height'} = $$specs{'txtImageHeight'.$qty_index};
	$$self{'image_height'} = $$self{'object_height'} if ! $$self{'image_height'};

	$$self{'imposition'} = $$specs{'txtImposition'.$qty_index};
	$$self{versions} = $$specs{'Versions'.$qty_index};
	$$self{'start_columns'} = $$self{'columns'} = $$specs{'hdnImpositionColumns'.$qty_index};
	$$self{'start_rows'} = $$self{'rows'} = $$specs{'hdnImpositionRows'.$qty_index};
	#$$self{'columns'} = $$self{'imposition'} / $$self{'rows'} if $$self{'rows'} and ! $$self{'columns'};
	#$$self{'rows'} = $$self{'imposition'} / $$self{'columns'} if $$self{'columns'} and ! $$self{'rows'};
	$$self{'dutch_rows'} = $$specs{'hdnImpositionDutchRows'.$qty_index};
	$$self{'dutch_columns'} = $$specs{'hdnImpositionDutchColumns'.$qty_index};
	$$self{'dutch_orientation'} = $$specs{'hdnImageOrientation'.$qty_index} eq 'Vertical' ? 'Horizontal' : 'Vertical';
	$$self{'cut_off'} = $$specs{'CutOff'.$qty_index};
	$$self{'stock_width'} = $$self{'paper'}->width();
	$$self{'stock_height'} = $$self{'cut_off'} ? $$self{'cut_off'} : $$self{'paper'}->height();

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
		$$self{pages} = $$specs{'PageQuantity'.$qty_index};
		$$self{spread_size} = $$specs{'txtSpreadSize'};
		$$self{spreads} = $$self{pages} / $$self{spread_size} if $$self{spread_size};
		$$self{'spread_rows'} = $$specs{'SpreadRows'.$qty_index};
		$$self{'spread_columns'} = $$specs{'SpreadCols'.$qty_index};
		#$$self{'layout_width'} = $$self{'spread_columns'} * $$self{'layout_width'};
		#$$self{'layout_height'} = $$self{'spread_rows'} * $$self{'layout_height'};
		#$$self{'image_width'} = $$self{'spread_columns'} * $$self{'image_width'};
		#$$self{'image_height'} = $$self{'spread_rows'} * $$self{'image_height'};

	} else {
		$$self{'spread_rows'} = Math::Round::nearest(1,$$specs{'txtWidth'} / $$specs{'txtFinalWidth'}) if $$specs{'txtFinalWidth'};
		$$self{'spread_columns'} = Math::Round::nearest(1,$$specs{'txtHeight'} / $$specs{'txtFinalHeight'}) if $$specs{'txtFinalHeight'};

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
		$$self{pages} = $$self{'spreads'} * $$self{'spread_size'};
	} # end if
	return $self;
} # end sub load

sub save {
	my ( $self, $specs, $qty_index ) = @_;
	$$specs{'txtImposition'.$qty_index} = $self->imposition();
	$$specs{'Versions'.$qty_index} = $$self{versions};
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
	$$specs{'ddmBleedSize'.$qty_index} = $$self{'bleed_size'};
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
	$_[0]{object_area} = $_[1] if @_ > 1;
	if ( ! exists $_[0]{object_area} ) {
		$_[0]{object_area} = $_[0]{object_width} * $_[0]{object_height} * $_[0]{imposition} * $_[0]{spreads};
	} 
	return $_[0]{object_area};
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
		if ( $$self{'start_columns'} and $$self{'columns'} and $$self{'start_columns'} != $$self{'columns'} ) {
		return $self->Paper()->height() / ( $$self{'start_columns'} / $$self{'columns'} );
		} else {
			return $self->Paper()->height();
		} # end if
	} else {
		$$self{'paper'}->width( @_ ) if @_;
		if ( $$self{'start_columns'} and $$self{'columns'} and $$self{'start_columns'} != $$self{'columns'} ) {
		return $self->Paper()->width() / ( $$self{'start_columns'} / $$self{'columns'} );
		} else {
			return $self->Paper()->width();
		} # end if

	} # end if
} # end sub sheet_width

sub sheet_height {
	my $self = shift;
	$$self{'start_columns'} = $$self{'columns'} if ! $$self{'start_columns'};
	$$self{'start_rows'} = $$self{'rows'} if ! $$self{'start_rows'};
	if ( $$self{'rotate_sheet'} ) {
		$$self{'paper'}->width( @_ ) if @_;
			if ( $$self{'start_rows'} and $$self{'rows'} and $$self{'start_rows'} != $$self{'rows'} ) {
		return $self->Paper()->width() / ( $$self{'start_rows'} / $$self{'rows'} );
		} else {
			return $self->Paper()->width();
		} # end if
	} else {
		$$self{'paper'}->height( @_ ) if @_;
		if ( ! $self->Paper()->height() ) {
			if ( $$self{'start_rows'} and $$self{'rows'} and $$self{'start_rows'} != $$self{'rows'} ) {
			return $$self{'cut_off'} / ( $$self{'start_rows'} / $$self{'rows'} );
			} else {
				return $$self{'cut_off'};
			} # end if
		} else {
			if ( $$self{'start_rows'} and $$self{'rows'} and $$self{'start_rows'} != $$self{'rows'} ) {
			return $self->Paper()->height() / ( $$self{'start_rows'} / $$self{'rows'} );
			} else {
			return $self->Paper()->height();
			} 
		} # end if
	} # end if
} # end sub sheet_height

sub sheet_area {
	return $_[0]->sheet_width() * $_[0]->sheet_height();
} # end sub sheet_area

sub pages {
	return $_[0]{'pages'};
	#return $_[0]{'pages'} ? $_[0]{'pages'} : $_[0]{'spreads'} * $_[0]{'spread_size'};
}

# Is in relation to the image.
sub grain_direction {
	my $self = $_[0];
	if ( @_ > 1 ) {
		$$self{'grain_direction'} = $_[1];
	} # end if
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
		$_[0]{'to_string'} = sprintf('%s %dx%d+%dx%d=%dout %dx%d=%dp %sx%s %s', ( $_[0]{Press} ? $_[0]->Press()->strid() : 'unknown equipment' ), $_[0]->get('columns','rows','dutch_columns','dutch_rows','imposition','page_columns','page_rows','pages', 'sheet_width','sheet_height', 'image_orientation') );
	}
	return $_[0]{'to_string'};
} # end sub to_string

sub bleed_size {
	$_[0]{'bleed_size'} = $_[1] if @_ > 1;
	return $_[0]{'bleed_size'};
} # end sub bleed_size
sub runstyle {
	$_[0]{'runstyle'} = $_[1] if @_ > 1;
	return $_[0]{'runstyle'};
} # end sub runstyle
sub quantity {
	$_[0]{'quantity'} = $_[1] if @_ > 1;
	return $_[0]{'quantity'};
} # end subquantity
sub sides {
	$_[0]{'sides'} = $_[1] if @_ > 1;
	return $_[0]{'sides'};
} # end sub sides
sub Press { 
	$_[0]{Press} = $_[1] if @_ > 1;
	return $_[0]{Press};
} # end sub Press

sub DESTROY {
}

1;
__END__
