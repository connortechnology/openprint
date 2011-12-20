use strict;
package openprint::SkidContent;
our @ISA = qw(openprint::Object);

use vars qw( $debug %fields %transforms %defaults $table $serial );
use Carp qw( cluck );

require sql;
require openprint::StockPurpose;
require openprint::InventoryCondition;
require openprint::ManifestContent;

$debug = 0;

%fields = (
	'id'			=>	'id',
	'skid_id'		=>	'skid_id',
	'paper_id'		=>	'paper_id',
	'quantity'		=>	'quantity',
	'purpose_id'	=>	'purpose_id',
	'units'			=>	'units',
	'condition_id'	=>	'condition_id',
	'manifestcontent_id'	=>	'manifestcontent_id',
);
%defaults = (
	'purpose_id'	=>	undef,
	'condition_id'	=>	undef,
	'manifestcontent_id'	=>	undef,
);
%transforms = (
);
$table = 'Skid_Contents';
$serial = 'skid_contents_id_seq';

sub purpose {
	my $self = shift;
	return $self->Purpose()->name();
} # end sub purpose

sub Purpose {
	my $self = shift;
	my $Purpose = new openprint::StockPurpose( $$self{'purpose_id'} );
	return $Purpose;
} # end sub Purpose

sub Paper {
	my $self = shift;
	my $Paper = new openprint::Paper( $$self{'paper_id'} );
	return $Paper;
} # end sub Paper

sub Skid {
	return new openprint::Skid( $_[0]{'skid_id'} );
} # end sub Skid
sub delete {
	my $self = $_[0];
	my $error = $self->SUPER::delete();
	if ( !$error ) {
		$self->Paper()->save();
	} # end if
} # end sub delete
sub allocateable {
    my ( $self ) = @_;
    return $self->quantity() - $self->allocation();
} # end sub allocateable

sub allocated {
	my $PA = openprint::PaperAllocation->find_one('paper_id'=>$_[0]{'paper_id'},'skid_id'=>$_[0]{'skid_id'});
	return $PA->quantity() if $PA;
	return 0;
} # end sub allocated

sub condition {
    my ( $self, $condition ) = @_;

    if ( defined $condition ) {
		$condition = openprint::InventoryCondition->transform('name', $condition );
		my $Condition = openprint::InventoryCondition->find_one('name lc'=>$condition);
		if ( ! $Condition ) {
			$Condition = new openprint::InventoryCondition();
			$Condition->save({'name'=>$condition});
		} # end if
        @$self{'condition_id','condition'} = @$Condition{'id','name'};
    } elsif ( $$self{'condition_id'} and ! $$self{'condition'} ) {
        $$self{'condition'} = new openprint::InventoryCondition( $$self{'condition_id'} )->name();
    } # end if
    return $$self{'condition'};
} # end sub condition

# Looks to find a PO matching this stock and pulls the value from it.
sub cost {
	my $self = $_[0];
	if ( ! exists $$self{'cost'} ) {
		if ( ! $$self{'manifestcontent_id'} ) {
			my @MCS = openprint::ManifestContent->find('skid_id'=>$$self{'skid_id'});
			if ( @MCS == 1 ) {
				$self->save({'manifestcontent_id'=>$MCS[0]->id()});
			} elsif ( @MCS > 1 ) {
				$openprint::log->error("TOo many MCs ffor SKID " .$$self{'skid_id'});
			} # end if
		}
		my $MC = new openprint::ManifestContent( $$self{'manifestcontent_id'} );
		if ( ! $MC->id() ) {
			#$log->error("No Manifest Content found for skid_id $_[0]{'skid_id'}, paper_id $_[0]{'paper_id'}");
			return;
		} # end if
		if ( $MC->Type()->cost() ) {
			$$self{'cost'} = $MC->Type()->cost();
		} else {
			my $POC = $MC->Type()->PurchaseOrder_Content();
			return if ! $POC;
			my $POCurrency = $POC->PurchaseOrder()->Currency();
			if ( $POCurrency ) {
				$$self{'cost'} = $POCurrency->convert_from( $POC->price() );
			} else {
				$openprint::log->error("No POCurrency");
				$$self{'cost'} = $POC->price();
			} # end if
		} # end if
	} # end if ! exists cost
    return $$self{'cost'};
} # end sub cost
# Looks to find a PO matching this stock and pulls the value from it.
sub value {
	my $self = $_[0];
	if ( ! exists $$self{'value'} ) {
		if ( ! $$self{'manifestcontent_id'} ) {
			my @MCS = openprint::ManifestContent->find('skid_id'=>$$self{'skid_id'});
			if ( @MCS == 1 ) {
				$self->save({'manifestcontent_id'=>$MCS[0]->id()});
			} elsif ( @MCS > 1 ) {
				$openprint::log->error("TOo many MCs ffor SKID " .$$self{'skid_id'});
			} # end if
		} # end if
		my $MC = new openprint::ManifestContent( $$self{'manifestcontent_id'} );
		if ( ! $MC->id() ) {
			#$log->error("No Manifest Content found for skid_id $_[0]{'skid_id'}, paper_id $_[0]{'paper_id'}");
			return;
		} # end if
		my ( $cost, $units );
		if ( $MC->Type()->cost() ) {
			$cost = $MC->Type()->cost();
			$units = $MC->Type()->cost_units();
		} else {
			my $POC = $MC->Type()->PurchaseOrder_Content();
			return if ! $POC;
			my $POCurrency = $POC->PurchaseOrder()->Currency();
			if ( $POCurrency ) {
				$cost = $POCurrency->convert_from( $POC->price() );
			} else {
				$openprint::log->error("No POCurrency");
				$cost = $POC->price();
			} # end if
			$units = $POC->price_units();
		} # end if
		if ( (!$units) or sets::isin( $units, ['/100lbs', '', '/cwt' ] ) ) {
			$$self{'value'} = $$self{'quantity'} * $cost / 100;
		} else {
			$$self{'value'} = $$self{'quantity'} * $cost;
		} # end if
	} # end if ! exists value
    return $$self{'value'};
} # end sub value

1;
__END__
