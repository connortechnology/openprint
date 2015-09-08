use strict;
package openprint::SkidContent;
our @ISA = qw(openprint::Object);

use vars qw( $debug %fields %find_fields %transforms %defaults $table $serial );

$debug = 0;

%fields = (
	id				=>	'id',
	skid_id			=>	'skid_id',
	paper_id		=>	'paper_id',
	quantity		=>	'quantity',
	purpose_id		=>	'purpose_id',
	units			=>	'units',
	condition_id	=>	'condition_id',
);
%find_fields = (
# FIXME
	allocated	=>	'(SELECT SUM(quantity) FROM Paper_Allocations WHERE Paper_Allocations.skid_id=Skid_Contents.skid_id AND paper_allocations.paper_id=Skid_Contents.paper_id)',
	deleted		=>	'(SELECT deleted FROM skids where skids.id=skid_id)',
	condition	=>	'(SELECT name FROM InventoryConditions WHERE id=skid_contents.condition_id)',
	location	=>	'(SELECT name from Locations WHERE id=(SELECT location_id FROM skids where skids.id=skid_id))',
	type		=>	'(SELECT type FROM Skids WHERE skids.id=skid_id)',
);
%defaults = (
	paper_id		=>	undef,
	quantity		=>	undef,
	purpose_id		=>	undef,
	condition_id	=>	undef,
);
%transforms = (
	id			=>	[ 's/\D//g', '<2147483647' ],
);
$table = 'Skid_Contents';
$serial = 'skid_contents_id_seq';

sub purpose {
	return $_[0]->Purpose()->name();
} # end sub purpose

sub Purpose {
	require openprint::StockPurpose;
	return new openprint::StockPurpose( $_[0]{purpose_id} );
} # end sub Purpose

sub Paper {
	if ( ! $_[0]{Paper} ) {
		$_[0]{Paper} = new openprint::Paper( $_[0]{paper_id} );
	} # end if
	return $_[0]{Paper};
} # end sub Paper

sub Skid {
	if ( ! $_[0]{Skid} ) {
		$_[0]{Skid} = new openprint::Skid( $_[0]{skid_id} );
	} # end if
	return $_[0]{Skid};
} # end sub Skid

sub delete {
	my $self = $_[0];
	my $error = $self->SUPER::delete();
	if ( !$error ) {
		$self->Skid()->Contents(undef);
		$self->Paper()->save();
	} # end if
} # end sub delete

sub allocateable {
	if ( ! exists $_[0]{'allocateable'} ) {
		$_[0]{'allocateable'} = $_[0]->quantity() - $_[0]->allocated();
		$_[0]{'allocateable'} = 0 if $_[0]{'allocateable'} < 0;
	} # end if
	return $_[0]{'allocateable'};
} # end sub allocateable

sub allocated {
	my $PA = openprint::PaperAllocation->find_one( paper_id=>$_[0]{paper_id},'skid_ids any'=>$_[0]{skid_id});
	return $PA->quantity() if $PA;
	return 0;
} # end sub allocated

sub condition {
    my ( $self, $condition ) = @_;

	require openprint::InventoryCondition;
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

sub Condition {
	require openprint::InventoryCondition;
	return new openprint::InventoryCondition( $_[0]{condition_id} );
} # end sub Condition

# Looks to find a PO matching this stock and pulls the value from it.
# SKids can have multiple manifests, but only one PO
sub cost {
	my $self = $_[0];
	if ( ! exists $$self{'cost'} ) {
		require openprint::ManifestContent;
		my @MCS = openprint::ManifestContent->find('skid_id'=>$$self{'skid_id'});
		foreach my $MC ( @MCS ) {
			my $Type = $MC->Type();
			if ( $Type->cost() ) {
				$$self{'cost'} = $Type->cost();
			} else {
				my $POC = $Type->PurchaseOrder_Content();
				return if ! $POC;
				my $POCurrency = $POC->PurchaseOrder()->Currency();
				if ( $POCurrency ) {
					$$self{'cost'} = $POCurrency->convert_from( $POC->price() );
				} else {
					$$self{'cost'} = $POC->price();
				} # end if
			} # end if
			last if $$self{cost};
		} # end foreach MC
	} # end if ! exists cost
    return $$self{'cost'};
} # end sub cost

# Looks to find a PO matching this stock and pulls the value from it.
sub value {
	my $self = $_[0];
	if ( ! exists $$self{'value'} ) {
		require openprint::ManifestContent;
		my @MCS = openprint::ManifestContent->find( skid_id=>$$self{'skid_id'});
		foreach my $MC ( @MCS ) {
			my $Type = $MC->Type();

			my ( $cost, $units );
			if ( $Type->cost() ) {
				$cost = $Type->cost();
				$units = $Type->cost_units();
			} else {
				my $POC = $Type->PurchaseOrder_Content();
				next if ! $POC;
				my $POCurrency = $POC->PurchaseOrder()->Currency();
				if ( $POCurrency ) {
					$cost = $POCurrency->convert_from( $POC->price() );
				} else {
					$cost = $POC->price();
				} # end if
				$units = $POC->price_units();
			} # end if
			if ( (!$units) or sets::isin( $units, ['/100lbs', '', '/cwt' ] ) ) {
				$$self{'value'} = $$self{'quantity'} * $cost / 100;
			} else {
				$$self{'value'} = $$self{'quantity'} * $cost;
			} # end if
			last if $$self{'value'};
		} # end foreach MC
	} # end if ! exists value
    return $$self{'value'};
} # end sub value

sub Manifest_Contents {
	require openprint::ManifestContent;
    my @MCS = openprint::ManifestContent->find( skid_id=>$_[0]{skid_id}, order=>'id' );
	return @MCS;
}

sub checked_out {
	if ( ! exists $_[0]{checked_out} ) {
		$_[0]{checked_out} = openprint::PaperInventory->find_one( skid_id=>$_[0]{skid_id}, paper_id=>$_[0]{paper_id}, 'comment like'=>'Checked out%' ); 
	} 
	return $_[0]{checked_out};
} # end sub checked_out

sub to_string {
	return sprintf('%s%s of %s', Number::Format::format_number( $_[0]{quantity} ), $_[0]->units(), $_[0]->Paper()->to_string() );
}

1;
__END__
