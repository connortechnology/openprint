use strict;
require openprint::Material;
require openprint::Service;
package openprint::Ink;
our @ISA = qw( openprint::Object );

use openprint ();

use vars qw( $table $debug $serial %fields %transforms %defaults );
$debug = 0;

$table = 'inks';
$serial = 'inks_id_seq';

%fields = (
	id			=>	'id',
	pmsid		=>	'pmsid',
	name		=>	'name',
	service_id	=>	'service_id',
	mix_service_id	=>	'mix_service_id',
	material_id	=>	'material_id',
	washups		=>	'washups',
	grades		=>	'grades',
	mix			=>	'mix',
);

%defaults = (
	mix			=>	0,
	washups		=>	undef,
	mix_service_id	=>	undef,
	service_id	=>	undef,
	material_id	=>	undef,
	grades		=>	undef,
);

%transforms = (
	washups	=> [ 's/\D//g' ],
);

sub Material {
	if ( ! $_[0]{Material} ) {
		$_[0]{Material} = new openprint::Material( $_[0]{material_id} );
	}
	return $_[0]{Material};
} # end sub Material

sub Service {
	if ( ! $_[0]{Service} ) {
		$_[0]{Service} = new openprint::Service( $_[0]{service_id} );
	} # end if
	return $_[0]{Service};	
} # end sub Service

sub Mix_Service {
	if ( ! $_[0]{Mix_Service} ) {
		$_[0]{Mix_Service} = new openprint::Service( $_[0]{mix_service_id} );
	} # end if
	return $_[0]{Mix_Service};	
} # end sub Mix_Service

# Provides cached coverage lookup
sub Coverage {
	my ( $self, $Press, $grade ) = @_;
	$$self{Coverages} = {} if ! $$self{Coverages};
	$$self{Coverages}{$$Press{id}} = {} if ! $$self{Coverages};
	if ( ! $$self{Coverages}{$$Press{id}}{$grade} ) {
		$$self{Coverages}{$$Press{id}}{$grade} = $self->Material()->New_Specification('Coverage', { range=>$grade, equipment_id=>$$Press{id}} );
	}
	return $$self{Coverages}{$$Press{id}}{$grade};
}

# colour is a hash with all the info in it
# area and impressions must be pre-calculated
sub calc_price {
  my ($self, $colour, $qty_index) = @_;

  my %ink_price = (Total=>0);

  if ( $$self{material_id} ) {
    my $Press = $$colour{Press};
    my $grade = $$colour{grade};
    my $material = $self->Material();
    my %material_price = $material->get_price( undef, $Press );
    #my $coverage = $$colour{coverage}/100;

    my $Coverage = $self->Coverage($Press, $grade);
    if ((!$Coverage) or !$$Coverage{value}) {
      $openprint::log->warn("No Coverage for grade $grade Press: $$Press{strid}");
    } else {
      $openprint::log->debug("Coverage for grade $grade Press: $$Press{strid} $$Coverage{value}");
    }
    my $area = $$colour{area}[$qty_index]; # square_inches
    my $impressions = $$colour{impressions}[$qty_index];
    $openprint::log->debug("Ink $$self{name} area $area impressions $impressions");

    if ( $material_price{units} eq 'per cartridge' ) {
      my $qty = Math::Round::nearest( 0.0001, $area/$$Coverage{value} ) if $Coverage and $$Coverage{value};
      %material_price = $material->get_price( $qty, $Press );
      $material_price{quantity} = $qty;
      $material_price{Total} = Math::Round::nearest( 0.01, $material_price{Price} * $qty );
      #$price{'Ink breakdown'} .= sprintf(' mileage: %d sq in per cartridge, %.2fsq in means %.4f * $%s%s=$%.2f = $%.2f', $$Coverage{value}, $area, $qty, @material_price{'Price','units','Total'}, $ink_price{Total});
    } elsif ( $material_price{units} eq 'per can' ) {
      my $qty = POSIX::ceil($area/$$Coverage{value}) if $Coverage and $$Coverage{value};
      %material_price = $material->get_price( $qty, $Press );
      $material_price{quantity} = $qty;
      $material_price{Total} += Math::Round::nearest( 0.01, $material_price{Price} * $qty );
      #$price{'Ink breakdown'} .= sprintf(' %d%% = %d square inches, mileage: %dsquare inches/can = %d cans * $%s%s=$%.2f = $%.2f',
      #$coverage*100, $area, $$Coverage{value}, $qty, @material_price{'Price','units','Total'}, $ink_price{Total});
    } elsif ( $material_price{units} eq 'per kg' ) {
      my $qty = Math::Round::nearest(0.01, $area/$$Coverage{value}) if $Coverage and $$Coverage{value};
      %material_price = $material->get_price($qty, $Press);
      $material_price{quantity} = $qty;
      $material_price{quantity_units} = 'kg';
      $material_price{Total} = Math::Round::nearest(0.01, $material_price{Price} * $qty);
      #$price{'Ink breakdown'} .= sprintf(' %d%% = %d square inches, mileage: %dsquare inches/kg = %.2fkg * $%s%s=$%.2f = $%.2f', $coverage*100, $area, $$Coverage{value}, $qty, @material_price{'Price','units','Total'}, $ink_price{Total});
    } elsif ($material_price{units} eq 'per square foot' ) {
      $area /= 144;
      $material_price{Total} = Math::Round::nearest( 0.01, $material_price{Price} * $area );
      $material_price{quantity} = $area;
      #$price{'Ink breakdown'} .= sprintf(' Grade: %d, %.2f sq feet * $%s%s = $%.2f', $grade, $area, @material_price{'Price','units','Total'} );
    } elsif ( $material_price{units} eq 'per unit' ) {
      my $sheets_per_ink_unit = 750000;
      #my $p = Math::Round::nearest( 0.01, $material_price{Price} * ($area/$sheets_per_ink_unit) / $$project{print_sides} );
      #$price{'Ink breakdown'} .= sprintf(' %d%% %s sq inches * $%s%s / %d sheets per unit = $%.2f = $%.2f', $coverage*100, Number::Format::format_number($area), @material_price{'Price','units'}, $sheets_per_ink_unit, $p, $ink_price{Total} );
    } elsif ($material_price{units} eq 'per square inch') {
      $material_price{Total} = Math::Round::nearest(0.01, $material_price{Price} * $area);
      $material_price{quantity} = $area;
      #$price{'Ink breakdown'} .= sprintf(' Grade: %d, %d sq inches * $%s%s = $%.2f = $%.2f', $grade, $area, @material_price{'Price','units'}, $p, $ink_price{Total} );
    } elsif ( $material_price{units} eq 'per m' ) {
      $material_price{quantity} = $impressions/1000;
      $material_price{Total} = Math::Round::nearest( 0.01, $material_price{Price} * $impressions/1000 );
      #$price{'Ink breakdown'} .= sprintf( ' %d * $%.2f%s = %.2f', $colour_impressions, @material_price{'Price','units'}, $p );
    } elsif ( $material_price{units} eq 'per impression' ) {
      $material_price{quantity} = $impressions;
      $material_price{Total} = Math::Round::nearest( 0.01, $material_price{Price} * $$colour{impressions} );
      #$price{'Ink breakdown'} .= ' ' . $colour_impressions . " * $material_price{Price}$material_price{units} = " . $p;
    }

    $ink_price{Material} = \%material_price;
    $ink_price{Total} += $material_price{Total};
  } # end if material id
  return \%ink_price;
}

1;
__END__
