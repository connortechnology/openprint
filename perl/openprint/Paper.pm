use strict;
package openprint::Paper;
our @ISA = qw(openprint::Object);
require openprint::Object;
use Carp qw( cluck );
require Math::Round;

use openprint ();
use vars qw( $log %variable %config );
*variable = \%openprint::variable;
*config = \%openprint::config;
*log = \$openprint::log;

require sql;
require ssi;
require misc;
require configuration;
require openprint::Skid;
require openprint::PaperPrice;
require openprint::logs;
require openprint::Manufacturer;
require openprint::SkidContent;
require openprint::Manufacturer;
require openprint::StockBrand;
require openprint::StockFinish;
require openprint::StockColour;
require openprint::StockWeight;
require openprint::StockQuality;
require openprint::StockGroup;
require openprint::StockMaterial;
require openprint::Equipment_Stock_Setting;
require openprint::PaperAllocation;

use Time::HiRes qw{ time gettimeofday tv_interval }; 

use vars qw( $debug $table $serial %fields %find_fields %defaults %transforms %grades );

$debug = 0;
$table = 'papers';
$serial	= 'paper_id_seq';
%fields = (
		'id'			=>	'id', 
		'created_on'	=>	'created_on',
		'group_id'		=>	'group_id',
		'owner_id'		=>	'owner_id',
		'manufacturer_id'	=>	'manufacturer_id',
		'brand_id'		=>	'brand_id',
		'colour_id'		=>	'colour_id',
		'finish_id'		=>	'finish_id',
		'weight_id'		=>	'weight_id',
		'quality_id'	=>	'quality_id',
		'calliper'		=>	'calliper',
		'taxexempt1'	=>	'taxexempt1',
		'taxexempt2'	=>	'taxexempt2',
		'cuttable'		=>	'cuttable', 
		'multipart'		=>	'multipart', 
		'doublesided'	=>	'doublesided', 
		'perfecting'	=>	'perfecting', 
		'score_required'	=>	'score_required',
		'die_score_required'	=>	'die_score_required',
		'width'				=>	'width',
		'height'			=>	'height',
		'mweight'			=>	'mweight',
		'sheets_per_package'	=>	'sheets_per_package',
		'gsm'					=>	'gsm',
		'wpsi'					=>	'wpsi',
		'digital'				=>	'digital',
		'type'					=>	'type',
		'basis_width'			=>	'basis_width',
		'basis_height'			=>	'basis_height',
		'basis_mweight'			=>	'basis_mweight',
		'bladecleaning'			=>	'bladecleaning',
		'grade'					=>	'grade',
		'grain_direction'		=>	'grain_direction',
		'fsc_code'				=>	'fsc_code',
		'supplied'				=>	'supplied',
		'minimum_order'			=>	'minimum_order',
		'inventory_number'		=>	'inventory_number',
		'full_packages'			=>	'full_packages',
		'message'				=>	'message',
		'diescoring'			=>	'diescoring',
		'in_stock'				=>	'in_stock',
		'allocated'				=>	'allocated',
		'parts'					=>	'parts',
		'material_id'			=>	'material_id',
		'user_type'				=>	'user_type',
		manufacturers_name		=>	'manufacturers_name',
		);
%find_fields = (
		'manufacturer'	=>	'(SELECT name FROM manufacturers WHERE manufacturers.id=papers.manufacturer_id)',
		'group'	=>	'(SELECT name FROM stockgroups WHERE stockgroups.id=papers.group_id)',
		'material'	=>	'(SELECT name FROM stockmaterials WHERE stockmaterials.id=papers.material_id)',
		'brand'	=>	'(SELECT name FROM stockbrands WHERE stockbrands.id=papers.brand_id)',
		'finish'	=>	'(SELECT name FROM stockfinishes WHERE stockfinishes.id=papers.finish_id)',
		'colour'	=>	'(SELECT name FROM stockcolours WHERE stockcolours.id=papers.colour_id)',
		'weight'	=>	'(SELECT name FROM stockweights WHERE stockweights.id=papers.weight_id)',
		'quality'	=>	'(SELECT name FROM stockqualities WHERE stockqualities.id=papers.quality_id)',
		'size'		=>	q`width || '" x ' || height || '"'`,
		'sheetsize'		=>	q`width || '" x ' || height || '"'`,
		allocated_to_docket	=>	'(SELECT docket FROM paper_allocations WHERE paper_id = papers.id)',
		'project_type_name'	=>	'(SELECT name FROM project_types WHERE id IN ( SELECT lngProjectTypeIndex FROM Paper_Recommendations WHERE lngPaperIndex = papers.id ) )',
		'project_type_id'	=>	'(SELECT lngProjectTypeIndex FROM Paper_Recommendations WHERE lngPaperIndex = papers.id)',
		'stock_settings_equipment_id'	=>	'(SELECT equipment_id FROM equipment_stock_settings WHERE stock_id=papers.id)',
		);

%transforms = (
	manufacturers_name => [ 's/^\s+//', 's/\s+$//', 's/\s\s+$/ /g' ],
	gsm	=>	 [ 's/[^\d\.]//g' ],
);

%defaults = (
	created_on	=>	q`'NOW()'`,
	basis_width	=>	undef,
	basis_height	=>	undef,
	basis_mweight	=>	undef,
	width		=>	undef,
	height		=>	undef,
	gsm			=>	undef,	
	grade		=>	undef,
	calliper	=>	undef,
	allocated	=>	q`'0'`,
	in_stock	=>	q`'0'`,
	user_type	=>	q`''`,
	score_required	=>	'0',
	die_score_required	=>	'0',
	supplied		=>	undef,
	multipart	=>	0,
	sheets_per_package	=>	undef,
	wpsi				=>	undef,
	type				=>	q`''`,
	manufacturer_id		=>	undef,
	group_id			=>	undef,
);

%grades = (
1	=>	'1 Gloss-coated stock',
2	=>	'2 Matte-coated stock',
3	=>	'3 Gloss-coated, web stock', 
4	=>	'4 Uncoated, white stock', 
5	=>	'5 Uncoated, yellow stock'
);
sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Papers WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
	if ( exists $$data{allocated} ) {
		$$self{allocated} = $$data{allocated}
	}
	@$self{'start_width','start_height'} = @$self{'width','height'};
} # end sub load

# Returns a copy of the paper object.
sub copy {
	my $New = $_[0]->clone();
	$$New{id} = '';
	$$New{Prices} = [ $_[0]->Prices() ];
	$$New{recommendations} = [ $_[0]->recommendations() ];
	return $New;
} # end sub copy

sub Prices {
	if ( @_ > 1 ) {
		$_[0]{Prices} = $_[1];
	} # end if
	if ( ! $_[0]{Prices} ) {
		$_[0]{Prices} = [ openprint::PaperPrice->find( paper_id => $_[0]{id} ) ] if $_[0]{id};
	} # end if
	return @{$_[0]{Prices}} if $_[0]{Prices};
	return ();
} # end sub Prices

