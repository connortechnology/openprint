# Copyright (C) 2007 Isaac Connor <isaac@connortechnology.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

package openprint::Estimating::Collating;
use strict;
use constant DEBUG => 1;

require openprint::service;
require openprint::Project;
require openprint::Estimating::Folding;

my %Specifications = (
  'Collating Capable' => {values=>['Y', 'N']},
  'Run Speed' => { units=>['per hour' ] },
  '(\w+) ?Overs' => { units => [ 'sheets', 'percent' ] },
);

# Stripping tends to be a manual process.  There are tools to help...
my %ServicePrices = (
  CollatingMinimumCharge => {},
  'CollatingMakeReady' => { units => [ 'per hour' ] },
  'CollatingPocketMakeReady' => { units => [ 'per hour' ] },
  'Collating' => { units=> ['per hour', 'per lb','per m']},
);

sub ServicePriceConfiguration {
  my $name = shift;
  return $ServicePrices{$name} if $ServicePrices{$name};
  foreach my $key (keys %ServicePrices) {
    return $ServicePrices{$key} if ($name =~ /$key/i);
  }
  return undef;
}
sub SpecificationConfiguration {
  return $Specifications{shift};
}

my @variables = (
	'alert',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'txtSignatureCount1', 'txtSignatureCount2', 'txtSignatureCount3',
	'OverrideSignatureCount1', 'OverrideSignatureCount2', 'OverrideSignatureCount3',
	'chkOverrideEquipment1', 'chkOverrideEquipment2', 'chkOverrideEquipment3',
	'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
);

sub variables {
  return @variables;
} # end sub variables

sub has_overrides {
  my ( $Project, $service_id, $specs ) = @_;
  $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

  my @v;
  foreach my $qty_index ( $Project->quantity_indexes() ) {
    push @v, "chkOverrideEquipment$qty_index" if $$specs{"chkOverrideEquipment$qty_index"};
    push @v, "OverrideSignatureCount$qty_index" if $$specs{"chkOverrideEquipment$qty_index"};
  } # end foreach

  return @v;
} # end sub has_overrides

sub neccessary {
	my ( $Project ) = @_;

	my $services = $Project->services();
	if ( $$services{PerfectBound} ) {
		return 0;
	} # end if
	if ( $$services{PlasticCoil} ) {
		return 1;
	} # end if
	if ( $$services{MetalCoil} ) {
		return 1;
	} # end if
	if ( $$services{PlasticComb} ) {
		return 1;
	} # end if
	if ( $$services{Cerlox} ) {
		return 1;
	} # end if
	if ( $$services{DoubleLoopWire} ) {
		return 1;
	} # end if
	if ( $$services{CornerStitching} ) {
		return 1;
	} # end if

	return 0;
} # end sub neccessary

