package openprint::Paper;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;
use Carp ( cluck );

use strict;
use openprint ();
use vars qw( $log %variable %fields %transforms %defaults %config );
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
require openprint::StockName;
require openprint::StockFinish;
require openprint::StockColour;
require openprint::StockWeight;
require openprint::StockQuality;
require openprint::StockGroup;
require openprint::StockMaterial;
require openprint::Equipment_Stock_Setting;
use Time::HiRes qw{ time gettimeofday tv_interval }; 

my $debug = 0;

my @fields = (
		'id', 'created_on',
		'group_id','owner_id','manufacturer_id','quality_id','name_id','colour_id','finish_id','weight_id','calliper','taxexempt1','taxexempt2',
		'cuttable', 'multipart', 'doublesided', 'perfecting', 'score_required',
		'width','height','mweight','sheets_per_package','gsm','wpsi','digital','type','basis_width','basis_height','basis_mweight',
		'bladecleaning','grade','grain_direction','fsc_code','supplied',
		'minimum_order','inventory_number','full_packages','message','diescoring','in_stock','parts',
		'material_id',
		);

my %find_cache;

sub init_cache {
	%find_cache = ();
} # end sub init_cache

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	my $starttime = gettimeofday() if $debug;
	#my $hash_key = join(';',map { $_, ref $params{$_} eq 'HASH' ? join(';',%{$params{$_}}) :$params{$_} } sort keys %params );
#$openprint::log->debug("Hash key: $hash_key");
	#if ( $find_cache{$hash_key} ) {
		#$openprint::log->debug("Debug cached papers () () in : " . sprintf('%.4f', tv_interval( [$starttime])*1000) . 'usecs records:' . @{$find_cache{$hash_key}} ) if $debug;
		#return @{$find_cache{$hash_key}};
	#} # end if

	@params{lc keys %params} = @params{keys %params};
	my @values;
	# Can't auto-load in_stock because we have to not count Missing paper
	my $sql = 'SELECT papers.*, manufacturers.shortname AS manufacturer, papernames.shortname AS name, paperfinishes.shortname AS finish, papercolours.shortName AS colour, paperweights.shortname AS weight,(SELECT SUM(Quantity) FROM Paper_Allocations WHERE paper_id=papers.id) AS allocated FROM Papers, manufacturers, papernames,paperfinishes,papercolours,paperweights WHERE papers.manufacturer_id=manufacturers.id AND papers.name_id=papernames.id AND papers.finish_id=paperfinishes.id AND papers.colour_id=papercolours.id AND papers.weight_id=paperweights.id';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND papers.id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND papers.id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( $params{'owner_id'} ) {
		$sql .= ' AND owner_id=?';
		push @values, $params{'owner_id'};
	} # end if
	if ( $params{'owner_id !='} ) {
		$sql .= ' AND owner_id != ?';
		push @values, $params{'owner_id !='};
	} # end if
	if ( $params{'manufacturer_id'} ) {
		$sql .= ' AND manufacturer_id=?';
		push @values, $params{'manufacturer_id'};
	} # end if
	if ( $params{'manufacturer'} ) {
		$sql .= ' AND manufacturer_id=(SELECT id FROM Manufacturers WHERE longname=?)';
		push @values, $params{'manufacturer'};
	} # end if
	
	if ( $params{'group_id'} ) {
		$sql .= ' AND group_id=?';
		push @values, $params{'group_id'};
	} # end if
	if ( $params{'group'} ) {
		$sql .= ' AND group_id=(SELECT id FROM StockGroups WHERE name=?)';
		push @values, $params{'name'};
	} # end if
	if ( $params{'name_id'} ) {
		$sql .= ' AND name_id=?';
		push @values, $params{'name_id'};
	} # end if
	if ( $params{'name'} ) {
		$sql .= ' AND name_id=(SELECT id FROM PaperNames WHERE longname=?)';
		push @values, $params{'name'};
	} # end if
	if ( $params{'finish_id'} ) {
		$sql .= ' AND finish_id=?';
		push @values, $params{'finish_id'};
	} # end if
	if ( $params{'finish'} ) {
		$sql .= ' AND finish_id=(SELECT id FROM PaperFinishes WHERE longname=?)';
		push @values, $params{'finish'};
	} # end if
	if ( $params{'colour_id'} ) {
		$sql .= ' AND colour_id=?';
		push @values, $params{'colour_id'};
	} # end if
	if ( $params{'colour'} ) {
		$sql .= ' AND colour_id=(SELECT id FROM PaperColours WHERE longname=?)';
		push @values, $params{'colour'};
	} # end if
	if ( $params{'weight_id'} ) {
		$sql .= ' AND weight_id=?';
		push @values, $params{'weight_id'};
	} # end if
	if ( $params{'weight'} ) {
		$sql .= ' AND weight_id=(SELECT id FROM PaperWeights WHERE longname=?)';
		push @values, $params{'weight'};
	} # end if
	if ( $params{'quality_id'} ) {
		$sql .= ' AND quality_id=?';
		push @values, $params{'quality_id'};
	} # end if
	if ( $params{'quality'} ) {
		$sql .= ' AND quality_id=(SELECT id FROM PaperQualities WHERE longname=?)';
		push @values, $params{'quality'};
	} # end if
	if ( $params{'material_id'} ) {
		$sql .= ' AND material_id=?';
		push @values, $params{'material_id'};
	} # end if
	if ( $params{'material'} ) {
		$sql .= ' AND material_id=(SELECT id FROM StockMaterials WHERE name=?)';
		push @values, $params{'material'};
	} # end if
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'}
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND ( created_on >= ?)';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on <= ?)';
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'size'} ) {
		$sql .= ' AND width=? AND height=?';
		push @values, split 'x', $params{'size'};
	} # end if
	if ( $params{'width'} ) {
		$params{'width'} =~ s/[^\d\.]//g;
		$sql .= ' AND width=?';
		push @values, 1*$params{'width'};
	} # end if
	if ( $params{'width_>='} ) {
		$params{'width_>='} =~ s/[^\d\.]//g;
		$sql .= ' AND ( width IS NULL or width>=?)';
		push @values, 1*$params{'width_>='};
	} # end if
	if ( $params{'width_start'} ) {
		$params{'width_start'} =~ s/[^\d\.]//g;
		$sql .= ' AND width>=?';
		push @values, 1*$params{'width_start'};
	} # end if
	if ( $params{'height'} ) {
		$params{'height'} =~ s/[^\d\.]//g;
		$sql .= ' AND height=?';
		push @values, 1*$params{'height'};
	} # end if
	if ( $params{'height_start'} ) {
		$params{'height_start'} =~ s/[^\d\.]//g;
		$sql .= ' AND height>=?';
		push @values, 1*$params{'height_start'};
	} # end if
	if ( $params{'height_>='} ) {
		$params{'height_>='} =~ s/[^\d\.]//g;
		$sql .= ' AND ( height IS NULL OR height>=? )';
		push @values, 1*$params{'height_>='};
	} # end if
	if ( $params{'in_stock_start'} ) {
		$params{'in_stock_start'} =~ s/[^\d\.]//g;
		$sql .= ' AND ( in_stock IS NULL OR in_stock >= ?)';
		push @values, 1*$params{'in_stock_start'};
	} # end if
	if ( $params{'allocated_to_docket'} ) {
		$sql .= ' AND papers.id IN (SELECT paper_id FROM paper_allocations WHERE project_id IN (SELECT Index FROM Projects WHERE lngDocketNumber=?))';
		push @values, $params{'allocated_to_docket'};
	} # end if
	if ( $params{'project_type_name'} ) {
		$sql .= ' AND papers.id IN (SELECT lngPaperIndex FROM Paper_Recommendations WHERE lngProjectTypeIndex=(SELECT Id FROM Project_Types WHERE name = ?))';
		push @values, $params{'project_type_name'};
	} # end if
	if ( $params{'project_type_id'} ) {
		$sql .= ' AND papers.id IN (SELECT lngPaperIndex FROM Paper_Recommendations WHERE lngProjectTypeIndex=?)';
		push @values, $params{'project_type_id'};
	} # end if
	if ( exists $params{'fsc_code'} ) {
		if ( $params{'fsc_code'} ) {
			$sql .= ' AND fsc_code=?';
			push @values, $params{'fsc_code'};
		} else {
			$sql .= ' AND ( fsc_code IS NULL or fsc_code=? )';
			push @values, $params{'fsc_code'};
		} # end if
	} # end if
	if ( $params{'parts'} ) {
		$sql .= ' AND parts=?';
		push @values, $params{'parts'};
	} # end if
	if ( $params{'type'} ) {
		if ( ref $params{'type'} eq 'ARRAY' ) {
			if ( @{$params{'type'}} ) {
			$sql .= ' AND type IN (' . join(',', map { '?' } @{$params{'type'}} ) . ')';
			push @values, @{$params{'type'}};
			} else {
			$sql .= ' AND type IS NULL';
			} # end if
		} else {
			$sql .= ' AND type=?';
			push @values, $params{'type'};
		} # end if
	} # end if
	if ( $params{'supplied'} ) {
		if ( ref $params{'supplied'} eq 'ARRAY' ) {
			my @options;
			foreach my $option ( @{$params{'supplied'}} ) {
				if ( (! defined $option ) or ($option eq '' ) ) {
					push @options, 'supplied IS NULL';
				} else {
					push @options, 'supplied=?';
					push @values, $option;
				} # end if
			} # end foreach
			$sql .= ' AND ( ' . join(' OR ', @options ) . ' )';
		} else {
			if ( (! defined $params{'supplied'} ) or ($params{'supplied'} eq '' ) ) {
				$sql .= ' AND supplied IS NULL';
			} else {
				$sql .= ' AND (supplied IS NULL OR supplied=?)';
				push @values, $params{'supplied'} eq 'Y' ? 1 : 0;
			} # end if
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading papers SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$openprint::log->debug('No papers loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$openprint::log->debug("Debug loaded papers ($sql) (@values) in : " . sprintf('%.4f', tv_interval( [$starttime])*1000) . 'usecs records:' . @$data ) if $debug;
	} # end if
	#@{$find_cache{$hash_key}} = map { new openprint::Paper( $_->{id}, $_ ) } @$data;
	return map { new openprint::Paper( $_->{id}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT *,(SELECT SUM(Quantity) FROM Paper_Allocations WHERE paper_id=papers.id) AS allocated FROM Papers WHERE id=?}, {}, $$self{'id'} );
	} # end if
	@$self{@fields} = @$data{@fields};
	@$self{'start_width','start_height'} = @$self{'width','height'};
	@$self{'allocated'} = @$data{'allocated'};
} # end sub load