sub save {
	my ( $self, $hash ) = @_;

	$self->set($hash);
	
	if ( $$self{'group'} and ! $$self{'group_id'} ) {
		my $Group = openprint::StockGroup->find_one('name lc'=>lc openprint::StockGroup->transform( 'name', $$self{'group'} ) );
		if ( ! $Group ) {
			my $Group = new openprint::StockGroup();
			if ( $_ = $Group->save( {'name'=>$$self{'group'}} ) ) {
				return $_;
			} # end if
		} # end if
		@$self{'group_id','group'} = @$Group{'id','name'};
	} # end if group_id
	if ( $$self{'material'} and ! $$self{'material_id'} ) {
		my $Material = openprint::StockMaterial->find_one('name lc'=>lc openprint::StockMaterial->transform( 'name', $$self{'material'} ) );
		if ( ! $Material ) {
			$Material = new openprint::StockMaterial();
			if ( $_ = $Material->save( {'name'=>$$self{'material'}} ) ) {
				return $_;
			} # end if
		} # end if
		@$self{'material_id','material'} = @$Material{'id','name'};
	} # end if material
	if ( $$self{'brand'} and ! $$self{'brand_id'} ) {
		my $Brand = openprint::StockBrand->find_one('name lc'=>lc openprint::StockBrand->transform( 'name', $$self{'brand'} ) );
		if ( ! $Brand ) {
			$Brand = new openprint::StockBrand();
			if ( $_ = $Brand->save({'name'=>$$self{'brand'}}) ) {
				return $_;
			} # end if
		} # end if
		@$self{'brand_id','brand'} = @$Brand{'id','name'};
	} # end if brand_id
	if ( $$self{'finish'} and ! $$self{'finish_id'} ) {
		my $Finish = openprint::StockFinish->find_one('name lc'=>lc openprint::StockFinish->transform( 'name', $$self{'finish'} ) );
		if ( ! $Finish ) {
			$Finish = new openprint::StockFinish();
			if ( $_ = $Finish->save({'name'=>$$self{'finish'}}) ) {
				return $_;
			} # end if
		} # end if
		@$self{'finish_id','finish'} = @$Finish{'id','name'};
	} # end if finish_id
	if ( $$self{'colour'} and ! $$self{'colour_id'} ) {
		my $Colour = openprint::StockColour->find_one('name lc'=>lc openprint::StockColour->transform( 'name', $$self{'colour'} ) );
		if ( ! $Colour ) {
			$Colour = new openprint::StockColour();
			if ( $_ = $Colour->save({'name'=>$$self{'colour'}}) ) {
				return $_;
			} # end if
		} # end if
		@$self{'colour_id','colour'} = @$Colour{'id','name'};
	} # end if colour_id
	if ( $$self{'weight'} and ! $$self{'weight_id'} ) {
		my $Weight = openprint::StockWeight->find_one('name lc'=>lc openprint::StockWeight->transform( 'name', $$self{'weight'} ) );
		if ( ! $Weight ) {
			$Weight = new openprint::StockWeight();
			if ( $_ = $Weight->save({ name=>$$self{weight}}) ) {
				return $_;
			} # end if
		} # end if
		@$self{'weight_id','weight'} = @$Weight{'id','name'};
	} # end if weight_id
	if ( $$self{'quality'} and ! $$self{'quality_id'} ) {
		$$self{'quality'} = openprint::StockQuality->transform( 'name', $$self{'quality'} );
		my $Quality = openprint::StockQuality->find_one('name lc'=>lc $$self{'quality'});
		if ( ! $Quality ) {
			$Quality = new openprint::StockQuality();
			if ( $_ = $Quality->save({'name'=>$$self{'quality'}}) ) {
				return $_;
			} # end if
		} # end if
		@$self{'quality_id','quality'} = @$Quality{'id','name'};
	} # end if quality_id
	if ( $$self{'manufacturer'} and ! $$self{'manufacturer_id'} ) {
		my $Manufacturer = openprint::Manufacturer->find_one('name lc'=>lc openprint::Manufacturer->transform( 'name', $$self{'manufacturer'} ) );
		if ( ! $Manufacturer ) {
			$Manufacturer = new openprint::Manufacturer();
			if ( $_ = $Manufacturer->save({'name'=>$$self{'manufacturer'}}) ) {
				return $_;
			} # end if
		} # end if
		@$self{'manufacturer_id','manufacturer'} = @$Manufacturer{'id','name'};
	} # end if manufacturer

	if ( $$self{'id'} ) {
		$self->in_stock(undef);
		$self->allocated(undef,undef);
	} # end if

	$$self{'height'} = undef if $$self{'type'} eq 'Roll';
	
	my $error;
	$error .= 'An owner must be selected.<br/>' if ! $$self{'owner_id'};
	# Why?
	#$error .= 'A manufacturer must be selected.<br/>' if ! $$self{'manufacturer_id'};

	return $error if $error;

	my $ac = sql::start_transaction( $openprint::dbh );
	$error = $self->SUPER::save();
	if ( $error ) {
		$openprint::dbh->rollback();
		sql::end_transaction( $openprint::dbh, $ac );
		return $error;
	} # end if
	sql::execute( undef, undef, q{DELETE FROM StockBrands WHERE id NOT IN (SELECT DISTINCT brand_id FROM Papers)} );
	sql::execute( undef, undef, q{DELETE FROM StockFinishes WHERE id NOT IN (SELECT DISTINCT finish_id FROM Papers)} );
	sql::execute( undef, undef, q{DELETE FROM StockColours WHERE id NOT IN (SELECT DISTINCT colour_id FROM Papers)} );
	sql::execute( undef, undef, q{DELETE FROM StockWeights WHERE id NOT IN (SELECT DISTINCT weight_id FROM Papers)} );
	sql::execute( undef, undef, q{DELETE FROM StockGroups WHERE id NOT IN (SELECT DISTINCT group_id FROM Papers)} );
	sql::execute( undef, undef, q{DELETE FROM StockMaterials WHERE id NOT IN (SELECT DISTINCT material_id FROM Papers)} );
	sql::execute( undef, undef, q{DELETE FROM StockQualities WHERE id NOT IN (SELECT DISTINCT quality_id FROM Papers)} );

	my @recommendations = $self->recommendations();
	sql::execute( undef, undef, q{DELETE FROM Paper_Recommendations WHERE lngPaperIndex=?}, $$self{'id'} );
	foreach my $rec ( @recommendations ) {
		sql::insert( undef, undef, 'Paper_Recommendations', 'lngPaperIndex', $$self{'id'},'lngProjectTypeIndex', $rec );
	} # end foreach

	foreach my $Price ( $self->Prices() ) {
		if ( $$Price{'paper_id'} != $$self{'id'} ) {
			$$Price{'paper_id'} = $$self{'id'};
			$$Price{'id'} = undef;
		} # end if
		$Price->save();
	} # end foreach

	sql::end_transaction( $openprint::dbh, $ac );
	return;
} # end sub save

sub merge {
	my ( $self, $Duplicate ) = @_;
	my $ac = sql::start_transaction( $openprint::dbh );
	sql::update( undef, undef, 'Paper_allocations', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $self->id() );
	sql::update( undef, undef, 'Paper_Inventory', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $self->id() );
	sql::update( undef, undef, 'skid_contents', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $self->id() );
	sql::update( undef, undef, 'paper_prices', [ 'lngpaperindex=?', $Duplicate->id() ], 'lngpaperindex', $self->id() );
	sql::update( undef, undef, 'paper_recommendations', [ 'lngpaperindex=?', $Duplicate->id() ], 'lngpaperindex', $self->id() );
	sql::update( undef, undef, 'manifest_content_types', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $self->id() );
	$Duplicate->delete();
	$self->save({in_stock=>undef});
	sql::end_transaction( $openprint::dbh, $ac );
} # end sub merge

sub delete {
	my $self = shift;
	my $ac = sql::start_transaction( );
	# We don't want to lose the paper if it's in a manifest
	#sql::update( undef, undef, 'manifest_content_types', ['paper_id=?', $$self{'id'}], 'paper_id', undef );
	sql::execute( undef, undef, q{DELETE FROM Paper_Allocations WHERE paper_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM Paper_Inventory WHERE paper_id=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM Paper_prices WHERE lngpaperindex=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM Paper_recommendations WHERE lngpaperindex=?}, $$self{'id'} );
	sql::execute( undef, undef, q{DELETE FROM Skid_Contents WHERE paper_id=?}, $$self{'id'} );
	foreach my $ESS ( openprint::Equipment_Stock_Setting->find('stock_id'=>$$self{'id'} ) ) {
		$ESS->destroy();
	} # end foreach
	sql::execute( undef, undef, q{DELETE FROM Papers WHERE id=?}, $$self{'id'} );

	if ( ! sql::execute( undef, undef, q{SELECT DISTINCT manufacturer_id FROM Papers WHERE manufacturer_id=?}, $$self{'manufacturer_id'} ) ) {
		sql::execute( undef, undef, q{DELETE FROM Manufacturers WHERE Id=?}, $$self{'manufacturer_id'} );
	} # end if
	if ( ! sql::execute( undef, undef, q{SELECT DISTINCT brand_id FROM Papers WHERE brand_id=?}, $$self{'brand_id'} ) ) {
		sql::execute( undef, undef, q{DELETE FROM StockBrands WHERE id=?}, $$self{'brand_id'} );
	} # end if
	if ( ! sql::execute( undef, undef, q{SELECT DISTINCT finish_id FROM Papers WHERE finish_id=?}, $$self{'finish_id'} ) ) {
		sql::execute( undef, undef, q{DELETE FROM StockFinishes WHERE Id=?}, $$self{'finish_id'} );
	} # end if
	if ( ! sql::execute( undef, undef, q{SELECT DISTINCT colour_id FROM Papers WHERE colour_id=?}, $$self{'colour_id'} ) ) {
		sql::execute( undef, undef, q{DELETE FROM StockColours WHERE Id=?}, $$self{'colour_id'} );
	} # end if
	if ( ! sql::execute( undef, undef, q{SELECT DISTINCT weight_id FROM Papers WHERE weight_id=?}, $$self{'weight_id'} ) ) {
		sql::execute( undef, undef, q{DELETE FROM StockWeights WHERE Id=?}, $$self{'weight_id'} );
	} # end if
	sql::execute( undef, undef, q{DELETE FROM StockGroups WHERE id NOT IN (SELECT DISTINCT group_id FROM Papers)} );
	sql::execute( undef, undef, q{DELETE FROM StockMaterials WHERE id NOT IN (SELECT DISTINCT material_id FROM Papers)} );
	
	# Add record to audit log - action "Delete Paper".
	new openprint::Log()->save({action=>'Delete Paper', note=>'Stock ID: '.$$self{'id'} });
	sql::end_transaction( undef, $ac );
	
} # end sub delete