sub get_signature_count {
  my ($Project, $specs, $qty_index, $Impositions, $calc_hash) = @_;
  my $folding_specs = $$calc_hash{FoldingSpecs};
  my $services = $Project->services();

  if ( (!$$specs{'OverrideSignatureCount'.$qty_index} ) or ( $$specs{'OverrideSignatureCount'.$qty_index} ne 'Y' ) ) {
    $$specs{'txtSignatureCount'.$qty_index} = 0;
    foreach my $I ( @$Impositions ) {
      my $sig_specs = $$I{specs};
      my $form = $$sig_specs{SignatureIndex};
      if ( ! $$I{Folds} ) {
        $openprint::log->error('Stitching: No folds in imposition, generating');
        if ( DEBUG ) {
          $I->display('No Folds');
        }
        if ( $folding_specs ) {
          $$I{Folds} = [ openprint::Estimating::Folding::get_Folds($folding_specs, $I, $qty_index) ];
          if ( DEBUG ) {
            foreach my $F ( @{$$I{Folds}} ) {
              $F->display('pq:'.$$F{page_quantity});
            } # end foreach F
          } # end if
        } # end if
      } # end if
      if ($$I{Folds}) {
        if (!@{$$I{Folds}}) {
          $$specs{'txtSignatureCount'.$qty_index} += 1;
        } else {
          foreach my $Fold_Imp ( @{$$I{Folds}} ) {
            $I->display() if DEBUG;
            $$specs{'txtSignatureCount'.$qty_index} += ($$I{pages} / $$Fold_Imp{pages});
            # * $Fold_Imp->quantity() / ($$I{imposition}/$$Fold_Imp{imposition});
            $openprint::log->debug("Fold $qty_index: " . $$Fold_Imp{type} . ' ' . $Fold_Imp->pages() . 'pg ' . $Fold_Imp->quantity() . ' ' . $$Fold_Imp{imposition}. ' signature count:'.$$specs{'txtSignatureCount'.$qty_index} ) if DEBUG;

          } # end foreach Fold product
        }
      } else {
        $$specs{'txtSignatureCount'.$qty_index} += $$sig_specs{'PageQuantity'.$qty_index} / $$sig_specs{txtSpreadSize};
      } # end if
    } # end foreach Impositions
    foreach my $coilname ('PlasticCoil','MetalCoil','PlasticComb','Cerlox','DoubleLoopWire') {
      if ($$services{$coilname} and @{$$services{$coilname}}) {
        my $coil_specs = openprint::service::get_specs_ref($Project, $$services{$coilname}[0]);
        $openprint::log->error("Have $coilname $$coil_specs{acetate_front} $$coil_specs{acetate_back}");
        if ($$coil_specs{acetate_front}) {
          $$specs{'txtSignatureCount'.$qty_index} += 1;
        }
        if ($$coil_specs{acetate_back}) {
          $$specs{'txtSignatureCount'.$qty_index} += 1;
        }
      } else {
        $openprint::log->error("Do not Have $coilname $$services{$coilname} ");
      }
    }
  } # end if override
} # end sub get_signature_count

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	$$specs{Status} = 'calculated';
  $$specs{alert} = '';

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

  my $calc_hash = {};

	my $printing_specs = $$calc_hash{PrintingSpecs} = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	if ( ! $$printing_specs{txtTotalPageQuantity} ) {
		$$specs{alert} = 'Number of pages is unknown!';
		return $$specs{Status} = 'uncalculated';
	} # end if

  my $folding_specs;
  if ( $$services{Folding} and @{$$services{Folding}} ) {
    $folding_specs = $$calc_hash{FoldingSpecs} = openprint::service::get_specs_ref( $Project, $$services{Folding}[0] );
  } # end if

  my @signatures = $Project->signatures();
  if ( ! @signatures ) {
    $$specs{alert} .= 'Unable to find any signatures to collate.<br/>';
    return $$specs{Status} = 'uncalculated';
  } # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
    $$specs{"txtQuantity$qty_index"} = int( $$specs{"txtQuantity$qty_index"} );
    $$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};
    my @Impositions;

    foreach my $signature_service_index ( @signatures ) {
      my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
      next if ! $$sig_specs{"txtImposition$qty_index"};
      my $form = $$sig_specs{SignatureIndex};
      if ( $folding_specs and
        ( ! $$folding_specs{"ddmEquipment-$form-$qty_index"} ) and
        ( $$folding_specs{"chkOverrideEquipment-$form-$qty_index"} )
      ) {
        $openprint::log->debug('Overrode folding to nothing.') if DEBUG;
      } # end if
      my $Imposition = new openprint::Imposition();
      $Imposition->load( $sig_specs, $qty_index, $Project );
      push @Impositions, $Imposition;
      if ( $folding_specs ) {
        $$Imposition{Folds} = [ openprint::Estimating::Folding::get_Folds( $folding_specs, $Imposition, $qty_index ) ];
        if ( DEBUG ) {
          foreach my $F ( @{$$Imposition{Folds}} ) {
            $F->display("Stitching::calc Fold: pq($$F{page_quantity})");
          } # end foreach F
        } # end if
      }
    } # end foreach signature_service_index

		my %bestPrice = internal_calc($Project, $specs, $qty_index, \@Impositions, $calc_hash);

    $$specs{'hdnBreakdown'.$qty_index} = $bestPrice{Breakdown};
		$$specs{"ddmEquipment$qty_index"} = $bestPrice{Equipment}->id();
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{UnitPriceFormat}, $bestPrice{Service} * (1+$Project->markup()/100) );
    $$specs{"MPrice$qty_index"} = sprintf( $openprint::config{UnitPriceFormat}, $bestPrice{MPrice} );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $bestPrice{Total} * (1+$Project->markup()/100) );
    $$specs{Status} = 'uncalculated' if $bestPrice{Status} eq 'uncalculated';
	} # end foreach qty_index

	return $$specs{Status};
} # end sub calc