sub clone {
	my $self = shift;

	my $New = new openprint::Paper();
	@$New{keys %$self} = @$self{keys %$self};
	return $New;
} # end sub clone

# Returns a copy of the paper object.
sub copy {
	my $self = shift;

	my $New = new openprint::Paper();
	@$New{keys %$self} = @$self{keys %$self};
	$$New{'id'} = '';
	@{$$New{'Prices'}} = $self->prices();
	@{$$New{'recommendations'}} = $self->recommendations();
	return $New;
} # end sub copy

sub prices {
	my $self = shift;
	if ( ! $$self{'Prices'} ) {
		@{$$self{'Prices'}} = openprint::PaperPrice::find( 'paper_id' => $$self{'id'}, 'pricelist_id'=>shift );
	} # end if
	return @{$$self{'Prices'}};
} # end sub prices

sub save {
	my ( $self, $hash ) = @_;

	if ( $hash ) {
		foreach my $key ( @fields ) {
			$$self{$key} = $$hash{$key} if exists $$hash{$key};
		} # end foreach
	} # end if
	
	if ( $$self{'group'} and ! $$self{'group_id'} ) {
		my $new_group = new openprint::StockGroup();
		if ( $_ = $new_group->save( {'name'=>$$self{'group'}} ) ) {
			return $_;
		} # end if
		$$self{'group_id'} = $new_group->id();
	} # end if name_id
	if ( $$self{'material'} and ! $$self{'material_id'} ) {
		my $new_material = new openprint::StockMaterial();
		if ( $_ = $new_material->save( {'name'=>$$self{'material'}} ) ) {
			return $_;
		} # end if
		$$self{'material_id'} = $new_material->id();
	} # end if material
	if ( $$self{'name'} and ! $$self{'name_id'} ) {
		sql::insert( undef, undef, 'PaperNames', [ 'shortname', $$self{'name'}, 'longname', $$self{'name'} ] );
		@$self{'name_id','name'} = sql::execute( undef, undef, q{SELECT id,longname FROM PaperNames WHERE longname=?}, $$self{'name'} );
	} # end if name_id
	if ( $$self{'finish'} and ! $$self{'finish_id'} ) {
		sql::insert( undef, undef, 'PaperFinishes', 'shortname', $$self{'finish'}, 'longname', $$self{'finish'} );
		@$self{'finish_id','finish'} = sql::execute( undef, undef, q{SELECT id,longname FROM PaperFinishes WHERE longname=?}, $$self{'finish'} );
	} # end if finish_id
	if ( $$self{'colour'} and ! $$self{'colour_id'} ) {
		sql::insert( undef, undef, 'PaperColours', 'shortname', $$self{'colour'}, 'longname', $$self{'colour'} );
		@$self{'colour_id','colour'} = sql::execute( undef, undef, q{SELECT id,longname FROM PaperColours WHERE longname=?}, $$self{'colour'} );
	} # end if colour_id
	if ( $$self{'weight'} and ! $$self{'weight_id'} ) {
		sql::insert( undef, undef, 'PaperWeights', 'shortname', $$self{'weight'}, 'longname', $$self{'weight'} );
		@$self{'weight_id','weight'} = sql::execute( undef, undef, q{SELECT id,longname FROM PaperWeights WHERE longname=?}, $$self{'weight'} );
	} # end if weight_id
	if ( $$self{'quality'} and ! $$self{'quality_id'} ) {
		sql::insert( undef, undef, 'PaperQualities', 'shortname', $$self{'quality'}, 'longname', $$self{'quality'} );
		@$self{'quality_id','quality'} = sql::execute( undef, undef, q{SELECT id,longname FROM PaperQualities WHERE longname=?}, $$self{'quality'} );
	} # end if quality_id
	if ( $$self{'manufacturer'} and ! $$self{'manufacturer_id'} ) {
		sql::insert( undef, undef, 'Manufacturers', 'shortname', $$self{'manufacturer'}, 'longname', $$self{'manufacturer'} );
		@$self{'manufacturer_id','manufacturer'} = sql::execute( undef, undef, q{SELECT id, longname FROM Manufacturers WHERE longname=?}, $$self{'manufacturer'} );
	} # end if manufacturer

	delete $$self{'in_stock'};
	$self->in_stock();

	foreach my $key ( @fields ) {
		$$self{$key} = undef if $$self{$key} eq '';
	} # end foreach
	$$self{'height'} = undef if $$self{'type'} eq 'Roll';
	
	my $error;
	$error .= 'An owner must be selected.<br/>' if ! $$self{'owner_id'};
	$error .= 'A manufacturer must be selected.<br/>' if ! $$self{'manufacturer_id'};

	return $error if $error;

	my %sql = map { $_, $$self{$_} } @fields;
	delete $sql{'created_on'};
	
	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('paper_id_seq')} );
		$sql{'id'} = $$self{'id'};

		$error = sql::insert( undef, undef, 'Papers', \%sql );

       # Add record to audit log - action "New Paper".
       openprint::logs::insertLogRecord('63', "Paper ID: " . $$self{'id'},);

		if ( ! $error ) {

			$variable{'Paper'} = $self;
			if ( my $email_template = misc::load_file( $openprint::log, $config{'SkinPath'} . '/email_template.html' ) ) {
				$variable{'ReplacementText'} = misc::load_file( $openprint::log, $ENV{'DOCUMENT_ROOT'} . '/email_content/new_paper_notification.html' );
				$variable{'ReplacementText'} = ssi::variable_substitution( \$variable{'ReplacementText'}, \%variable );
				my $body = ssi::variable_substitution( \$email_template, \%variable );
				my %mail = (
						SMTP    => $config{'Mail Server'},
						FROM    => $config{'InventoryEmail'},
						TO      => $config{'InventoryEmail'},
						SUBJECT => 'A new paper has been added to inventory',
						);
				#misc::send_email_with_attachment( $openprint::log, \%mail, ( '', encode_qp($body), 'text/html', 'quoted-printable' ) );
			} # end if
		} else {
			$$self{'id'} = undef;
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if

    } else {
        if ( $error = sql::update( undef, undef, 'Papers', ['id=?',$$self{'id'}], \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
       # Add record to audit log - action "Update Paper".
       openprint::logs::insertLogRecord('64', "Paper ID: " . $$self{'id'},);
    } # end if
    sql::execute( undef, undef, q{DELETE FROM PaperNames WHERE id NOT IN (SELECT DISTINCT name_id FROM Papers)} );
    sql::execute( undef, undef, q{DELETE FROM PaperFinishes WHERE id NOT IN (SELECT DISTINCT finish_id FROM Papers)} );
    sql::execute( undef, undef, q{DELETE FROM PaperColours WHERE id NOT IN (SELECT DISTINCT colour_id FROM Papers)} );
    sql::execute( undef, undef, q{DELETE FROM PaperWeights WHERE id NOT IN (SELECT DISTINCT weight_id FROM Papers)} );
    sql::execute( undef, undef, q{DELETE FROM StockGroups WHERE id NOT IN (SELECT DISTINCT group_id FROM Papers)} );
    sql::execute( undef, undef, q{DELETE FROM StockMaterials WHERE id NOT IN (SELECT DISTINCT material_id FROM Papers)} );

	my @recommendations = $self->recommendations();
    sql::execute( undef, undef, q{DELETE FROM Paper_Recommendations WHERE lngPaperIndex=?}, $$self{'id'} );
	foreach my $rec ( @recommendations ) {
		sql::insert( undef, undef, 'Paper_Recommendations', 'lngPaperIndex', $$self{'id'},'lngProjectTypeIndex', $rec );
	} # end foreach

	foreach my $Price ( $self->prices() ) {
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
	sql::update( undef, undef, 'manifest_content_types', [ 'paper_id=?', $Duplicate->id() ], 'paper_id', $self->id() );
	$Duplicate->delete();
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
    if ( ! sql::execute( undef, undef, q{SELECT DISTINCT name_id FROM Papers WHERE name_id=?}, $$self{'name_id'} ) ) {
        sql::execute( undef, undef, q{DELETE FROM PaperNames WHERE Id=?}, $$self{'name_id'} );
    } # end if
    if ( ! sql::execute( undef, undef, q{SELECT DISTINCT finish_id FROM Papers WHERE finish_id=?}, $$self{'finish_id'} ) ) {
        sql::execute( undef, undef, q{DELETE FROM PaperFinishes WHERE Id=?}, $$self{'finish_id'} );
    } # end if
    if ( ! sql::execute( undef, undef, q{SELECT DISTINCT colour_id FROM Papers WHERE colour_id=?}, $$self{'colour_id'} ) ) {
        sql::execute( undef, undef, q{DELETE FROM PaperColours WHERE Id=?}, $$self{'colour_id'} );
    } # end if
    if ( ! sql::execute( undef, undef, q{SELECT DISTINCT weight_id FROM Papers WHERE weight_id=?}, $$self{'weight_id'} ) ) {
        sql::execute( undef, undef, q{DELETE FROM PaperWeights WHERE Id=?}, $$self{'weight_id'} );
    } # end if
    if ( ! sql::execute( undef, undef, q{SELECT DISTINCT quality_id FROM Papers WHERE quality_id=?}, $$self{'quality_id'} ) ) {
        sql::execute( undef, undef, q{DELETE FROM PaperQualities WHERE Id=?}, $$self{'quality_id'} );
    } # end if
    sql::execute( undef, undef, q{DELETE FROM StockGroups WHERE id NOT IN (SELECT DISTINCT group_id FROM Papers)} );
    sql::execute( undef, undef, q{DELETE FROM StockMaterials WHERE id NOT IN (SELECT DISTINCT material_id FROM Papers)} );
    
    # Add record to audit log - action "Delete Paper".
    openprint::logs::insertLogRecord('15', "Paper ID: " . $$self{'id'},);
    sql::end_transaction( undef, $ac );
	
} # end sub delete

sub to_string {
	my $self = shift;
	if ( ! $$self{'to_string'} ) {
		my $string = join(' ', ( $self->manufacturer(), $self->name(), $self->finish(), $self->colour(), $self->weight() ) );
		if ( $self->type() eq 'Roll' ) {
			$string .= ' ' . $self->width.'"' if $self->width();
			$string .= ' Roll ';
		} else {
			if ( ( $self->width() != $self->start_width() ) or ( $self->height() != $self->start_height() ) ) {
				$string .= ' ' . $self->start_width().'x'.$self->start_height() . ' => '. $self->width().'x'.$self->height() . ' ';
			} else {
				$string .= ' ' . $self->width().'x'.$self->height() . ' ';
			} # end if
			$string .= $self->mweight().'M ' if $self->mweight();
		} # end if
		$string .= sprintf('%.1fPT ', 1000*$self->calliper()) if $self->calliper();
		$string .= $self->gsm().'gsm ' if $self->gsm();
		$string .= $self->quality() . ' ' if $self->quality();
		$string .= 'FSC:' . $$self{'fsc_code'} if $$self{'fsc_code'};
		$string .= 'Minimum: ' . $$self{'minimum_order'} if $$self{'minimum_order'};
		$$self{'to_string'} = $string;
	} # end if
	return $$self{'to_string'};
} # end sub to_string

sub material {
    my ( $self, $material ) = @_;

	if ( defined $material ) {
		$material =~ s/^\s*(.*)\s*$/$1/;

        @$self{'material_id','material'} = sql::execute( undef, undef, q{SELECT id, name FROM StockMaterials WHERE lower(name)=?}, lc $material );
        if ( ! $$self{'material_id'} ) {
			$$self{'material'} = $material;
        } # end if
    } elsif ( $$self{'material_id'} and ! $$self{'material'} ) {
        $$self{'material'} = new openprint::StockMaterial( $$self{'material_id'} )->name();
    } # end if
    return $$self{'material'};
} # end sub material

sub group {
    my ( $self, $group ) = @_;

	if ( defined $group ) {
		$group =~ s/^\s*(.*)\s*$/$1/;

		if ( ! $$self{'custom'} ) {
			@$self{'group_id','group'} = sql::execute( undef, undef, q{SELECT id, name FROM StockGroups WHERE lower(name)=?}, lc $group );
			if ( ! $$self{'group_id'} ) {
				$$self{'group'} = $group;
			} # end if
		} else {
			$$self{'group'} = $group;
        } # end if
    } elsif ( $$self{'group_id'} and ! $$self{'group'} ) {
        $$self{'group'} = new openprint::StockGroup( $$self{'group_id'} )->name();
    } # end if
    return $$self{'group'};
} # end sub group

sub Name {
	return openprint::StockName( $_[0]{'name_id'} );
}

sub name {
    my ( $self, $name ) = @_;

	if ( defined $name ) {
		$name =~ s/^\s+//;
		$name =~ s/\s+$//;
		$name =~ s/\s\s+$/ /;
		if ( ! $$self{'custom'} ) {
			@$self{'name_id','name'} = sql::execute( undef, undef, q{SELECT id, longname FROM PaperNames WHERE lower(longname)=?}, lc $name );
			if ( ! $$self{'name_id'} ) {
				$$self{'name'} = $name;
			} # end if
		} else {
			$$self{'name'} = $name;
        } # end if
    } elsif ( $$self{'name_id'} and ! $$self{'name'} ) {
        $$self{'name'} = new openprint::StockName( $$self{'name_id'} )->shortname();
    } # end if
    return $$self{'name'};
} # end sub name

sub Manufacturer {
	return openprint::Manufacturer( $_[0]{'manufacturer_id'} );
}
sub manufacturer {
    my ( $self, $manufacturer ) = @_;

    if ( defined $manufacturer ) {
		$manufacturer =~ s/^\s+//;
		$manufacturer =~ s/\s+$//;
		$manufacturer =~ s/\s\s+$/ /;
		if ( ! $$self{'custom'} ) {
			@$self{'manufacturer_id','manufacturer'} = sql::execute( undef, undef, q{SELECT id, longname FROM Manufacturers WHERE lower(longname)=?}, lc $manufacturer );
			if ( ! $$self{'manufacturer_id'} ) {
				$$self{'manufacturer'} = $manufacturer;
			} # end if
		} else {
			$$self{'manufacturer'} = $manufacturer;
        } # end if
    } elsif ( $$self{'manufacturer_id'} and ! $$self{'manufacturer'} ) {
        $$self{'manufacturer'} = new openprint::Manufacturer( $$self{'manufacturer_id'} )->shortname();
    } # end if
    return $$self{'manufacturer'};
} # end sub manufacturer

sub Finish {
	return openprint::StockFinish( $_[0]{'finish_id'} );
}
sub finish {
    my ( $self, $finish ) = @_;

    if ( defined $finish ) {
		$finish =~ s/^\s+//;
		$finish =~ s/\s+$//;
		$finish =~ s/\s\s+$/ /;
		if ( ! $$self{'custom'} ) {
			@$self{'finish_id','finish'} = sql::execute( undef, undef, q{SELECT id,longname FROM PaperFinishes WHERE lower(longname)=?}, lc $finish );
			if ( ! $$self{'finish_id'} ) {
				$$self{'finish'} = $finish;
			} # end if
		} else {
			$$self{'finish'} = $finish;
		} # end if
    } elsif ( $$self{'finish_id'} and ! $$self{'finish'} ) {
        $$self{'finish'} = new openprint::StockFinish( $$self{'finish_id'} )->shortname();
    } # end if
    return $$self{'finish'};
} # end sub finish

sub Colour {
	return openprint::StockColour( $_[0]{'colour_id'} );
}
sub colour {
    my ( $self, $colour ) = @_;

    if ( defined $colour ) {
		$colour =~ s/^\s+//;
		$colour =~ s/\s+$//;
		$colour =~ s/\s\s+$/ /;
		if ( ! $$self{'custom'} ) {
			@$self{'colour_id','colour'} = sql::execute( undef, undef, q{SELECT id,longname FROM PaperColours WHERE lower(longname)=?}, lc $colour );
			if ( ! $$self{'colour_id'} ) {
				$$self{'colour'} = $colour;
			} # end if
		} else {
			$$self{'colour'} = $colour;
        } # end if
    } elsif ( $$self{'colour_id'} and ! $$self{'colour'} ) {
        @$self{'colour'} = new openprint::StockColour( $$self{'colour_id'} )->shortname();
    } # end if
    return $$self{'colour'};
} # end sub colour

sub Weight {
	return openprint::StockWeight( $_[0]{'weight_id'} );
}
sub weight {
    my ( $self, $weight ) = @_;


    if ( defined $weight ) {
		$weight =~ s/^\s+//;
		$weight =~ s/\s+$//;
		$weight =~ s/\s\s+$/ /;
		if ( ! $$self{'custom'} ) {
			@$self{'weight_id','weight'} = sql::execute( undef, undef, q{SELECT id, longname FROM PaperWeights WHERE lower(longname)=?}, lc $weight );
			if ( ! $$self{'weight_id'} ) {
				$$self{'weight'} = $weight;
			} # end if
		} else {
			$$self{'weight'} = $weight;
        } # end if
    } elsif ( $$self{'weight_id'} and ! $$self{'weight'} ) {
        $$self{'weight'} = new openprint::StockWeight( $$self{'weight_id'} )->shortname();
    } # end if
    return $$self{'weight'};
} # end sub weight

sub quality {
    my ( $self, $quality ) = @_;

    if ( defined $quality ) {
		$quality =~ s/^\s+//;
		$quality =~ s/\s+$//;
		$quality =~ s/\s\s+$/ /;
		if ( ! $$self{'custom'} ) {
			@$self{'quality_id','quality'} = sql::execute( undef, undef, q{SELECT id, longname FROM PaperQualities WHERE lower(longname)=?}, lc $quality );
			if ( ! $$self{'quality_id'} ) {
				$$self{'quality'} = $quality;
			} # end if
		} else {
			$$self{'quality'} = $quality;
        } # end if
    } elsif ( $$self{'quality_id'} and ! $$self{'quality'} ) {
        $$self{'quality'} = new openprint::StockQuality( $$self{'quality_id'} )->longname();
    } # end if
    return $$self{'quality'};
} # end sub quality

sub width {
    my ( $self, $width ) = @_;
    if ( defined $width ) {
        $width =~ s/[^\d\.]//g;
        $$self{'width'} = $width;
		delete $$self{'to_string'};
    } # end if
    return $$self{'width'};
} # end if
sub height {
    my ( $self, $height ) = @_;
    if ( defined $height ) {
        $height =~ s/[^\d\.]//g;
        $$self{'height'} = $height;
		delete $$self{'to_string'};
    } # end if
    return $$self{'height'};
} # end if

sub mweight {
    my ( $self, $mweight ) = @_;
    if ( defined $mweight ) {
        $mweight =~ s/[^\d\.]//g;
        $$self{'mweight'} = 1*$mweight;
	} # end if
	if ( ! $$self{'mweight'} ) {
		if ( $$self{'gsm'} ) {
			my $wpsi = $$self{'gsm'}/703064.5;
			if ( $$self{'type'} eq 'Roll' and $$self{'basis_width'} and $$self{'basis_height'} ) {
				$$self{'mweight'} = sprintf('%.2f', $wpsi * $$self{'basis_width'} * $$self{'basis_height'} * 1000 );
				# MWeight is in relaion to the basis size
			} elsif ( $$self{'width'} and $$self{'height'} ) {
				$$self{'mweight'} = sprintf('%.2f', $wpsi * $$self{'width'} * $$self{'height'} * 1000 );
			} # end if
		} elsif ( ($self->weight() =~ /(\d+)lb/) or ($self->weight() =~ /(\d+)lbs/) ) {
			$$self{'mweight'} = sprintf('%.0f', ($1*$$self{'width'}*$$self{'height'})/(25*38));
		} elsif ( ! $self->weight() =~ /\D/ ) {
			# weigiht of 500sheets of 25x38
#$openprint::log->debug("Auto calcing mweight from " . $self->weight() );
			$$self{'mweight'} = sprintf('%.0f', ($self->weight()*$$self{'width'}*$$self{'height'})/(25*38));
		} # end if
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
		my @Companies = openprint::Company::find('name'=>$_[0]);
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
    my ( $self, $Skid, $quantity, $units, $description ) = @_;
    $quantity =~ s/[^\-\d]//g;
    $quantity = int $quantity;

	if ( ref $Skid ne 'openprint::Skid' ) {
		$Skid = new openprint::Skid( $Skid );
		$openprint::log->debug('Please update call to add_inventory to pass a Skid instead of skid_id');
	} # end if
	my $C = $Skid->Content( $self );

# force recalc;
	delete $$self{'in_stock'};

	my $docket;
	if ( $description =~ /docket (\d+)/ ) {
		$docket = $1;
	} # end if

	$units = $self->units() if ! $units;
	new openprint::PaperInventory()->save({
			'paper_id'		=> $$self{'id'},
			'user_id'		=> $openprint::session{'user_id'},
			'poindex'		=> undef,
			'instock'		=> $self->in_stock() + $quantity,
			'delta'			=> $quantity,
			'comment'		=> $description,
			'skid_id'		=> $Skid->id(),
			'units'			=> $units,
			'docket'		=> $docket,
			} );

	delete $$self{allocated};
	# Updates in_stock
	$self->save();

} # end sub add_inventory

sub allocate {
    my ( $self, $skid_id, $project_id, $quantity, $units, $reason ) = @_;

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
			'paper_id'		=>	$$self{'id'},
			'skid_ids'		=>	$skids,
			'quantity'		=>	$quantity,
			'units'			=>	$units ? $units : $self->units(),
			'project_id'	=>	$project_id,
			'operator_id'	=>	$openprint::session{'user_id'},
			} );
	if ( $project_id ) {
		new openprint::Project( $project_id )->add_to_log( @openprint::session{'company_id','user_id'}, 
				qq`Allocated $quantity$$PA{units} of <a href="/employee/inventory/paper_details.html?paper_id=$$self{'id'}">` . $self->to_string()
				);
	} # end if project_id

	delete $$self{allocated};
	delete $$self{available};
	return $PA;
} # end sub allocate

sub back_ordered {
    my $self = shift;
	return 0 if ! $$self{'id'};

    return 0;
} # end sub back_ordered

sub allocated {
    my ( $self, $project_id, $new ) = @_;
	return 0 if ! $$self{'id'};
	if ( @_ == 3 ) {
		if ( defined $new ) {
			$$self{allocated} = $new;
		} else {
			delete $$self{allocated};
		} # end if
	} # end if
	if ( $project_id ) {
		( $_ ) = sql::execute( undef, undef, q{SELECT SUM(Quantity) FROM Paper_Allocations WHERE paper_id=? and project_id=?}, $$self{'id'}, $project_id );
		return $_;
	} # end if
	if ( ! exists $$self{allocated} ) {
		@$self{allocated} = sql::execute( undef, undef, q{SELECT SUM(Quantity) FROM Paper_Allocations WHERE paper_id=?}, $$self{'id'} );
	} # end if
    return $$self{allocated};
} # end sub allocated

sub in_stock {
    my $self = shift;
	return 0 if ! $$self{'id'};

	if ( ! exists $$self{in_stock} ) {
		foreach my $SkidContent ( openprint::SkidContent::find('paper_id'=>$$self{'id'},'quantity_>'=>0) ) {
			next if $SkidContent->Skid()->Location()->name() eq 'Missing';
			$$self{in_stock} += $SkidContent->quantity();
		} # end foreach SkidContent
	} # end if
    return 1*$$self{in_stock};
} # end sub in_stock

sub available {
    my $self = shift;
	if ( @_ ) {
		if ( defined $_[0] ) {
		$$self{'available'} = $_[0];
		} else {
			delete $$self{'available'};
		} # end if
	} # end if
	return 0 if ! $$self{'id'};

	if ( ! exists $$self{available} ) {
		$$self{available} = 0;
		foreach my $SkidContent ( openprint::SkidContent::find('paper_id'=>$$self{'id'},'quantity_>'=>0) ) {
			next if $SkidContent->Skid()->Location()->name() eq 'Missing';
			@$self{available} += int $SkidContent->quantity();
		} # end foreach SkidContent
		$$self{'available'} -= $self->allocated();
	} # end if
    return $$self{available};
} # end sub available

sub skids {
    my $self = shift;
	return 0 if ! $$self{'id'};
	return openprint::Skid::find('paper_id'=>$$self{'id'}, 'quantity_>='=>1);
    #return map { new openprint::Skid( $_ ) } sql::execute( undef, undef, q{SELECT skid_id FROM skid_contents WHERE paper_id=? and quantity > 0}, $$self{'id'} );
} # end sub skids

sub previous {
    my $self = shift;
	my @papers = find( 'order'=>'name,finish,colour,weight,width,height' );
	for ( my $i = 0; $i < @papers; $i += 1 ) {
		return $papers[$i-1] if ($papers[$i] == $self )and ($i > 0);
    } # end if
    return $self;
} # end sub previous
sub next {
    my $self = shift;
	my @papers = find( 'order'=>'name,finish,colour,weight,width,height' );
	for ( my $i = 0; $i < @papers; $i += 1 ) {
		return $papers[$i+1] if ($papers[$i] == $self )and ($i < @papers);
    } # end if
    return $self;
} # end sub next

sub recommendations {
	my $self = shift;
	if ( @_ ) {
		@{$$self{'recommendations'}} = @_;
	} elsif ( ! exists $$self{'recommendations'} ) {
		@{$$self{'recommendations'}} = sql::execute( undef, undef, q{SELECT lngProjectTypeIndex FROM paper_recommendations WHERE lngPaperIndex=?}, $$self{'id'} );
	} # end if
	return @{$$self{'recommendations'}};
} # end sub recommendations

# From now on, qty is always weight
sub get_price {
	my ( $self, $qty ) = @_;
    my %price;

    if ( $$self{'Price'} ) {
		# If custom paper
		%price = ( 'Price' => $$self{'Price'}, 'Cost'=>$$self{'Price'}, 'units'=>$$self{'Units'});
#$openprint::log->debug("Usnig custom price $$self{'Price'}$$self{'Units'}");
	} elsif ( $$self{'id'} ) {
		my $list_id = openprint::pricing::get_pricelist_id( );
		my $bestPrice;
		my @Prices = $self->prices( $list_id );
		if ( (! $$self{'supplied'} ) and ! @Prices ) {
			$openprint::log->warn( 'No prices for paper for pricelist ' . $list_id );
			return %price;
		} # end if
		foreach my $Price ( @Prices ) {
#$openprint::log->warn(sprintf('Price: %s - %s : %s',$Price->Min(), $Price->Max(), $Price->Price() ) );
			if ( 
					( (!(1*$Price->Min())) or $Price->Min() <= $qty ) and
					( (!(1*$Price->Max())) or $Price->Max() >= $qty )
			   ) {
				$bestPrice = $Price;
				last;
			} # end if
		} # end foreach Price
		if ( ! $bestPrice ) {
			$openprint::log->warn("Unable to find price for $qty");
			return;
		} # end if
		$price{'Price'} = $bestPrice->Price();
		$price{'units'} = $bestPrice->Units();
		if ( $openprint::config{'ApplyMarkup'} ) {
		#$openprint::log->debug("Apply Markup: $openprint::config{'ApplyMarkup'}");	
			my $pricingpercent = $openprint::config{'ApplyMarkup'};
			$pricingpercent =~ s/[^\d\.\-]//g;
			$pricingpercent /= 100;
			$price{'Price'} *= ( 1 + $pricingpercent );
		} # end if

		my $Pricelist = new openprint::Pricelist( $list_id );
		$price{'currency_id'} = $Pricelist->currency_id();
		openprint::Currency::convert( \%price );
	} else {
		$openprint::log->error("No custom price, and no paper::id");
	} # end if

	my $Company = new openprint::Company( $openprint::session{company_id} );
	if ( $Company->discount() ) {
		$price{'Price'} *= 1 - ( $Company->discount()/100 );
	} # end if

# Don't need to cut it because the mweight has already byeen cut
	$price{'mweight'} = $self->mweight();
	# Prices are always stored in cwt now
	if ( ! $$self{'mweight'} ) {
		# ROll papers won't have an mweight
		$price{'100lb'} = $price{'Price'};
		$price{'100lb Cost'} = $price{'Cost'};
		$price{'100lb Price'} = $price{'Price'};
		#$price{'Cost'} *= $$self{'wpsi'} * $self->width() * $self->height();
		#$price{'Price'} *= $$self{'wpsi'} * $self->width() * $self->height();
	} else {
		$price{'100lb'} = $price{'Price'};
		$price{'100lb Cost'} = $price{'Cost'};
		$price{'100lb Price'} = $price{'Price'};
		#$price{'Cost'} *= $$self{'mweight'} / 100000;
		#$price{'Price'} *= $$self{'mweight'} / 100000;
	} # end if
	$price{'100lb Total'} = $price{'100lb Price'} * $qty/100;
#$openprint::log->debug("Costs: ($price{Cost}) ($price{'100lb'})/100lb ($price{'100lb Cost'}) ($price{'Price'})") if $debug;
	return %price;

} # end sub get_price


sub cut {
    my $self = shift;

    if ( $$self{'height'} > $$self{'width'} ) {
        $$self{'height'} /= 2;
    } else {
        $$self{'width'} /= 2;
    } # end if
    $$self{'mweight'} /= 2;
	delete $$self{'to_string'};
	$$self{'grain_direction'} = undef; # force recalc of gd
} # end sub cut

sub minimum_order {
	my $self = shift;
	if ( @_ ) {
		$$self{'minimum_order'} = shift;
	} # end if

	my $factor = int($$self{'start_width'} / $$self{'width'} ) * int( $$self{'start_height'} / $$self{'height'} ) if $$self{'width'} and $$self{'height'};
#$openprint::log->debug("SPP: $$self{'start_width'} / $$self{'width'} ) * int( $$self{'start_height'} / $$self{'height'} * spp $$self{'sheets_per_package'} * $factor;");
	return $$self{'minimum_order'} * $factor if $factor;
	return $$self{'minimum_order'};
} # end minimum_order 
sub minimum_order_weight {
	my $self = $_[0];
	if ( $$self{'type'} eq 'Sheet' ) {
		return $self->minimum_order() * $self->sheet_weight();
	} # end if
	return $self->minimum_order();
} # end sub minimum_order_weight

sub sheets_per_package {
	my $self = shift;
	if ( @_ ) {
		$$self{sheets_per_package} = shift;
	} # end if

	my $factor = int($$self{'start_width'} / $$self{'width'} ) * int( $$self{'start_height'} / $$self{'height'} ) if $$self{'width'} and $$self{'height'};
#$openprint::log->debug("SPP: $$self{'start_width'} / $$self{'width'} ) * int( $$self{'start_height'} / $$self{'height'} * spp $$self{'sheets_per_package'} * $factor;");
	return $$self{'sheets_per_package'} * $factor if $factor;
	return $$self{'sheets_per_package'};
} # end sheets_per_package
	
sub gsm {
	my $self = shift;
	if ( @_ ) {
		$$self{'gsm'} = shift;
	} elsif ( ! $$self{'gsm'} ) {
		if ( $self->wpsi() ) {
			$$self{'gsm'} = sprintf('%.2f', $$self{'wpsi'} * 703064.5 );
		} else { 
			$openprint::log->warn("Can't calculate gsm");
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
		if ( $$self{'gsm'} ) {
			$$self{'wpsi'} = $$self{'gsm'} / 703064.5;
		} elsif ( ( $$self{'type'} eq 'Sheet' ) and $$self{'width'} and $$self{'height'} ) {
			$$self{'wpsi'} = ($$self{'mweight'} / 1000)/($$self{'width'}*$$self{'height'});
		} elsif ( $self->basis_mweight() ) {
			$$self{'wpsi'} = ($$self{'basis_mweight'}/1000)/($self->basis_width()*$self->basis_height());
		} # end if
	} # end if
	return $$self{'wpsi'};
} # end if wpsi

sub Prices {
	my $self = shift;
	return openprint::PaperPrice::find('paper_id'=>$$self{'id'}, @_ );
} # end sub Prices

sub JDF_Media {
	my ( $self, $doc ) = @_;

	my $Paper = $doc->createElement('Media');
	$Paper->setAttribute('Status','Available');
	$Paper->setAttribute('MediaType','Paper');
	$Paper->setAttribute('MediaUnit', $self->type() );
	$Paper->setAttribute('Brand',$self->name() );
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
	$Paper->setAttribute('Thickness', int(Math::Units::convert($$self{'calliper'},'in','microns') ));
	$Paper->setAttribute('Weight', .99*int $self->gsm() );

	return $Paper;	
} # end sub jdf

sub JDF_MediaIntent {
	my ( $self, $doc, $sig_index ) = @_;

	my $Paper = $doc->createElement('MediaIntent');
	$Paper->setAttribute('Status','Available');
	#$Paper->setAttribute('MediaUnit', $self->type() eq 'Roll' ? '' : 'Sheet' );
	#$Paper->setAttribute('Brand',$self->name() );
	$Paper->setAttribute('Class', 'Intent' );
	$Paper->setAttribute('Locked', 'false' );
	$Paper->setAttribute('DescriptiveName',$self->to_string() );
	$Paper->setAttribute('ProductID',$self->id() );
	#$Paper->setAttribute('Type', 'ConventionalPrinting' );
	$Paper->setAttribute('ID', 'Paper'.$sig_index );
	#$Paper->setAttribute( 'Dimensions',join(' ',
				#Math::Units::convert($$self{'width'},'in','mm'),
				#Math::Units::convert($$self{'height'},'in','mm'),
#) );

	my $MediaType = $Paper->appendChild( $doc->createElement( 'MediaType' ) );
	$MediaType->setAttribute('DataType','EnumerationSpan');
	$MediaType->setAttribute('Preferred','Paper');

	my $Grade = $Paper->appendChild( $doc->createElement( 'Grade' ) );
	$Grade->setAttribute('DataType','IntegerSpan');
	$Grade->setAttribute('Preferred','1');

	my $Weight = $Paper->appendChild( $doc->createElement( 'Weight' ) );
	$Weight->setAttribute('DataType','NumberSpan');
	$Weight->setAttribute('Preferred', Math::Units::convert($$self{'mweight'}/1000,'lb','g' ) );

	my $Thickness = $Paper->appendChild( $doc->createElement( 'Thickness' ) );
	$Thickness->setAttribute('DataType','NumberSpan');
	$Thickness->setAttribute('Preferred', Math::Units::convert($$self{'calliper'},'in','mm') );

	my $GrainDirection = $Paper->appendChild( $doc->createElement( 'GrainDirection' ) );
	$GrainDirection->setAttribute('DataType','EnumerationSpan');
	$GrainDirection->setAttribute('Preferred', 'LongEdge' );

	my $MediaColor = $Paper->appendChild( $doc->createElement( 'MediaColor' ) );
	$MediaColor->setAttribute('DataType','EnumerationSpan');
	$MediaColor->setAttribute('Preferred',$self->colour() );

	my $MediaBrand = $Paper->appendChild( $doc->createElement( 'StockBrand' ) );
	$MediaBrand->setAttribute('DataType','StringSpan');
	$MediaBrand->setAttribute('Preferred',$self->name() );

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
		$Paper->name( $$specs{'txtSpecificStockBrand'} );
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

		$Paper->Price( $$specs{'CustomStockPrice'} );
		$Paper->Units( $$specs{'CustomStockPriceUnits'} );
		$Paper->basis_width( $$specs{'basis_width'} );
		$Paper->basis_height( $$specs{'basis_height'} );
		$Paper->basis_mweight( $$specs{'basis_mweight'} );
		$Paper->score_required( $Paper->calliper() > 0.008 );
		#if ( $$specs{'StockType'} ne 'Roll' ) {
			$Paper->mweight( $$specs{'txtCustomMWeight'} );
		#} # end if
		$Paper->supplied( $$specs{'rdbSuppliedStock'} eq 'Y' ? 1 : 0 );
	} else {
		if ( $qty_index and $$specs{'paper_id'.$qty_index} ) {
			$Paper = new openprint::Paper( $$specs{'paper_id'.$qty_index} );
			$Paper = $Paper->id() ? $Paper : undef;
		} elsif ( ! ( $$specs{'ddmStockBrand'} and $$specs{'ddmStockFinish'} and $$specs{'ddmStockColour'} and $$specs{'ddmStockWeight'} ) ) {
			return new openprint::Paper();
		} # end if

		if ( ! $Paper ) {
			my %params = (
					'supplied'	=> $$specs{'rdbSuppliedStock'},
					'name'      => $$specs{'ddmStockBrand'},
					'finish'    => $$specs{'ddmStockFinish'},
					'colour'    => $$specs{'ddmStockColour'},
					'weight'    => $$specs{'ddmStockWeight'},
					'project_type_id'=> $Project ? $Project->type_id() : undef,
					'order'		=>	'minimum_order',
					);
			if ( $qty_index ) {
				$params{'width'} = $$specs{'hdnSuppliedStockWidth'.$qty_index};
				$params{'height'} = $$specs{'hdnSuppliedStockHeight'.$qty_index};
				$params{'type'}	= $$specs{'StockType'.$qty_index};
			} # end if
			my @Papers = find( %params );
			if ( ! @Papers ) {
#$log->debug("Didn't find specific paper $params{'width'}x$params{'height'}");
				delete $params{'width'};
				delete $params{'height'};
				@Papers = find( %params );
			} elsif ( @Papers > 1 ) {
				Carp::cluck("More than 1 paper found in load_from_signature");
			} # end if
#$log->debug("Found " . @Papers );
			if ( ! @Papers ) {
				$openprint::log->warn("No papers found");
				$Paper = new openprint::Paper();
				$Paper->name( $$specs{'ddmStockBrand'} );
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

				$Paper->Price( $$specs{'CustomStockPrice'} );
				$Paper->Units( $$specs{'CustomStockPriceUnits'} );
				$Paper->basis_width( $$specs{'basis_width'} );
				$Paper->basis_height( $$specs{'basis_height'} );
				$Paper->basis_mweight( $$specs{'basis_mweight'} );
				$Paper->score_required( $Paper->calliper() > 0.008 );
				$Paper->mweight( $$specs{'txtMWeight'.$qty_index} );
				@Papers = ( $Paper );
			} # end if

			foreach my $P ( @Papers ) {
				next if $$specs{'StockQuantity'.$qty_index} < $P->minimum_order();
				$Paper = $P;
				last;
			} # end foreach
			if ( ( ! $Paper ) and @Papers ) {
#$log->debug("No paper found matching minimum_order ($$specs{'StockQuantity'.$qty_index})");
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
	if ( $qty_index ) {
		if ( $Paper->width() != $$specs{'StockWidth'.$qty_index} or $Paper->height() != $$specs{'StockHeight'.$qty_index} ) {
$log->debug("Custom size $$specs{'StockWidth'.$qty_index}x$$specs{'StockHeight'.$qty_index}");
			$Paper->width( $$specs{'StockWidth'.$qty_index} );
			$Paper->start_width( $Paper->width() ) if ! $Paper->start_width();
			$Paper->height( $$specs{'StockHeight'.$qty_index} ) if $Paper->type() ne 'Roll';
			$Paper->mweight($Paper->mweight()/( ($Paper->start_width()/$Paper->width())*($Paper->start_height()/$Paper->height()))) if $Paper->start_width() and $Paper->start_height() and $Paper->width() and $Paper->height(); # force recalc
		} # end if
	} # end if
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
		if ( $self->name() =~ /cover/i ) {
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
		if ( $self->name() =~ /cover/i ) {
			$$self{'basis_height'} = 26;
		} else {
			$$self{'basis_height'} = 38;
		} # end if
	} # end if
	return $$self{'basis_height'};
} # end sub basis_height

sub sheet_weight {
	my ( $self ) = @_;
	return $$self{'width'} * $$self{'height'} * $self->wpsi();
} # end sub sheet_weight

sub start_sheet_weight {
	my ( $self ) = @_;
	return $$self{'start_width'} * $$self{'start_height'} * $self->wpsi();
} # end sub start_sheet_weight

sub units {
	return $_[0]{'type'} eq 'Roll' ? 'lbs' : 'sheets';
} # end sub units

sub Supplied {
	my ( $self ) = @_;
	my $Supplied = $self->clone();
	$$Supplied{'width'} = $$Supplied{'start_width'} if $$Supplied{'start_width'};
	$$Supplied{'height'} = $$Supplied{'start_height'} if $$Supplied{'start_height'};
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

1;
__END__