sub id_string {
	my $self = shift;
	if ( @_ ) {
		$$self{'id_string'} = $_[0];
	} # end if
	if ( ! $$self{'id_string'} ) {
		my $string = join(' ', ( $self->manufacturer(), $self->brand(), $self->finish(), $self->colour(), $self->weight() ) );
		if ( $self->type() eq 'Roll' ) {
			$string .= ' ' . $self->width.'"' if $self->width();
			$string .= ' Roll ';
		} else {
			if ( $self->start_width() and ( ( $self->width() != $self->start_width() ) or ( $self->height() != $self->start_height() ) ) ) {
				$string .= ' ' . $self->start_width().'x'.$self->start_height() . ' => '. $self->width().'x'.$self->height() . ' ';
			} else {
				$string .= ' ' . $self->width().'x'.$self->height() . ' ';
			} # end if
			#$string .= $self->mweight().'M ' if $self->mweight();
		} # end if
		$string .= sprintf('%.1fPT ', 1000*$self->calliper()) if $self->calliper();
		$string .= $self->gsm().'gsm ' if $self->gsm();
		$string .= 'FSC:' . $$self{'fsc_code'} if $$self{'fsc_code'};
		$string .= 'Minimum: ' . $$self{'minimum_order'} if $$self{'minimum_order'};
		$$self{'id_string'} = $string;
	} # end if
	return $$self{'id_string'};
} # end sub id_string

sub to_string {
	my $self = shift;
	if ( @_ ) {
		$$self{'to_string'} = $_[0];
	} # end if
	if ( ! $$self{'to_string'} ) {
		my $string = ($$self{id} ? '' : 'Custom: ').join(' ', ( $self->manufacturer(), $self->brand(), $self->finish(), $self->colour(), $self->weight() ) );
		if ( $self->type() eq 'Roll' ) {
			$string .= ' ' . $self->width.'"' if $self->width();
			$string .= ' Roll ';
		} else {
			if ( $self->start_width() and ( ( $self->width() != $self->start_width() ) or ( $self->height() != $self->start_height() ) ) ) {
				$string .= ' ' . $self->start_width().'x'.$self->start_height() . ' => '. $self->width().'x'.$self->height() . ' ';
			} else {
				$string .= ' ' . $self->width().'x'.$self->height() . ' ';
			} # end if
			#$string .= $self->mweight().'M ' if $self->mweight();
		} # end if
		$string .= sprintf('%.1fPT ', 1000*$self->calliper()) if $self->calliper() and ! $self->weight() =~ /PT/;
		$string .= $self->gsm().'gsm ' if $self->gsm();
		$string .= 'FSC:' . $$self{'fsc_code'} if $$self{'fsc_code'};
		#$string .= 'Minimum: ' . $$self{'minimum_order'} if $$self{'minimum_order'};
		$$self{'to_string'} = $string;
	} # end if
	return $$self{'to_string'};
} # end sub to_string

sub material {
	my ( $self, $material ) = @_;

	if ( defined $material ) {
		$material = openprint::StockMaterial->transform('name',$material);
		my $Material = openprint::StockMaterial->find_one('name lc'=> lc $material );
		if ( $Material ) {
			@$self{'material_id','material'} = @$Material{'id','name'};
		} else {
			@$self{'material_id','material'} = ( undef, $material );
		} # end if
	} elsif ( $$self{'material_id'} and ! $$self{'material'} ) {
		$$self{'material'} = new openprint::StockMaterial( $$self{'material_id'} )->name();
	} # end if
	return $$self{'material'};
} # end sub material

sub Material {
	return new openprint::StockMaterial( $_[0]{'material_id'} );
} # end sub Material

sub group {
	my ( $self, $group ) = @_;

	if ( defined $group ) {
		$group = openprint::StockGroup->transform('name',$group);
		my $Group = openprint::StockGroup->find_one('name lc'=> lc $group );
		if ( $Group ) {
			@$self{'group_id','group'} = @$Group{'id','name'};
		} else {
			@$self{'group_id','group'} = ( undef, $group );
		} # end if
	} elsif ( $$self{'group_id'} and ! $$self{'group'} ) {
		$$self{'group'} = new openprint::StockGroup( $$self{'group_id'} )->name();
	} # end if
	return $$self{'group'};
} # end sub group

sub Brand {
	return openprint::StockBrand( $_[0]{'brand_id'} );
}

sub brand {
	if ( defined $_[1] ) {
		$_[1] = openprint::StockBrand->transform( 'name', $_[1] );
		if ( ! $_[0]{'custom'} ) {
			my $Brand = openprint::StockBrand->find_one('name lc'=> lc $_[1] );
			if ( $Brand ) {
				@{$_[0]}{'brand_id','brand'} = @$Brand{'id','name'};
			} else {
				@{$_[0]}{'brand_id','brand'} = ( undef, $_[1] );;
			} # end if
		} else {
			$_[0]{'brand'} = $_[1];
			$_[0]{'brand_id'} = undef;
		} # end if
	} elsif ( $_[0]{'brand_id'} and ! $_[0]{'brand'} ) {
		$_[0]{'brand'} = new openprint::StockBrand( $_[0]{'brand_id'} )->name();
	} # end if
	return $_[0]{'brand'};
} # end sub brand

sub Manufacturer {
	return openprint::Manufacturer( $_[0]{'manufacturer_id'} );
}
sub manufacturer {
	if ( defined $_[1] ) {
		$_[1] = openprint::Manufacturer->transform( 'name', $_[1] );
		if ( ! $_[0]{'custom'} ) {
			my $Manufacturer = openprint::Manufacturer->find_one('name lc'=> lc $_[1] );
			if ( $Manufacturer ) {
				@{$_[0]}{'manufacturer_id','manufacturer'} = @$Manufacturer{'id','name'};
			} else {
				@{$_[0]}{'manufacturer_id','manufacturer'} = ( undef, $_[1] );
			} # end if
		} else {
			$_[0]{'manufacturer'} = $_[1];
			$_[0]{'manufacturer_id'} = undef;
		} # end if
	} elsif ( $_[0]{'manufacturer_id'} and ! $_[0]{'manufacturer'} ) {
		$_[0]{'manufacturer'} = new openprint::Manufacturer( $_[0]{'manufacturer_id'} )->name();
	} # end if
	return $_[0]{'manufacturer'};
} # end sub manufacturer

sub Finish {
	return new openprint::StockFinish( $_[0]{'finish_id'} );
}
sub finish {
	if ( @_ > 1 ) {
		$_[1] = openprint::StockFinish->transform( 'name', $_[1] );
		if ( ! $_[0]{'custom'} ) {
			my $Finish = openprint::StockFinish->find_one('name lc'=> lc $_[1] );
			if ( $Finish ) {
				@{$_[0]}{'finish_id','finish'} = @$Finish{'id','name'};
			} else {
				@{$_[0]}{'finish_id','finish'} = ( undef, $_[1] );
			} # end if
		} else {
			$_[0]{'finish'} = $_[1];
			$_[0]{'finish_id'} = undef;
		} # end if
	} elsif ( $_[0]{'finish_id'} and ! $_[0]{'finish'} ) {
		$_[0]{'finish'} = new openprint::StockFinish( $_[0]{'finish_id'} )->name();
	} # end if
	return $_[0]{'finish'};
} # end sub finish

sub Colour {
	return new openprint::StockColour( $_[0]{'colour_id'} );
}
sub colour {

	if ( @_ > 1 ) {
		$_[1] = openprint::StockColour->transform( 'name', $_[1] );
		if ( ! $_[0]{'custom'} ) {
			my $Colour = openprint::StockColour->find_one('name lc'=> lc $_[1] );
			if ( $Colour ) {
				@{$_[0]}{'colour_id','colour'} = @$Colour{'id','name'};
			} else {
				$_[0]{'colour'} = $_[1];
				$_[0]{'colour_id'} = undef;
			} # end if
		} else {
			$_[0]{'colour'} = $_[1];
		} # end if
	} elsif ( $_[0]{'colour_id'} and ! $_[0]{'colour'} ) {
		$_[0]{'colour'} = new openprint::StockColour( $_[0]{'colour_id'} )->name();
	} # end if
	return $_[0]{'colour'};
} # end sub colour

sub Quality {
	return new openprint::StockQuality( $_[0]{'quality_id'} );
} # end sub Quality