sub internal_calc {
  my ($Project, $specs, $qty_index, $impositions, $calc_hash) = @_;
  my $printing_specs = $$calc_hash{PrintingSpecs};
  my %bestPrice;

  get_signature_count($Project, $specs, $qty_index, $impositions, $calc_hash);

	my $minimumCharge = openprint::service::get_price( 'CollatingMinimumCharge', undef, undef );

	my @possible_equipment;
	my @all_equipment = openprint::Equipment->find(
    Specifications => {'Collating Capable'=>['Y','When Printing']},
    useinestimating=>1,order=>'strName');
	my $error = '';
	if ( ! @all_equipment ) {
		$error .= 'We have no collating equipment.<br/>';
	} # end if
	foreach my $Equipment ( @all_equipment ) {
		if ( my $reason = $Equipment->fits( @$printing_specs{'txtFinalWidth','txtFinalHeight'}, $$specs{txtCalliper} ) ) {
			$error .= 'For ' . $Equipment->name() . ': '. $reason  . '<br/>';
		} else {
			push @possible_equipment, $Equipment;
		} # end if
	} # end foreach

	if (!@possible_equipment) {
# alert the user that no equipment is good.
		$$specs{alert} = "Our collating equipment cannot run this project, for the following reasons:<br/>$error<br/> Please only print flat sheets and contact another bindery.";
    $bestPrice{Status} = 'uncalculated';
		return %bestPrice;
	} # end if

	my $CollatingMakeReady = openprint::Service->find_one(name=>'CollatingMakeReady');
	my $CollatingPocketMakeReady = openprint::Service->find_one(name=>'CollatingPocketMakeReady');
	my $Collating = openprint::Service->find_one(name=>'Collating');

  my $base_qty = $$specs{"txtQuantity$qty_index"};

  my @equipment = ();
  if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
    @equipment = ( new openprint::Equipment( $$specs{"ddmEquipment$qty_index"} ) );
  } else {
    @equipment = @possible_equipment;
  } # end if

  foreach my $Equipment ( @equipment ) {
    my %price = (
      Breakdown => '',
      Service		=> 0,
      MakeReady	=> 0,
      Equipment	=> $Equipment,
      Total		=> 0,
      quantity => $base_qty,
    );
    $price{Breakdown} .= 'Pockets: '.$$specs{'txtSignatureCount'.$qty_index}.'<br/>';
    $price{Breakdown} .= 'Equipment ' . $Equipment->name().':<br/>';
    if ( $Equipment->specification('Collating Capable') eq 'When Printing' ) {
      # All signatures must be printed on the same machine
      my $cant = 0;
      foreach my $sig_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
        next if ! $$sig_specs{"txtImposition$qty_index"};

        if ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) {
          # cant
          $cant = 1;
        } # end if
      } # end foreach
      if ( $cant ) {
        $price{Breakdown} .= ': Not all signatures printed on this press.<br/>';
        next;
      } # end if
    } # end if

    my $pockets = $$specs{'txtSignatureCount'.$qty_index};

    my $qty = $base_qty;
    if ( my $Overs = $Equipment->Specification('Collating Overs') ) {
      my $overs = 0;
      if ( $$Overs{units} eq 'sheets' ) {
        $overs = int($$Overs{value});
      } elsif ( $$Overs{units} eq 'percent' ) {
        $overs = int($qty * $$Overs{value}/100);
      } else {
        $openprint::log->error("Invalid units on $$Overs{name} $$Overs{units} on $$Equipment{name}");
      } # end if
      $qty += $overs;
      $price{overs} = $overs;
      $price{Overs} = $Overs;
      $price{quantity} = $qty;
      $price{Breakdown} .= sprintf('Base quantity %d + %d%s = %d overs = %d<br/>',
        $base_qty, $$Overs{value}, $$Overs{units}, $overs, $qty);
    } # end if

    my %MakeReadyPrice = $CollatingMakeReady->get_price( undef, $Equipment ) if $CollatingMakeReady;
    $price{MakeReady} = $MakeReadyPrice{Price};
    $price{Breakdown} .= sprintf('Make Ready: $%.2f<br/>', $price{MakeReady});

    if ( $CollatingPocketMakeReady) {
      my %PocketMakeReadyPrice = $CollatingPocketMakeReady->get_price( undef, $Equipment );
      $price{PocketMakeReady} = $PocketMakeReadyPrice{Total} = $PocketMakeReadyPrice{Price} * $pockets;
      $price{Breakdown} .= sprintf('Pocket Make Ready: %d pockets @ $%.2f%s = $%.2f<br/>', $pockets, @PocketMakeReadyPrice{qw(Price units Total)});
    }

    my %servicePrice = $Collating->get_price( $pockets, $Equipment ) if $Collating;
    if (!$servicePrice{units}) {
      $$specs{alert} .= 'No units in service price.<br/>';
      $price{Service} = $servicePrice{Total} = 1000000;
    } elsif (sets::isin( $servicePrice{units}, 'per m', 'per 1000')) {
      $price{Service} = $qty*$servicePrice{Price}/1000; # Service Price for Collating is per 1000
      $price{MPrice} = $price{Service};
    } elsif ($servicePrice{units} eq 'per hour') {
      my $runspeed = $Equipment->Specification('Run Speed', $pockets);
      if ($runspeed) {
        if (lc $$runspeed{units} eq 'per hour') {
          $servicePrice{speed} = $$runspeed{value};
          $servicePrice{hours} = $qty / $$runspeed{value};
          $price{Service} = $servicePrice{Total} = $servicePrice{Price} * $qty / $$runspeed{value};
          $price{Breakdown} .= sprintf('Service: $%.2f%s * %.2fhours @%d = $%.2f<br/>', @servicePrice{qw(Price units hours speed Total)});
          $price{MPrice} = $price{Service} *1000/$$runspeed{value};
        }
      } else {
        $price{Service} = $servicePrice{Price};
        $price{Breakdown} .= 'Service: Pricing is per hour but no run speed found.<br/>';
        $$specs{alert} .= 'Pricing is per hour but no run speed set.<br/>';
      }
    } else {
      $$specs{alert} .= 'Unknown units in service price.<br/>';
    } # end if
    $price{Total} = $price{MakeReady} + $price{PocketMakeReady} + $price{Service};
    $price{Breakdown} .= sprintf('Total: $%.2f<br/>', $price{Total});

    if ( ! $bestPrice{Total} or $price{Total} < $bestPrice{Total} ) {
      %bestPrice = %price;
    } # end if
  } # end foreach equipment

  if ($minimumCharge and $bestPrice{Total} < $minimumCharge) {
     $bestPrice{Total} = $minimumCharge;
     $bestPrice{Breakdown} = 'MinimumCharge: $' . sprintf( '%.2f', $minimumCharge ) . '<br/>'
   }

  if ( ! $bestPrice{Equipment} ) {
    $bestPrice{Status} = 'uncalculated';
  } # end if
  return %bestPrice;
} # end sub calc

sub display {
    my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my @equipment = openprint::Equipment->find( 'Specifications' => {'Collating Capable'=>['Y','When Printing']}, 'useinestimating'=>1,'order'=>'strName');
	foreach my $qty_index ( $Project->quantity_indexes() ) {	
		$$variable{'ddmEquipment'.$qty_index} = ssi::make_drop_down( [ map { $_->id(), $_->name() } @equipment ], $$variable{'ddmEquipment'.$qty_index} );
	} # end foreach qty_index

} # end sub display

sub summary {
	return;
}

1;
__END__
