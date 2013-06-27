use strict;
package openprint::SkidContent;
our @ISA = qw(openprint::Object);

require openprint::StockPurpose;
require openprint::InventoryCondition;
require openprint::ManifestContent;
use vars qw( $log $dbh $debug %fields %transforms %defaults $table $serial );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$debug = 1;

%fields = (
	id				=>	'id',
	skid_id			=>	'skid_id',
	paper_id		=>	'paper_id',
	quantity		=>	'quantity',
	purpose_id		=>	'purpose_id',
	units			=>	'units',
	condition_id	=>	'condition_id',
);
%defaults = (
	paper_id		=>	undef,
	quantity		=>	undef,
	purpose_id		=>	undef,
	condition_id	=>	undef,
);
%transforms = (
);
$table = 'Skid_Contents';
$serial = 'skid_contents_id_seq';

sub find_one {
	shift @_ if $_[0] eq 'openprint::SkidContent';
	shift @_ if ref $_[0] eq 'openprint::SkidContent';
	my %params = @_;
	$params{'limit'}=1;
	my @Results = find(%params);
	return $Results[0] if @Results;
} # end sub find_one

sub find {
	shift @_ if $_[0] eq 'openprint::SkidContent';
	shift @_ if ref $_[0] eq 'openprint::SkidContent';
	
	my %params = @_;

	my $sql = 'SELECT * FROM Skid_Contents WHERE 1>0';
	my @values;
	if ( exists $params{'skid_id'} ) {
		if ( ref $params{skid_id} eq 'ARRAY' ) {
            $sql .= ' AND skid_id IN (' . join(',', map { '?' } @{$params{skid_id}} ) . ')';
            push @values, @{$params{skid_id}};
		} else {
			$sql .= ' AND skid_id=?';
			push @values, $params{'skid_id'};
		} # end if
	} # end if
	if ( ( exists $params{paper_id} ) and ! defined $params{paper_id} ) {
		$sql .= ' AND paper_id IS NULL';
	} # end if

	if ( $params{'paper_id'} ) {
		$sql .= ' AND paper_id=?';
		push @values, $params{'paper_id'};
	} # end if
	if ( $params{'condition_id'} ) {
		$sql .= ' AND condition_id=?';
		push @values, $params{'condition_id'};
	} # end if
	if ( $params{'Paper'} ) {
		$sql .= ' AND paper_id=?';
		push @values, $params{'Paper'}->id();
	} # end if
	if ( exists $params{'quantity_>'} ) {
		$sql .= ' AND quantity > ?';
		push @values, $params{'quantity_>'};
	} elsif ( exists $params{'quantity >'} ) {
		$sql .= ' AND quantity > ?';
		push @values, $params{'quantity >'};
	} # end if
	if ( exists $params{'allocated'} ) {
		$sql .= ' AND (SELECT SUM(quantity) FROM Paper_Allocations WHERE Paper_Allocations.skid_id=Skid_Contents.skid_id AND paper_allocations.paper_id=Skid_Contents.paper_id) = ?';
		push @values, $params{'allocated'};
	} # end if
	if ( exists $params{'allocated is null'} ) {
		$sql .= ' AND (SELECT SUM(quantity) FROM Paper_Allocations WHERE Paper_Allocations.skid_id=Skid_Contents.skid_id AND paper_allocations.paper_id=Skid_Contents.paper_id) IS NULL';
	} # end if
	if ( exists $params{'allocated is not null'} ) {
		$sql .= ' AND (SELECT SUM(quantity) FROM Paper_Allocations WHERE Paper_Allocations.skid_id=Skid_Contents.skid_id AND paper_allocations.paper_id=Skid_Contents.paper_id) IS NOT NULL';
	} # end if
	if ( exists $params{'manifestcontent_id'} ) {
		$sql .= ' AND ? IN (SELECT id FROM ManifestContents WHERE manifestcontents.skid_id=skid_contents.skid_id)';
		push @values, $params{'manifestcontent_id'};
	} # end if

	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->debug("openprint::SkidContent::find( $sql)" . $dbh->errstr);
		return;
	} elsif ( $debug ) {
		$log->debug("Loading openprint::SkidContent::find($sql) : @values # of results: " . @$data );
	} # end if
	return map { new openprint::SkidContent( $_->{id}, $_ ); } @$data;
} # end sub find

sub purpose {
	return $_[0]->Purpose()->name();
} # end sub purpose

sub Purpose {
	return new openprint::StockPurpose( $_[0]{purpose_id} );
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
	my $PA = openprint::PaperAllocation->find_one('paper_id'=>$_[0]{'paper_id'},'skid_ids any'=>$_[0]{'skid_id'});
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

sub Condition {
	return new openprint::InventoryCondition( $_[0]{'condition_id'} );
} # end sub Condition

# Looks to find a PO matching this stock and pulls the value from it.
# SKids can have multiple manifests, but only one PO
sub cost {
	my $self = $_[0];
	if ( ! exists $$self{'cost'} ) {
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
					$log->error("No POCurrency");
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
					$log->error("No POCurrency");
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

1;
__END__