sub quality {
	my ( $self, $quality ) = @_;
	if ( @_ > 1 ) {
		$quality = openprint::StockQuality->transform( 'name', $quality );
		if ( ! $$self{'custom'} ) {
			my $Quality = openprint::StockQuality->find_one('name lc'=>lc $quality );
			if ( $Quality ) {
				@$self{'quality_id','quality'} = @$Quality{'id','name'};
			} else {
				@$self{'quality_id','quality'} = ( undef, $quality );
			} # end if
		} else {
			$$self{'quality'} = $quality;
		} # end if
	} elsif ( $$self{'quality_id'} and ! $$self{'quality'} ) {
		$$self{'quality'} = new openprint::StockQuality( $$self{'quality_id'} )->name();
	} # end if
	return $$self{'quality'};
} # end sub quality

sub Weight {
	return new openprint::StockWeight( $_[0]{'weight_id'} );
}
sub weight {
	my ( $self, $weight ) = @_;
	if ( @_ > 1 ) {
		$weight = openprint::StockWeight->transform( 'name', $weight );
		if ( ! $_[0]{'custom'} ) {
			my $Weight = openprint::StockWeight->find_one('name lc'=>lc $weight);
			if ( $Weight ) {
				@{$_[0]}{'weight_id','weight'} = @$Weight{'id','name'};
			} else {
				$_[0]{weight} = $weight;
				$_[0]{weight_id} = '';
			} # end if
		} else {
			$_[0]{weight} = $weight;
		} # end if
	} elsif ( $_[0]{weight_id} and ! $_[0]{weight} ) {
		$_[0]{weight} = new openprint::StockWeight( $_[0]{weight_id} )->name();
	} # end if
	return $_[0]{weight};
} # end sub weight

sub width {
	my ( $self, $width ) = @_;
	if ( defined $width ) {
		$width =~ s/[^\d\.]//g;
		$$self{'width'} = $width;
		delete $$self{'to_string'};
		delete $$self{'id_string'};
	} # end if
	return $$self{'width'};
} # end if
sub height {
	my ( $self, $height ) = @_;
	if ( defined $height ) {
		$height =~ s/[^\d\.]//g;
		$$self{'height'} = $height;
		delete $$self{'to_string'};
		delete $$self{'id_string'};
	} # end if
	return $$self{'height'};
} # end if

sub mweight {
	my ( $self, $mweight ) = @_;
	if ( defined $mweight ) {
		$mweight =~ s/[^\d\.]//g;
		$$self{'mweight'} = 1*$mweight;
		$self->wpsi(undef) if $$self{'mweight'};
	} # end if
	if ( ! $$self{'mweight'} ) {
		if ( $$self{'gsm'} ) {
			my $wpsi = $$self{'gsm'}/703064.5;
			if ( $$self{'type'} eq 'Roll' and $$self{'basis_width'} and $$self{'basis_height'} ) {
				$$self{'mweight'} = Math::Round::round( $wpsi * $$self{'basis_width'} * $$self{'basis_height'} * 1000 );
				# MWeight is in relaion to the basis size
			} elsif ( $$self{'width'} and $$self{'height'} ) {
				$$self{'mweight'} = Math::Round::round( $wpsi * $$self{'width'} * $$self{'height'} * 1000 );
			} # end if
		} elsif ( ($self->weight() =~ /(\d+)lb/) or ($self->weight() =~ /(\d+)lbs/) ) {
			$$self{'mweight'} = Math::Round::round(($1*$$self{'width'}*$$self{'height'})/(25*38));
		} elsif ( ! $self->weight() =~ /\D/ ) {
			# weigiht of 500sheets of 25x38
#$openprint::log->debug("Auto calcing mweight from " . $self->weight() );
			$$self{'mweight'} = Math::Round(($self->weight()*$$self{'width'}*$$self{'height'})/(25*38));
		} # end if
		$self->wpsi(undef);
	} # end if
	return $$self{'mweight'};
} # end sub mweight

sub calliper {
	my $self = shift;
	if ( @_ ) {
		my $c = shift;
		$c =~ s/[^\d\.]//g;
		$$self{'calliper'} = $c;
	} # end if
	return $$self{'calliper'};
} # end sub calliper
sub sheetsize {
	my $self = shift;

	if ( $$self{'type'} eq 'Roll' ) {
		if ( $$self{'width'} ) {
			return $$self{'width'} . '"';
		} # end if
		return '';
	} else {
		return sprintf('%s" x %s"', @$self{'width','height'} );
	} # end if
} # end sub sheetsize
sub size {
	my $self = shift;

	if ( $$self{'type'} eq 'Roll' ) {
		if ( $$self{'width'} ) {
			return $$self{'width'} . '"';
		} # end if
		return '';
	} else {
		return sprintf('%s" x %s"', @$self{'width','height'} );
	} # end if
} # end sub size
sub size_id {
	return $_[0]->size();
}
sub Owner {
	my ( $self, $Owner ) = @_;
	if ( defined $Owner ) {
		$$self{'owner_id'} = $Owner->id();
	} # end if
	return new openprint::Company( $$self{'owner_id'} );
} # endn sub Owner
sub owner {
	my $self = shift;
	my $Company;
	if ( @_ and $_[0] ) {
		my @Companies = openprint::Company->find('name'=>$_[0]);
		if ( ! @Companies ) {
			$Company = new openprint::Company();
			$Company->name( $_[0] );
			$Company->save();
		} else {
			$Company = $Companies[0];
		} # end if

		$$self{'owner_id'} = $Company->id();
	} else {
		$Company = new openprint::Company( $$self{'owner_id'} );
	} # end if
	return $Company->name();
} # end sub owner
sub owner_id {
	my $self = shift;
	if ( @_ ) {
		$$self{'owner_id'} = shift;
		#$$self{'owner_id'} =~ s/\D//g;
	} # end if
	return $$self{'owner_id'};
} # end sub owner

# This function assumes that the skid contents have already been updated
sub add_inventory {
	my ( $self, $Skid, $quantity, $units, $description, $Project ) = @_;
	$quantity =~ s/[^\-\d]//g;
	$quantity = int $quantity;

	if ( ! $Project ) {
		my $docket;
		if ( $description =~ /docket (\d+)/ ) {
			$docket = $1;
		} # end if
		if ( $docket ) {
			my @Projects = openprint::Project->find(docket=>$docket);
			$Project = $Projects[0] if @Projects;
		} else {
			$Project = new openprint::Project();
		} # end if
	} # end if

	$units = $self->units() if ! $units;
	my $PI = new openprint::PaperInventory();
	$PI->save({
		paper_id	=>	$$self{id},
		user_id		=>	$openprint::session{user_id},
		poindex		=>	undef,
		instock		=>	$self->in_stock() + $quantity,
		delta		=>	$quantity,
		comment		=>	$description,
		skid_id		=>	$Skid->id(),
		units		=>	$units,
		docket		=>	$$Project{docket},
		project_id	=>	$$Project{id},
		});
	# Updates in_stock and allocated
	$self->save();
} # end sub add_inventory

sub allocate {
	my ( $self, $skid_id, $project_id, $quantity, $units, $condition_id ) = @_;

	my $skids;
	if ( ref $skid_id eq 'openprint::Skid' ) {
		$skids = [ $skid_id->id() ];
	} elsif ( ref $skid_id eq '' ) {
		$skids = [ $skid_id ];
	} else {
		$skids = $skid_id;
	} # end if

	my $PA = new openprint::PaperAllocation();
	$PA->save( {
			paper_id		=>	$$self{'id'},
			skid_ids		=>	$skids,
			quantity		=>	$quantity,
			units			=>	$units ? $units : $self->units(),
			project_id		=>	$project_id,
			operator_id		=>	$openprint::session{'user_id'},
			condition_id	=>	$condition_id,
			} );
	if ( $project_id ) {
		new openprint::Project( $project_id )->add_to_log( @openprint::session{'company_id','user_id'}, 
				qq`Allocated $quantity$$PA{units} of <a href="/employee/inventory/paper_details.html?paper_id=$$self{'id'}">` . $self->to_string().'</a>'
				);
	} # end if project_id

	$self->save();
	delete $$self{available};
	return $PA;
} # end sub allocate

sub back_ordered {
	my $self = shift;
	return 0 if ! $$self{'id'};

	return 0;
} # end sub back_ordered

sub allocated {
	return 0 if ! $_[0]{id};
	my ( $self, $project_id, $new ) = @_;
	if ( @_ == 3 ) {
		$$self{allocated} = $new;
	} # end if
	if ( $project_id ) {
		my $qty = misc::sum( map { $_->quantity() } openprint::PaperAllocation->find(paper_id=>$$self{id}, project_id=>$project_id) );
		return $qty;
	} # end if
	if ( ! defined $$self{allocated} ) {
		$$self{allocated} = misc::sum( map { $_->quantity() } openprint::PaperAllocation->find(paper_id=>$$self{id}) );
	} # end if
	return $$self{allocated};
} # end sub allocated

sub in_stock {
	return 0 if ! $_[0]{id};

	if ( @_ > 1 ) {
		if ( ref $_[1] eq 'openprint::InventoryCondition' ) {
			my $in_stock = 0;
			foreach my $C ( openprint::SkidContent->find(deleted=>0,paper_id=>$_[0]{id}, condition_id=>$_[1]->id() ) ) {
				$in_stock += $C->quantity();
			} # end foreach C
			return $in_stock;
		} else {
			$_[0]{in_stock} = $_[1];
		} # end if
	} # end if

	if ( ! defined $_[0]{in_stock} ) {
		foreach my $SkidContent ( $_[0]->SkidContents() ) {
			$_[0]{in_stock} += $SkidContent->quantity();
		} # end foreach SkidContent
	} # end if
	return $_[0]{in_stock};
} # end sub in_stock

sub SkidContents {
	if ( @_ > 1 ) {
		$_[0]{SkidContents} = $_[1];
	} # end if
	if ( ! $_[0]{SkidContents} ) {
		$_[0]{SkidContents} = [ openprint::SkidContent->find(deleted=>0,paper_id=>$_[0]{id},'quantity >'=>0,'location not in'=>['Missing']) ];
	} # end if
	return @{$_[0]{SkidContents}};
} # end sub SkidContents

sub available {
	my $self = shift;
	if ( @_ ) {
		if ( defined $_[0] ) {
			$$self{available} = $_[0];
		} else {
			delete $$self{'available'};
		} # end if
	} # end if
	return 0 if ! $$self{'id'};

	if ( ! exists $$self{available} ) {
		$$self{available} = 0;
		foreach my $SkidContent ( $self->SkidContents() ) {
			next if sets::isin( $SkidContent->condition(), ['Damaged', 'Used' ] );
			@$self{available} += int $SkidContent->quantity();
		} # end foreach SkidContent
		$$self{available} -= $self->allocated();
	} # end if
	return $$self{available};
} # end sub available

sub skids {
	return 0 if ! $_[0]{id};
	if ( $_[0]{SkidContents} ) {
		return map { $_->Skid() } @{$_[0]{SkidContents}};
	} else {
		return openprint::Skid->find( paper_id=>$_[0]{id}, 'quantity >='=>1);
	} # end if
	#return map { new openprint::Skid( $_ ) } sql::execute( undef, undef, q{SELECT skid_id FROM skid_contents WHERE paper_id=? and quantity > 0}, $$self{'id'} );
} # end sub skids

sub previous {
	my $self = shift;
	my @papers = openprint::Paper->find( 
'columns'   =>  '*,(select name from stockbrands where id=brand_id) AS brand, (select name from stockfinishes where id=finish_id) AS finish, (select name from stockcolours where id=colour_id) AS colour, (select name from stockweights where id=weight_id) AS weight',
'order'=>'brand,finish,colour,weight,width,height' );
	for ( my $i = 0; $i < @papers; $i += 1 ) {
		return $papers[$i-1] if ($papers[$i] == $self )and ($i > 0);
	} # end if
	return $self;
} # end sub previous
sub next {
	my $self = shift;
	my @papers = openprint::Paper->find_one( 
			columns   =>  '*,(select name from stockbrands where id=brand_id) AS brand, (select name from stockfinishes where id=finish_id) AS finish, (select name from stockcolours where id=colour_id) AS colour, (select name from stockweights where id=weight_id) AS weight',
'order'=>'brand,finish,colour,weight,width,height', 'brand >=' => $self->brand(), 'id !=' => $$self{id} );
	for ( my $i = 0; $i < @papers; $i += 1 ) {
		return $papers[$i+1] if ($papers[$i] == $self )and ($i < @papers);
	} # end if
	return $self;
} # end sub next

sub recommendations {
	my $self = shift;
	if ( @_ ) {
		@{$$self{recommendations}} = @_;
	} elsif ( ! exists $$self{recommendations} ) {
		if ( $$self{id} ) {
			$$self{recommendations} = [ sql::execute( undef, undef, q{SELECT lngProjectTypeIndex FROM paper_recommendations WHERE lngPaperIndex=?}, $$self{id} ) ];
		} else {
			$$self{recommendations} = [];
		} # end if
	} # end if
	return @{$$self{recommendations}};
} # end sub recommendations

# From now on, qty is always weight
sub get_price {
	my ( $self, %params ) = @_;
	
	my $price;
	my $qty = $params{weight} ? $params{weight} : $params{sheets};
	my $lookup_qty = $params{'lookup_weight'} ? $params{'lookup_weight'} : $qty;
	if ( ($params{'service'} eq 'Material') and ! $lookup_qty ) {
		Carp::cluck("Paper qty lookup with no qty");
	} #end if

	if ( $$self{'Price'} and ($params{'service'} eq 'Material') ) {
		# If custom paper
		$price = { 'price' => $$self{'Price'}, 'cost'=>$$self{'Price'}, 'units'=>$$self{'Units'} };
#$openprint::log->debug("Usnig custom price $$self{'Price'}$$self{'Units'}");
	} elsif ( $$self{'id'} ) {
		my @Prices = $self->Prices( );
		if ( (! $$self{'supplied'} ) and ! @Prices ) {
			$openprint::log->warn( 'No prices for paper ' );
			return;
		} # end if
		my $list_id = openprint::pricing::get_pricelist_id( );
		foreach my $Price ( @Prices ) {
			next if $$Price{'pricelist_id'} != $list_id;
			next if ( $params{'equipment_id'} and $$Price{'equipment_id'} and ( $params{'equipment_id'} != $$Price{'equipment_id'} ) );
			next if $$Price{'service'} ne $params{'service'};
#$openprint::log->warn(sprintf('Price: %s - %s : %s',$Price->min(), $Price->max(), $Price->price() ) );
			if ( 
					( (!(1*$Price->min())) or $Price->min() <= $lookup_qty ) and
					( (!(1*$Price->max())) or $Price->max() >= $lookup_qty )
				) {
				$price = $Price->clone();
				last;
			} # end if
		} # end foreach Price
		if ( ! $price ) {
			if ( $params{'service'} eq 'Material' or $debug ) {
				$openprint::log->warn("Unable to find price for Stock id:$$self{id} $params{service} equip: $params{equipment_id} : $qty $lookup_qty");
		foreach my $Price ( @Prices ) {
			if ( $$Price{'pricelist_id'} != $list_id ) {
				$openprint::log->debug("Wrong pricelist: " . $Price->to_string() );
				next;
			} 
			if ( $params{'equipment_id'} and $$Price{'equipment_id'} and ( $params{'equipment_id'} != $$Price{'equipment_id'} ) ) {
				$openprint::log->debug("Wrong equipment: " . $Price->to_string() );
				next;
			}
			if ( $$Price{'service'} ne $params{'service'} ) {
				$openprint::log->debug("Wrong service: " . $Price->to_string() );
				next;
			} 
#$openprint::log->warn(sprintf('Price: %s - %s : %s',$Price->min(), $Price->max(), $Price->price() ) );
			if ( 
					( (!(1*$Price->min())) or $Price->min() <= $lookup_qty ) and
					( (!(1*$Price->max())) or $Price->max() >= $lookup_qty )
				) {
				$price = $Price->clone();
				last;
			} else {
				$openprint::log->debug("Wrong qty: $lookup_qty" . $Price->to_string() );
			} # end if
		} # end foreach Price
				
			} # end if
			return;
		} # end if
		if ( $openprint::config{'ApplyMarkup'} ) {
		#$openprint::log->debug("Apply Markup: $openprint::config{'ApplyMarkup'}");	
			my $pricingpercent = $openprint::config{'ApplyMarkup'};
			#$pricingpercent =~ s/[^\d\.\-]//g;
			$pricingpercent /= 100;
			$$price{'price'} *= ( 1 + $pricingpercent );
		} # end if

		my $Pricelist = new openprint::Pricelist( $list_id );
		$$price{'currency_id'} = $Pricelist->currency_id();
		openprint::Currency::convert( $price );
	} else {
		Carp::cluck("No custom price, and no paper::id for service: $params{service}" . $self->to_string()) if $debug;
	} # end if

	my $Company = new openprint::Company( $openprint::session{company_id} );
	if ( $Company->discount() ) {
		$$price{'price'} *= 1 - ( $Company->discount()/100 );
	} # end if

	if ( $params{'service'} eq 'Material' ) {
	# Don't need to cut it because the mweight has already byeen cut
		$$price{'mweight'} = $self->mweight();
		# Prices are always stored in cwt now
		if ( ! $$self{'mweight'} ) {
			# ROll papers won't have an mweight
			$$price{'100lb'} = $$price{'price'};
			$$price{'100lb Cost'} = $$price{'cost'};
			$$price{'100lb Price'} = $$price{'price'};
			#$price{'Cost'} *= $$self{'wpsi'} * $self->width() * $self->height();
			#$price{'Price'} *= $$self{'wpsi'} * $self->width() * $self->height();
		} else {
			$$price{'100lb'} = $$price{'price'};
			$$price{'100lb Cost'} = $$price{'cost'};
			$$price{'100lb Price'} = $$price{'price'};
			#$price{'Cost'} *= $$self{'mweight'} / 100000;
			#$price{'Price'} *= $$self{'mweight'} / 100000;
		} # end if
		$$price{'100lb Total'} = $$price{'100lb Price'} * $qty/100;
	} # end if
$openprint::log->debug("Costs: cost($$price{cost}) Price($$price{'100lb Price'})/100lb cost($$price{'100lb Cost'})/cwt Price($$price{'Price'}) qty($qty) Total($$price{'100lb Total'})") if $debug;
	return $price;
} # end sub get_price


sub cut {
	my $self = shift;
	if ( @_ ) {
		my ( $new_width, $new_height ) = @_;
		$$self{mweight} = int( $$self{mweight} / ( ( $$self{width} * $$self{height} ) / ( $new_width * $new_height ) ) );
		$$self{width} = $new_width;
		$$self{height} = $new_height;
	} else {
		if ( $$self{height} > $$self{width} ) {
			$$self{height} /= 2;
		} else {
			$$self{width} /= 2;
		} # end if
		$$self{mweight} /= 2;
	} # end if
	delete $$self{'to_string'};
	delete $$self{'id_string'};
	$$self{'grain_direction'} = undef; # force recalc of gd
} # end sub cut

sub minimum_order {
	my $self = shift;
	if ( @_ ) {
		$$self{'minimum_order'} = shift;
	} # end if

#$openprint::log->debug("SPP: $$self{'start_width'} / $$self{'width'} ) * int( $$self{'start_height'} / $$self{'height'} * spp $$self{'sheets_per_package'} * $factor;");
	return $$self{'minimum_order'} * $self->factor();
} # end minimum_order 

sub minimum_order_weight {
	my $self = $_[0];
	if ( ! exists $$self{'minimum_order_weight'} ) {
		if ( $$self{'type'} eq 'Sheet' ) {
			$$self{'minimum_order_weight'} = Math::Round::nearest( 0.1, $self->minimum_order() * $self->sheet_weight() );
		} else {
			$$self{'minimum_order_weight'} = $self->minimum_order();
		} # end if
	} # end if
	return $$self{'minimum_order_weight'};
} # end sub minimum_order_weight

sub factor {
	my $factor = int($_[0]{'start_width'} / $_[0]{'width'} ) * int( $_[0]{'start_height'} / $_[0]{'height'} ) if $_[0]{'width'} and $_[0]{'height'};
	return 1 if ! $factor;
	return $factor;
} # end sub factor

sub sheets_per_package {
	my $self = shift;
	if ( @_ ) {
		$$self{sheets_per_package} = shift;
	} # end if

#$openprint::log->debug("SPP: $$self{'start_width'} / $$self{'width'} ) * int( $$self{'start_height'} / $$self{'height'} * spp $$self{'sheets_per_package'} * $factor;");
	return $$self{'sheets_per_package'} * $self->factor();
} # end sheets_per_package
	
sub gsm {
	my $self = shift;
	if ( @_ ) {
		$$self{'gsm'} = shift;
		$self->wpsi(undef) if $$self{'gsm'};
	} elsif ( ! $$self{'gsm'} ) {
		if ( $self->wpsi(undef) ) {
			$$self{'gsm'} = sprintf('%.2f', $$self{'wpsi'} * 703064.5 );
		} else { 
			$$self{'gsm'} = 'unknown';
			$openprint::log->warn("Can't calculate gsm for " . $self->to_string() ) if $$self{brand};
		} # end if
	} # end if
	return $$self{'gsm'};
} # end sub gsm

sub wpsi {
	my $self = shift;
	if ( @_ ) {
		$$self{'wpsi'} = shift;
	} # end if
	if ( ! $$self{'wpsi'} ) {
#$openprint::log->debug("Calcing wpsi");
		if ( $$self{'gsm'} ) {
			$$self{'wpsi'} = $$self{'gsm'} / 703064.5;
		} elsif ( ( $$self{'type'} eq 'Sheet' ) and $$self{'width'} and $$self{'height'} ) {
			$$self{'wpsi'} = ($$self{'mweight'} / 1000)/($$self{'width'}*$$self{'height'});
		} elsif ( $self->basis_mweight() ) {
			$$self{'wpsi'} = ($$self{'basis_mweight'}/1000)/($self->basis_width()*$self->basis_height());
		} # end if
	} # end if
#$openprint::log->debug("Calcing wpsi $$self{wpsi}");
	return $$self{'wpsi'};
} # end if wpsi

sub JDF_Media {
	my ( $self, $doc ) = @_;

	my $Paper = $doc->createElement('Media');
	$Paper->setAttribute('Status','Available');
	$Paper->setAttribute('MediaType','Paper');
	$Paper->setAttribute('MediaUnit', $self->type() );
	$Paper->setAttribute('Brand',$self->brand() );
	#$Paper->setAttribute('Class', 'Consumable' );
	#$Paper->setAttribute('Grade', '1' );
	#$Paper->setAttribute('Locked', 'false' );
	$Paper->setAttribute('DescriptiveName',$self->to_string() );
	$Paper->setAttribute('ProductID',$self->id() );
	#$Paper->setAttribute('ID', 'Paper' );
	if ( $$self{'width'} > $$self{'height'} ) {
	$Paper->setAttribute( 'Dimension',join(' ', $$self{'width'} *72, $$self{'height'}*72) );
	$Paper->setAttribute('GrainDirection', 'ShortEdge' );
	} else {
	$Paper->setAttribute( 'Dimension',join(' ', $$self{'height'} *72, $$self{'width'}*72) );
	$Paper->setAttribute('GrainDirection', 'LongEdge' );
	} # end if
	$Paper->setAttribute('Thickness', int($$self{'calliper'}*25400));
	$Paper->setAttribute('Weight', .99*int $self->gsm() );

	return $Paper;	
} # end sub jdf

sub JDF_MediaIntent {
	my ( $self, $doc, $sig_index ) = @_;

	my $Paper = $doc->createElement('MediaIntent');
	$Paper->setAttribute('Status','Available');
	#$Paper->setAttribute('MediaUnit', $self->type() eq 'Roll' ? '' : 'Sheet' );
	#$Paper->setAttribute('Brand',$self->brand() );
	$Paper->setAttribute('Class', 'Intent' );
	$Paper->setAttribute('Locked', 'false' );
	$Paper->setAttribute('DescriptiveName',$self->to_string() );
	$Paper->setAttribute('ProductID',$self->id() );
	#$Paper->setAttribute('Type', 'ConventionalPrinting' );
	$Paper->setAttribute('ID', 'Paper'.$sig_index );
	#$Paper->setAttribute( 'Dimensions',join(' ',
				#Math::Calc::Units::convert($$self{'width'}.'in','mm'),
				#Math::Calc::Units::convert($$self{'height'}.'in','mm'),
#) );

	my $MediaType = $Paper->appendChild( $doc->createElement( 'MediaType' ) );
	$MediaType->setAttribute('DataType','EnumerationSpan');
	$MediaType->setAttribute('Preferred','Paper');

	my $Grade = $Paper->appendChild( $doc->createElement( 'Grade' ) );
	$Grade->setAttribute('DataType','IntegerSpan');
	$Grade->setAttribute('Preferred','1');

	my $Weight = $Paper->appendChild( $doc->createElement( 'Weight' ) );
	$Weight->setAttribute('DataType','NumberSpan');
	$Weight->setAttribute('Preferred', $$self{'mweight'}*.45359237 ); #Kg

	my $Thickness = $Paper->appendChild( $doc->createElement( 'Thickness' ) );
	$Thickness->setAttribute('DataType','NumberSpan');
	$Thickness->setAttribute('Preferred', $$self{'calliper'}*25.4 ); #mm

	my $GrainDirection = $Paper->appendChild( $doc->createElement( 'GrainDirection' ) );
	$GrainDirection->setAttribute('DataType','EnumerationSpan');
	$GrainDirection->setAttribute('Preferred', 'LongEdge' );

	my $MediaColor = $Paper->appendChild( $doc->createElement( 'MediaColor' ) );
	$MediaColor->setAttribute('DataType','EnumerationSpan');
	$MediaColor->setAttribute('Preferred',$self->colour() );

	my $MediaBrand = $Paper->appendChild( $doc->createElement( 'StockBrand' ) );
	$MediaBrand->setAttribute('DataType','StringSpan');
	$MediaBrand->setAttribute('Preferred',$self->brand() );

	my $FrontCoatings = $Paper->appendChild( $doc->createElement( 'FrontCoatings' ) );
	$FrontCoatings->setAttribute('DataType','EnumerationSpan');
	$FrontCoatings->setAttribute('Preferred',$openprint::JDF::coatings{$self->finish()} );

	my $BackCoatings = $Paper->appendChild( $doc->createElement( 'BackCoatings' ) );
	$BackCoatings->setAttribute('DataType','EnumerationSpan');
	$BackCoatings->setAttribute('Preferred', $self->doublesided() ? $openprint::JDF::coatings{$self->finish()} : undef );
	
	return $Paper;	
} # end sub jdf

sub multipart {
	my $self = shift;

	if ( @_ ) {
		$$self{'multipart'} = int shift;
	} # end if
	return $$self{'multipart'};
}

sub load_from_signature {
	my ( $Project, $specs, $qty_index ) = @_;

	#$qty_index = $Project->ordered_quantity_index() if ! $qty_index;

	my $Paper;
	if ( $$specs{'rdbSpecificStock'} eq 'Y' ) {
		$Paper = new openprint::Paper();
		$$Paper{'custom'} = 1;
		$Paper->brand( $$specs{'txtSpecificStockBrand'} );
		$Paper->finish( $$specs{'txtSpecificStockFinish'} );
		$Paper->colour( $$specs{'txtSpecificStockColour'} );
		$Paper->weight( $$specs{'txtSpecificStockWeight'} );
		$Paper->calliper( $$specs{'txtSpecificStockCalliper'} );
		$Paper->start_width( $$specs{'txtSpecificStockWidth'} );
		$Paper->start_height( $$specs{'txtSpecificStockHeight'} );
		if ( $qty_index ) {
			$Paper->width( $$specs{'StockWidth'.$qty_index} );
			$Paper->height( $$specs{'StockHeight'.$qty_index} );
		} else {
			$Paper->width( $$specs{'txtSpecificStockWidth'} );
			$Paper->height( $$specs{'txtSpecificStockHeight'} );
		} # end if
		$Paper->gsm( $$specs{'txtStockGSM'} );
		$Paper->type( $$specs{'StockType'} );

		$Paper->minimum_order( $$specs{'minimum_order'} );
		$Paper->sheets_per_package( $$specs{'sheets_per_package'} );
		$Paper->full_packages( $$specs{'full_packages'} );
		$Paper->cuttable( exists $$specs{'cuttable'} ? $$specs{'cuttable'} : 1 );
		$Paper->digital(1);
		$Paper->perfecting($$specs{'perfecting'});

		$Paper->doublesided($$specs{'CustomSheetDoubleSided'});
		$Paper->grade( $$specs{'StockGrade'});

		$$Paper{Price} = $$specs{'CustomStockPrice'};
		$$Paper{Units} = $$specs{'CustomStockPriceUnits'};
		$Paper->basis_width( $$specs{'basis_width'} );
		$Paper->basis_height( $$specs{'basis_height'} );
		$Paper->basis_mweight( $$specs{'basis_mweight'} ) if $$specs{'basis_mweight'};
		$Paper->score_required( $Paper->calliper() > 0.008 );
		#if ( $$specs{'StockType'} ne 'Roll' ) {
			$Paper->mweight( $$specs{'txtCustomMWeight'} ) if ! $Paper->gsm();
		#} # end if
		$Paper->supplied( $$specs{'rdbSuppliedStock'} eq 'Y' ? 1 : 0 );
	} else {
		my $Press = openprint::Equipment->find_one(strid=>$$specs{"ddmPress$qty_index"}) if $qty_index;

		if ( $qty_index and $$specs{'paper_id'.$qty_index} ) {
			$Paper = new openprint::Paper( $$specs{'paper_id'.$qty_index} );
			$Paper = $Paper->id() ? $Paper : undef;
			$openprint::log->debug("Loading by paper id" . $Paper->to_string() ) if $debug;
		} elsif ( ! ( $$specs{'ddmStockBrand'} and $$specs{'ddmStockFinish'} and $$specs{'ddmStockColour'} and $$specs{'ddmStockWeight'} ) ) {
			return new openprint::Paper();
		} # end if

		if ( ! $Paper ) {
			my %params = (
					'supplied is null or ='	=> $$specs{'rdbSuppliedStock'},
					'brand'	 	=> $$specs{'ddmStockBrand'},
					'finish'	=> $$specs{'ddmStockFinish'},
					'colour'	=> $$specs{'ddmStockColour'},
					'weight'	=> $$specs{'ddmStockWeight'},
					( $Project ? ( 'project_type_id any'=> $Project->type_id() ) : () ),
					( $$specs{'PrintingType'.$qty_index} eq 'Digital' ? ( 'digital'=>1 ) : () ),
					'order'		=>	'minimum_order',
					);
			if ( $qty_index and $$specs{'hdnSuppliedStockWidth'.$qty_index} ) {
				$params{'width'} = $$specs{'hdnSuppliedStockWidth'.$qty_index};
				$params{'type'}	= $$specs{'StockType'.$qty_index};
				if ( $params{'type'} ne 'Roll' ) {
					$params{'height'} = $$specs{'hdnSuppliedStockHeight'.$qty_index};
				} # end if
			} # end if
			my @Papers = openprint::Paper->find( %params );
			if ( ! @Papers ) {
$log->debug("Didn't find specific paper $params{'width'} x $params{'height'}");
				delete $params{'width'};
				delete $params{'height'};
				@Papers = openprint::Paper->find( %params );
			} # end if
			if ( ! @Papers ) {
				$openprint::log->warn("No papers found");
				$Paper = new openprint::Paper();
				$Paper->brand( $$specs{'ddmStockBrand'} );
				$Paper->finish( $$specs{'ddmStockFinish'} );
				$Paper->colour( $$specs{'ddmStockColour'} );
				$Paper->weight( $$specs{'ddmStockWeight'} );
				$Paper->calliper( $$specs{'txtSpecificStockCalliper'} );
				$Paper->width( $$specs{'hdnSuppliedStockWidth'} );
				$Paper->height( $$specs{'hdnSuppliedStockHeight'} );
				$Paper->start_width( $$specs{'hdnSuppliedStockWidth'} );
				$Paper->start_height( $$specs{'hdnSuppliedStockHeight'} );
				$Paper->doublesided( $$specs{'CustomSheetDoubleSided'} );
				$Paper->gsm( $$specs{'txtStockGSM'} );
				$Paper->type( $$specs{'StockType'.$qty_index} );

				$Paper->grade( $$specs{'StockGrade'});

				$$Paper{Price} = $$specs{'CustomStockPrice'};
				$$Paper{Units} = $$specs{'CustomStockPriceUnits'};
				$Paper->basis_width( $$specs{'basis_width'} );
				$Paper->basis_height( $$specs{'basis_height'} );
				$Paper->basis_mweight( $$specs{'basis_mweight'} );
				$Paper->score_required( $Paper->calliper() > 0.008 );
				$Paper->mweight( $$specs{'txtMWeight'.$qty_index} );
				@Papers = ( $Paper );
			} else {
				foreach my $P ( @Papers ) {
					if ( $Press and ( my $Stock_Setting = $Press->Stock_Setting( $P ) ) ) {
						next if $Stock_Setting->grain() eq 'Dont Use';
					} # end if
					if ( ! $$specs{'StockQuantity'.$qty_index} ) {
						$$specs{'StockQuantity'.$qty_index} = $$specs{'txtPressSheetQty'.$qty_index};
						$$specs{'StockQuantity'.$qty_index} =~ s/\D//g;
					} # end if
					if ( $$specs{'StockQuantity'.$qty_index} and ( $$specs{'StockQuantity'.$qty_index} < $P->minimum_order() ) ) {
						$openprint::log->debug("Paper no good due to minimum order. Need " . $$specs{'StockQuantity'.$qty_index} . ' have ' . $P->minimum_order() ) if $debug;
						next;
					} # end if
					$Paper = $P;
					last;
				} # end foreach
			} # end if
			if ( ( ! $Paper ) and @Papers ) {
$log->debug("No paper found matching minimum_order want($$specs{'StockQuantity'.$qty_index})");
foreach my $P ( @Papers ) {
$log->debug($P->id_string());
} # end foreach P
				$Paper = shift @Papers;
			} # end if
		} # end if Paper
		if ( ! $Paper ) {
#$log->debug("No paper found");
			$Paper = new openprint::Paper();
		} # end if

		if ( $$specs{'rdbSuppliedStock'} eq 'Y' and ! $Paper->supplied() ) {
			$Paper->supplied(1);
		} # end if
	} # end if
	if ( $qty_index and ( $$specs{'OverrideStockPrice'.$qty_index} eq 'Y' ) ) {
		$openprint::log->warn("Override price: " . $$specs{'StockPrice'.$qty_index} );
		$$Paper{'Price'} = $$specs{'StockPrice'.$qty_index};
	} # end if

	$Paper = $Paper->clone();
#$openprint::log->debug($Paper->to_string() );
	if ( $qty_index ) {
		if ( 
			( ( $Paper->width() != $$specs{'StockWidth'.$qty_index} ) or ($Paper->type() eq 'Sheet' and $Paper->height() != $$specs{'StockHeight'.$qty_index} ) )
			and
			( ( $Paper->height() != $$specs{'StockWidth'.$qty_index} ) or ($Paper->type() eq 'Sheet' and $Paper->width() != $$specs{'StockHeight'.$qty_index} ) )
) {
#Carp::cluck("Custom size $$specs{'StockWidth'.$qty_index}x$$specs{'StockHeight'.$qty_index}");
#$openprint::log->debug("Custom size $$Paper{width}x$$Paper{height} => $$specs{'StockWidth'.$qty_index}x$$specs{'StockHeight'.$qty_index}");
			if ( ! $Paper->start_width() ) {
#$openprint::log->debug("Setting start with");
				$Paper->start_width( $Paper->width() );
				$Paper->width( $$specs{'StockWidth'.$qty_index} );
			} elsif ( $Paper->width() >= $$specs{'StockWidth'.$qty_index} ) {
				$Paper->width( $$specs{'StockWidth'.$qty_index} );
			} else {
				$log->warn("Unsuitable Stock" . $Paper->to_string() . ' desired: ' . $$specs{'StockWidth'.$qty_index} . 'x' . $$specs{'StockHeight'.$qty_index});
				return new openprint::Paper();
			} # end if

			if ( $Paper->type() ne 'Roll' ) {
				if ( ! $Paper->start_height() ) {
#$openprint::log->debug("Setting start height");
					$Paper->start_height( $$specs{'StockHeight'.$qty_index} );
					$Paper->height( $$specs{'StockHeight'.$qty_index} );
				} elsif ( $Paper->height() >= $$specs{'StockHeight'.$qty_index} ) {
					$Paper->height( $$specs{'StockHeight'.$qty_index} );
				} else {
					$log->warn("Unsuitable Stock due to height");
					return new openprint::Paper();
				} # end if
			
				if ( $Paper->width() and $Paper->height() and $Paper->start_width() and $Paper->start_height() ) {
				$Paper->mweight($Paper->mweight()/( ($Paper->start_width()/$Paper->width())*($Paper->start_height()/$Paper->height())));
				} # end if
			} # end if
		} # end if
	} # end if
#$openprint::log->debug($Paper->to_string() );
	return $Paper;

} # end sub load_from_signature

sub grain_direction {
	my $self = shift;
	if ( @_ ) {
		$$self{'grain_direction'} = $_[0];
	} # end if
	if ( ! $$self{'grain_direction'} ) {
# Default to second measurement
		$$self{'grain_direction'} = 'height';
	} # end if

	return $$self{'grain_direction'};
} # end sub grain_direction

sub doublesided {
	my $self = shift;
	if ( @_ ) {
		$$self{doublesided} = shift;
	} # end if
	return 1 if ( $$self{'doublesided'} eq 'Y' );
	return 0 if ( $$self{'doublesided'} eq 'N' );
	return $$self{'doublesided'};

} # end sub doublesided

sub area {
	my $self = shift;
	return $$self{width} if ! $$self{height};
	return $$self{width}*$$self{height};
}

sub gsm_to_mweight {
	my ( $gsm ) = @_;

	my $wpsi = $gsm/703064.5;
	return sprintf('%.0f', $wpsi * 25 * 38 * 1000);
} # end sub gsm_to_mweight
sub gsm_to_weight {
	my ( $gsm ) = @_;

	my $wpsi = $gsm/703064.5;
	return sprintf('%.0f', $wpsi * 25 * 38 * 500 );
} # end sub gsm_to_mweight


sub start_area {
	my $self = shift;
	return $$self{'width'} * $$self{'height'} if ! ( $$self{'start_width'} and $$self{'start_height'} );
	return $$self{start_width} if ! $$self{start_height};
	return $$self{start_width}*$$self{start_height};
}

sub is_cut {
	my $self = shift;
	if ( $$self{'start_width'} and $$self{'start_height'} ) {
		return 1 if ( $$self{'start_width'} != $$self{'width'} or $$self{'start_height'} != $$self{'height'} );
	} # end if
	return 0;	
} # end sub is_cut

sub basis_mweight {
	my ( $self, $mweight ) = @_;
	if ( defined $mweight ) {
		$mweight =~ s/[^\d\.]//g;
		$$self{'basis_mweight'} = $mweight;
	} # end if
	if ( ! $$self{'basis_mweight'} ) {
		if ( $$self{'gsm'} ) {
			my $wpsi = $$self{'gsm'}/703064.5;
			$$self{'basis_mweight'} = sprintf('%.2f', $wpsi * $$self{'basis_width'} * $$self{'basis_height'} * 1000 );
		} elsif ( $$self{'wpsi'} ) {
			$$self{'basis_mweight'} = sprintf('%.2f', $$self{'wpsi'} * $$self{'basis_width'} * $$self{'basis_height'} * 1000 );
		} elsif ( ( $$self{'weight'} =~ /^(\d+)lb$/i ) or ( $$self{'weight'} =~ /^(\d+)lbs$/i ) or ( $$self{'weight'} =~ /^(\d+)#$/i ) ) {
			$$self{'basis_mweight'} = 2*$1;
		} # end if
	} # end if
	return $$self{'basis_mweight'};
} # end sub basis_mweight

sub basis_width {
	my ( $self, $width ) = @_;
	if ( defined $width ) {
		$width =~ s/[^\d\.]//g;
		$$self{'basis_width'} = $width;
	} # end if
	if ( ! $$self{'basis_width'} ) {
		if ( $self->brand() =~ /cover/i ) {
			$$self{'basis_width'} = 20;
		} else {
			$$self{'basis_width'} = 25;
		} # end if
	} # end if
	return $$self{'basis_width'};
} # end sub basis_width

sub basis_height {
	my ( $self, $height ) = @_;
	if ( defined $height ) {
		$height =~ s/[^\d\.]//g;
		$$self{'basis_height'} = $height;
	} # end if
	if ( ! $$self{'basis_height'} ) {
		if ( $self->brand() =~ /cover/i ) {
			$$self{'basis_height'} = 26;
		} else {
			$$self{'basis_height'} = 38;
		} # end if
	} # end if
	return $$self{'basis_height'};
} # end sub basis_height

sub sheet_weight {
	return $_[0]{'width'} * $_[0]{'height'} * $_[0]->wpsi();
} # end sub sheet_weight

sub start_sheet_weight {
	my ( $self ) = @_;
	return $$self{'start_width'} * $$self{'start_height'} * $self->wpsi();
} # end sub start_sheet_weight

sub units {
	return ($_[0]{'type'} eq 'Roll' ? 'lb' : 'sheet') . ( $_[1] == 1 ? '' : 's' );
} # end sub units
sub types {
	return ($_[0]{'type'} eq 'Roll' ? ' roll' : 'sheet') . ( $_[1] == 1 ? '' : 's' );
} # end sub units

sub Supplied {
	my ( $self ) = @_;
	my $Supplied = $self->clone();
	$$Supplied{'width'} = $$self{'start_width'} if $$self{'start_width'};
	$$Supplied{'height'} = $$self{'start_height'} if $$self{'start_height'};
	delete $$Supplied{'to_string'};
	$Supplied->mweight(0); # force recalc
	return $Supplied;
} # end sub Supplied

sub long {
	my ( $self ) = @_;
	return $$self{'width'} > $$self{'height'} ? 'width' : 'height';
}

sub short {
	my ( $self ) = @_;
	return $$self{'width'} > $$self{'height'} ? 'height' : 'width';
}

sub start_width {
	if ( @_ > 1 ) {
		$_[0]{'start_width'} = $_[1];
	} 
	return $_[0]{'start_width'};
} # end sub start_width
sub start_height {
	if ( @_ > 1 ) {
		$_[0]{'start_height'} = $_[1];
	} 
	return $_[0]{'start_height'};
} # end sub start_height

sub init_cache {
	openprint::Manufacturer->find();
    openprint::StockBrand->find();
    openprint::StockFinish->find();
    openprint::StockColour->find();
    openprint::StockWeight->find();
    openprint::StockQuality->find();
    openprint::StockMaterial->find();
}

sub link_to {
	return sprintf('<a href="/employee/inventory/paper_details.html?paper_id=%1$d">%2$s</a>', $_[0]{id}, $_[0]->to_string() );
} # end sub link_to

1;
__END__
