package openprint::service;

use strict;

require openprint::Equipment;
require openprint::pricing;
require openprint::project;

require openprint::Estimating::Cutting;
require openprint::Estimating::Folding;
require openprint::Estimating::Proofs;
require openprint::Estimating::Scoring;
require openprint::Estimating::Drilling;
require openprint::Estimating::Scanning;
require openprint::Estimating::Prepress;
require openprint::Estimating::Stitching;
require openprint::Estimating::Packaging;
require openprint::Estimating::Skids;
require openprint::Estimating::Lamination;
require openprint::Estimating::Collating;
require openprint::Estimating::Gluing;
require openprint::Estimating::PerfectBound;
require openprint::Estimating::Printing;
require openprint::Estimating::Shipping;
require openprint::Estimating::Spiral;
require openprint::Estimating::UPS;
require openprint::Estimating::Multipage;
require openprint::logs;

my $debug = 0;

my %cache_index_by_id;
my %cache_id_by_index;
my %specs_cache;

sub init_cache {
	%cache_index_by_id = ();
	%cache_id_by_index = ();
	%specs_cache = ();
} # end sub init_cache

sub get_index_by_id {
	my ( $id ) = @_;
	if ( ! %cache_index_by_id ) {
		%cache_index_by_id = map { $_->name(), $_->id() } openprint::Service::find();
	} # end if
	return $cache_index_by_id{$id};
} # end sub get_index_by_id

sub get_id_by_index {
	my ( $log, $dbh, $index ) = @_;

	if ( ! %cache_id_by_index ) {
		%cache_id_by_index = map { $_->id(), $_->name() } openprint::Service::find();
	} # end if

	return $cache_id_by_index{$index};
} # end sub get_id_by_index

sub get_price {
	my ( $log, $dbh, $variable, $service, $range, $equipment ) = @_;

	my %price = get_price_object( $log, $dbh, $variable, $service, $range, $equipment );
	return $price{'Price'};
} # end sub get_price

sub get_price_object {
	my ( $log, $dbh, $variable, $service, $range, $equipment ) = @_;

	my $index = get_index_by_id( $service );
	return if ! $index;

	if ( ref $equipment eq 'openprint::Equipment' ) {
		$equipment = $equipment->id();
	} # end if

	my $list_id = openprint::pricing::get_pricelist_id( $log, $dbh, $variable );
	my %price = openprint::pricing::get_best_price_object( $log, $dbh, $openprint::session{'company_id'}, $index, $list_id, 'openprint::service_priceset', $range, $equipment );
	return if ! %price;

	my $Pricelist = new openprint::Pricelist( $list_id );
	$price{'currency_id'} = $Pricelist->currency_id();
	openprint::Currency::convert( \%price );
	return %price;

} # end sub get_price_object

sub save_service {
	my ( $r, $log, $dbh, $project_index, $service_index ) = @_;

	$log->debug("***** START OF  save_service ************");
	if ( ! exists $specs_cache{$service_index} ) {
		%{$specs_cache{$service_index}} = sql::execute( $log, $dbh, 
				'SELECT strName, strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index );
	} # end if
	my $specs = $specs_cache{$service_index};

	my $service_type = $$specs{'ServiceType'};
	if ( ! $service_type ) {
		$service_type = $openprint::param{'ServiceType'};
	} # end if
	if ( (! $service_type) and (! $$specs{'ProjectType'}) ) {
		$log->error( "No serviceType in params for service $service_index.  Trying to recover" );
	} # end if
	if ( sets::isin( $service_type, ['SaddleStitching', 'LoopStitching'] ) ) {
		$service_type = 'Stitching';
	} elsif ( sets::isin( $service_type, [ '', 'AdditionalSignature' ] ) ) {
		$service_type = 'Printing';
	} elsif ( sets::isin( $service_type, ['KraftWrap','ShrinkWrap','Bundling','Bundle'] ) ) {
		$service_type = 'Packaging';
	} elsif ( sets::isin( $service_type, ['BulkSkids','PlainCartons'] ) ) {
		$service_type = 'Skids';
	} elsif ( sets::isin( $service_type, ( 'PhotoRetouching', 'ColourCorrection', 'PhotoPlacement', 'CDBurning' ) ) ) {
		$service_type = 'Prepress';
	} # end if
	eval ( 'require openprint::Estimating::'.$service_type.';' );
	my @variables = eval( 'openprint::Estimating::'.$service_type.'::variables( $project_index, $service_index, $specs )');
	$log->error($@) if $@;
	# make this fast by doing it in one transaction
	my $ac = sql::start_transaction( $dbh );
	foreach my $key (@variables) {
#$log->debug("Key: $key ($openprint::param{$key}) ( $$specs{$key})");
		if ( ref $openprint::param{$key} eq 'ARRAY' ) {
#$log->error("Key: $key ($openprint::param{$key}) ( $$specs{$key})");
		} elsif ( ! exists $openprint::param{$key} ) {
			delete_service_spec( $project_index, $service_index, $key );
		} else {
			insert_service_spec( $log, $dbh, $project_index, $service_index, $key, $openprint::param{$key}, 0 );
		} # end if
	} # end foreach
	sql::end_transaction( $dbh, $ac );

	$log->debug("***** END  OF  save_service ************");
} # end sub save_service

sub get_specifications {
	my ( $log, $dbh, $project_index, $service_index, @specs ) = @_;
	if ( ! ( $project_index or $service_index ) ) {
		$log->warn(" ***** get_specifications requested without Project or Service Index *********");
		return;
	} # end if

	if ( ! exists $specs_cache{$service_index} ) {
		%{$specs_cache{$service_index}} = sql::execute( $log, $dbh, 
				'SELECT strName, strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index );
	} # end if

	my @return_array = ();
	foreach my $spec ( @specs ) {
		push @return_array, $specs_cache{$service_index}{$spec};
	} # end foreach

	return @return_array;
} # end sub get_specifications

sub get_specifications_pairs {
	my ( $log, $dbh, $project_index, $service_index, @specs ) = @_;

	if ( ! $project_index and ! $service_index ) {
		$log->error("********* Called get_specifications_pairs with Project Index or Service Index ****************");
		return;
	} # end if

	if ( ! exists $specs_cache{$service_index} ) {
		%{$specs_cache{$service_index}} = sql::execute( $log, $dbh, 
				'SELECT strName, strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index );
	} # end if

	if ( @specs ) {
		my %results;
		@results{@specs} = @{$specs_cache{$service_index}}{@specs};
		return %results;
	} # end if
	return %{$specs_cache{$service_index}};
} # end sub get_specifications_pairs

sub get_specs_ref {
	my ( $p_id, $s_id ) = @_;
	if ( (! $p_id ) or (! $s_id) ) {
		$openprint::log->error("********* Called get_specs_ref with Project Index or Service Index ****************");
		return;
	} # end if
	if ( ref $p_id eq 'openprint::Project' ) {
		$p_id = $p_id->id();
	} # end if
	if ( ! exists $specs_cache{$s_id} ) {
		%{$specs_cache{$s_id}} = sql::execute( undef, undef, 
				'SELECT strName, strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?', $p_id, $s_id );
	} # end if
	return $specs_cache{$s_id};
} # end sub get_specs_ref

sub delete_service_spec {
	my ( $project_index, $service_index, $name ) = @_;

	if ( ! exists $specs_cache{$service_index} ) {
		%{$specs_cache{$service_index}} = sql::execute( undef, undef, 
				'SELECT strName, strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index );
	} # end if

	if ( exists $specs_cache{$service_index}{$name} ) {
		sql::execute( undef, undef, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?}, @_ );
		delete $specs_cache{$service_index}{$name};
	} # end if
} # end sub delete_service_spec

sub insert_service_spec {
	my ( $log, $dbh, $project_index, $service_index, $name, $value, $noDelete ) = @_;

	if ( ! exists $specs_cache{$service_index} ) {
		%{$specs_cache{$service_index}} = sql::execute( $log, $dbh, 
				'SELECT strName, strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index );
	} # end if
	return if $specs_cache{$service_index}{$name} eq $value;

	#if ( exists $specs_cache{$service_index}{$name} ) {
		#sql::update( $log, $dbh, 'tbl_Service_Specifications', ['lngProjectIndex=? AND lngServiceIndex=? AND strName=?',$project_index, $service_index, $name],
				#'strValue',			$value );
	#} else {
		if ( ! $noDelete ) {
			$_ = q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?};
			sql::execute( $log, $dbh, $_, $project_index, $service_index, $name );
		} # end if
		sql::insert( $log, $dbh, 'tbl_Service_Specifications', [
					'lngProjectIndex',	$project_index,
					'lngServiceIndex',	$service_index,
					'strName',			$name,
					'strValue',			$value] );
	#} # end if
	$specs_cache{$service_index}{$name} = $value;
} # end sub

sub insert_service_specs {
	my ( $log, $dbh, $project_index, $service_index, @specs ) = @_;

# make this fast by doing it in one transaction
	my $ac = sql::start_transaction( $openprint::dbh );
	while ( @specs ) {
		insert_service_spec( $log, $dbh, $project_index, $service_index, shift @specs, shift @specs );
	} # end while
	sql::end_transaction( $openprint::dbh, $ac );
} # end sub

sub auto_calculate {
	my ( $r, $log, $dbh, $variable, $project_index ) = @_;

	my $alert;
	my $specs;
	my $Project = new openprint::Project( $project_index );

# Need these.  If it's a book, then we get printing service + signatures, else just printing service
	my @signature_indices = $Project->signatures();
	return if ! scalar @signature_indices;

	# If the printing services aren't complete, then there is no sense continuing
	my @statuses = sql::execute( $log, $dbh, q{SELECT DISTINCT strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex IN (}.join(',', @signature_indices).q{)}, $project_index );
	return if sets::isin( 'uncalculated', \@statuses );
	my %services = $Project->get_services();

# Folding - first find out if we need it, and make sure we have it or don't as neccessary
	my $folding_service_index = $services{'Folding'}[0] if $services{'Folding'};
	if ( ! openprint::Estimating::Folding::neccessary( $log, $dbh, $project_index ) ) {
	} else {
		if ( ! $services{'Folding'} ) {
			if ( $Project->mode() ne 'Detailed' ) {
				push @{$services{'Folding'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Folding' );
			} # end if
		} # end if
	} # end if

	if ( openprint::Estimating::Paper::neccessary( $log, $dbh, $project_index ) ) {
		if ( ! $services{'Paper'} ) {
			push @{$services{'Paper'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Paper' );
		} # end if
	} # end if

	if ( openprint::Estimating::Cutting::neccessary( $log, $dbh, $project_index ) ) {
		if ( ! $services{'Cutting'} ) {
			if ( $Project->mode() ne 'Detailed' ) { 
				push @{$services{'Cutting'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Cutting' );
			} # end if
		} # end if
	} # end if

	if ( openprint::Estimating::PerfectBound::neccessary( $log, $dbh, $project_index ) ) {
		if ( ! $services{'PerfectBound'} ) {
			push @{$services{'PerfectBound'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'PerfectBound' );
		} # end if
	} elsif ( $services{'PerfectBound'} ) {
		while ( my $si = shift @{$services{'PerfectBound'}} ) {
			openprint::print_project::delete_service( $log, $dbh, $project_index, $si );
		} # end while
	} # end if

	if ( openprint::Estimating::Stitching::neccessary( $log, $dbh, $project_index ) ) {
		if ( ! $services{'SaddleStitching'} ) {
			push @{$services{'SaddleStitching'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'SaddleStitching' );
		} # end if
	} # end if
	if ( openprint::Estimating::Collating::neccessary( $log, $dbh, $project_index ) ) {
		if ( ! $services{'Collating'} ) {
			push @{$services{'Collating'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Collating' );
		} # end if
	} else {
		if ( ! $services{'Collating'} ) {
			foreach my $si ( @{$services{'Collating'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $project_index, $si );
			} # end foreach
		} # end if
	} # end if

# Proofs
	if ( ! $services{'Proofs'} ) {
		push @{$services{'Proofs'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Proofs' );
	} # end if

	foreach my $si ( @{$services{'Proofs'}} ) {
		if ( $openprint::config{'Insert Default Proofs'} eq 'Y' ) {
			openprint::Estimating::Proofs::insert_proof_defaults( $log, $dbh, $project_index, $si );
		} # end if
	} # end foreach

	if ( ! $services{'BulkSkids'} ) {
		if ( openprint::Estimating::Skids::neccessary( $Project ) ) {
			push @{$services{'BulkSkids'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'BulkSkids' );
		} # end if
	} # end if

	if ( ! $services{'Scoring'} ) {
		if ( openprint::Estimating::Scoring::neccessary( $Project ) ) {
			push @{$services{'Scoring'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Scoring' );
		} # end if
	} # end if

	foreach my $type ( keys %services ) {
		foreach my $service_index ( @{$services{$type}} ) {
			if ( sets::isin( $type, [ 'PhotoRetouching', 'ColourCorrection', 'PhotoPlacement', 'CDBurning' ] ) ) {
				$specs = internal_calc( $log, $dbh, $variable, $project_index, $service_index, 'Prepress' );
			} elsif ( sets::isin( $type, [ 'LoopStitching', 'SaddleStitching'] ) ) {
				$specs = internal_calc( $log, $dbh, $variable, $project_index, $service_index, 'Stitching' );
				$alert .= $$specs{'alert'};
			} elsif ( sets::isin( $type , [ 'Bundling', 'KraftWrap', 'ShrinkWrap' ] ) ) {
				$specs = internal_calc( $log, $dbh, $variable, $project_index, $service_index, 'Packaging' );
				$alert .= $$specs{'alert'};
			} elsif ( sets::isin( $type, ['BulkSkids', 'PlainCartons'] ) ) {
				$specs = internal_calc( $log, $dbh, $variable, $project_index, $service_index, 'Skids' );
				$alert .= $$specs{'alert'};
			} elsif ( sets::isin( $type, ['MetalCoil', 'PlasticCoil','PlasticComb','Cerlox','DoubleLoopWire'] ) ) {
				$specs = internal_calc( $log, $dbh, $variable, $project_index, $service_index, 'Spiral' );
				$alert .= $$specs{'alert'};
			} elsif ( sets::isin( $type, ['', 'AdditionalSignature'] ) ) {
			} else {
				eval "require openprint::Estimating::$type";
				$specs = internal_calc( $log, $dbh, $variable, $project_index, $service_index, $type );
				$alert .= $$specs{'alert'};
			} # end if
		} # end foreach service_index
	} # end while service_type
	return $alert;

} # end sub auto_calculate

sub get_status {
	my ( $log, $dbh, $service_index, $project_index ) = @_;

	my $sql = 'SELECT strStatus FROM tbl_Project_Contents WHERE lngServiceIndex=?';
	my @values = ( $service_index );
	if ( $project_index ) {
		$sql .= ' AND lngProjectIndex=?';
		push @values, $project_index;
	} # end if
	my ( $status ) = sql::execute( $log, $dbh, $sql, @values ) ;
	return $status;
} # end sub get_status

# Gets or Sets
sub status {
	my ( $project_index, $service_index, $new_status ) = @_;
	if ( defined $new_status ) {
		sql::update( $openprint::log, $openprint::dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index],
				'strStatus',    $new_status );
		return $new_status;
	} # end if
	( $_ ) = sql::execute( $openprint::log, $openprint::dbh, q{SELECT strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, $service_index );
	return $_;
} # end sub status


sub external_calc {
	my ( $r, $log, $dbh, $variable, $service_type, %specs ) = @_;

	# Not sure this is a good idea, but it's neccessary for printing...
	$specs_cache{$specs{ServiceIndex}} = \%specs;
	my %initial_specs = %specs;
#blah
	eval 'require openprint::Estimating::'.$service_type;
		$log->error("Error in eval: $@") if $@;
	eval q/$specs{'Status'} = openprint::Estimating::/.$service_type.'::calc( $log, $dbh, $variable, @specs{\'ProjectIndex\', \'ServiceIndex\'}, \%specs );';
		$log->error("Error in eval: $@") if $@;
	my @results = ();
	my @vars = eval( 'openprint::Estimating::'.$service_type.'::outputs()' );
	@vars = keys %specs if ! @vars;

	my @no_outputs = eval( 'return openprint::Estimating::'.$service_type.'::no_outputs( @specs{\'ProjectIndex\', \'ServiceIndex\'}, \%specs )' );

$log->warn("No outputs: @no_outputs : $@" ) if $debug;
	@vars = sets::exclude( \@no_outputs, \@vars );

	foreach my $key ( @vars ) {
		if ( exists $specs{$key} ) {
			if ( ( ! exists $initial_specs{$key} ) or ( $specs{$key} ne $initial_specs{$key} ) ) {
				push @results, "$key~$specs{$key}";
			} # end if
		} # end if
	} # end foreach
	return join( '|', @results );
} # end sub external_calc

sub get_type {
	my ( $log, $dbh, $project_index, $service_index ) = @_;
	( $_ ) = sql::execute( $log, $dbh, q{SELECT name FROM Service_Types WHERE id=(select servicetype_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, $service_index );
	return $_;
} # end sub get_type

sub internal_calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $service_type ) = @_;

	if ( ! exists $specs_cache{$service_index} ) {
		%{$specs_cache{$service_index}} = sql::execute( $log, $dbh, 
				q{SELECT strName, strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, $service_index );
	} # end if
	my %specs = %{$specs_cache{$service_index}};

	if ( ! $service_type ) {
		if ( $specs{'ServiceType'} ) {
			$service_type = $specs{'ServiceType'};
		} else {
			$service_type = get_type( $log, $dbh, $project_index, $service_index );
		} # end if
	} # end if

	my $status;
	my $starttime = time;
	eval 'require openprint::Estimating::'.$service_type;
	if ( ! eval '$status = openprint::Estimating::'.$service_type.'::calc( $log, $dbh, $variable, $project_index, $service_index, \%specs );' ) {
		$log->error("Error in eval: $@");
	} # end if
	$specs{'Status'} = $status;
	my $elapsed = time - $starttime;
	$log->debug( "\033" . sprintf( '[41;37m %s calc: Elapsed seconds: %d', $service_type, $elapsed ) );

	my $ac = sql::start_transaction( $dbh );
	sql::update( $log, $dbh, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], 'strStatus', $status );

	foreach my $key ( eval( 'openprint::Estimating::'.$service_type.'::variables( $project_index )') ) {
$log->debug("Internal Calc:: looking at $key $specs{$key} :". $specs_cache{$service_index}{$key}) if $debug;

		openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, $key, $specs{$key} );
	} # end foreach
	sql::end_transaction( $dbh, $ac );
	return \%specs;
} # end sub internal_calc

sub get_runtime {
    my ( $log, $dbh, $project_index, $service_index ) = @_;

    my $Project = new openprint::Project( $project_index );
    my ( $qty_index ) = $Project->ordered_quantity_index();
    my $specs = openprint::service::get_specs_ref( $project_index, $service_index );

    if ( $$specs{'ProjectType'} or ( $$specs{'ServiceType'} eq 'AdditionalSignature' ) ) {
		if ( ! $$specs{'UsePress'} ) {
			$$specs{'UsePress'} = $$specs{'ddmPress'.$qty_index};
		} # end if

		my @Equipment = openprint::Equipment::find( 'strid'=>$$specs{'UsePress'} );
		my $Equipment = shift @Equipment;
		return 0 if ! $Equipment;

        my $run_speed = $Equipment->specification( 'Press Additional Run Speed',$$specs{'txtSpecificStockCalliper'} );
        my $runtime;
        my @side_one_colours = openprint::Estimating::Printing::get_colours( $specs, 'SideOne' );
        my @side_two_colours = openprint::Estimating::Printing::get_colours( $specs, 'SideTwo' );
        my @colours;
        if ( sets::isin( $$specs{'ddmRunStyle'.$qty_index}, ['Work & Turn', 'Work & Tumble'] ) ) {
            @colours = openprint::Estimating::Printing::filter_colours( @side_one_colours, @side_two_colours );
			$runtime += $Equipment->specification('Setup Time');
        } else {
            @colours = ( @side_one_colours, @side_two_colours );
			$runtime += $Equipment->specification('Setup Time') if @side_one_colours;
			$runtime += $Equipment->specification('Setup Time') if @side_two_colours;
        } # end if

        $runtime += $Equipment->specification('Wash Up Time Per Colour') * @colours;
		my $std_runspeed = $Equipment->specification('Press Standard Run Speed');

        if ( $std_runspeed ) {
            if ( $run_speed ) {
                $runtime += int( ( 60 * $$specs{'hdnImpressionQuantity'.$qty_index} / $std_runspeed ) * ( $std_runspeed / $run_speed ) );
            } else {
                $runtime += int ( 60 * $$specs{'hdnImpressionQuantity'.$qty_index} / $std_runspeed );
            } # end if
        } # end if
        return $runtime;
    } elsif ( $$specs{'ServiceType'} eq 'Cutting' ) {
        return openprint::Estimating::Cutting::runtime( $project_index, $service_index, $specs, $qty_index );
    } elsif ( $$specs{'ServiceType'} eq 'Folding' ) {
       return openprint::Estimating::Folding::runtime( $project_index, $service_index, $specs, $qty_index );
    } elsif ( $$specs{'ServiceType'} eq 'Drilling' ) {
        return openprint::Estimating::Drilling::runtime( $project_index, $service_index, $specs, $qty_index );
    } elsif ( sets::isin( $$specs{'ServiceType'}, 'SaddleStitching','LoopStitching' ) ) {
        return openprint::Estimating::Stitching::runtime( $project_index, $service_index, $specs, $qty_index );
    } # end if

} # end sub get_runtime

sub summary {
	my ( $Project, $service_id, $qty_index ) = @_;

	$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';

	my $specs = get_specs_ref( $Project->id(), $service_id );
	if ( $$specs{'ServiceType'} eq 'AdditionalSignature' or ( $$specs{'ServiceType'} eq '' and ! $$specs{'txtTotalPageQuantity'}  ) ) {
		if ( $qty_index ) {
			if ( ! $$specs{'txtSpreadSize'} ) {
				my %services = $Project->get_services();
				if ( $services{''} ) {
					my $printing_specs = get_specs_ref( $Project->id(), $services{''}[0] );
					$$specs{'txtSpreadSize'} = $$printing_specs{'txtSpreadSize'};
				} # end if
			} # end if
			if ( ! exists $$specs{'txtSignatureSpreadQuantity'.$qty_index} ) {
				$$specs{'txtSignatureSpreadQuantity'.$qty_index} = $$specs{'txtSignatureSpreadQuantity'};
			} # end if
			return sprintf(qq{%s %dout %s\n\%s},
					($$specs{'txtSignatureSpreadQuantity'.$qty_index} and $$specs{'txtSpreadSize'} ) ? ($$specs{'txtSignatureSpreadQuantity'.$qty_index} * $$specs{'txtSpreadSize'}) . 'pp' : '',
					$$specs{'txtImposition'.$qty_index},
					($$specs{'ddmRunStyle'.$qty_index} eq 'Web' ? $$specs{'StockWidth'.$qty_index} . '" ' . $$specs{'ddmRunStyle'.$qty_index} : $$specs{'ddmRunStyle'.$qty_index} ),
					'Stock Qty: ' . $$specs{'txtPressSheetQty'.$qty_index} . ($$specs{'ddmRunStyle'.$qty_index} eq 'Web' ? '' : sprintf(' of %s" x %s"', @$specs{'StockWidth'.$qty_index,'StockHeight'.$qty_index}) ),
					);
		} else {
			my $side_one_coatings;
			$side_one_coatings .= '+AQ (Gloss)' if $$specs{'rdbAqueousSideOne'} eq 'Gloss';
			$side_one_coatings .= '+AQ (Matte)' if $$specs{'rdbAqueousSideOne'} eq 'Matte';
			$side_one_coatings .= '+Varnish (Spot Gloss)' if $$specs{'chkVarnishSpotGlossSideOne'};
			$side_one_coatings .= '+Varnish (Spot Matte)' if $$specs{'chkVarnishSpotMatteSideOne'};
			$side_one_coatings .= '+Varnish (Dry Trap)' if $$specs{'chkVarnishDryTrapSideOne'};
			$side_one_coatings .= '+Varnish (Overall Gloss)' if $$specs{'chkVarnishOverallGlossSideOne'};
			$side_one_coatings .= '+Varnish (Overall Matte)' if $$specs{'chkVarnishOverallMatteSideOne'};
			my $side_two_coatings;
			$side_two_coatings .= '+AQ (Gloss)' if $$specs{'rdbAqueousSideTwo'} eq 'Gloss';
			$side_two_coatings .= '+AQ (Matte)' if $$specs{'rdbAqueousSideTwo'} eq 'Matte';
			$side_two_coatings .= '+Varnish (Spot Gloss)' if $$specs{'chkVarnishSpotGlossSideTwo'};
			$side_two_coatings .= '+Varnish (Spot Matte)' if $$specs{'chkVarnishSpotMatteSideTwo'};
			$side_two_coatings .= '+Varnish (Dry Trap)' if $$specs{'chkVarnishDryTrapSideTwo'};
			$side_two_coatings .= '+Varnish (Overall Gloss)' if $$specs{'chkVarnishOverallGlossSideTwo'};
			$side_two_coatings .= '+Varnish (Overall Matte)' if $$specs{'chkVarnishOverallMatteSideTwo'};

			return sprintf( qq{%s %s"x%s" %d%s/%d%s\non %s %s}, 
					@$specs{'txtServiceDescription','txtWidth','txtHeight'}, 
					scalar(openprint::Estimating::Printing::get_colours( $specs, 'SideOne')), 
					$side_one_coatings,
					scalar(openprint::Estimating::Printing::get_colours( $specs, 'SideTwo')),
					$side_two_coatings,
					$$specs{'rdbSuppliedStock'} eq 'Y' ? '<b>Customer Supplied</b>' : '',
					$$specs{'rdbSpecificStock'} eq 'Y' ? 
					join(',', @$specs{'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight'} ) :
					join(',', @$specs{'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight'} ) 
					,
					);
		} # end if
	} elsif ( sets::isin( $$specs{'ServiceType'}, ['PlainCartons','BulkSkids'] ) ) {
		return openprint::Estimating::Skids::summary($Project->id(), $service_id, $specs, $qty_index );
	} elsif ( sets::isin( $$specs{'ServiceType'}, ['ShrinkWrap','KraftWrap','Bundling'] ) ) {
		return openprint::Estimating::Packaging::summary($Project->id(), $service_id, $specs, $qty_index );
	} elsif ( sets::isin( $$specs{'ServiceType'}, ['SaddleStitching','LoopStitching'] ) ) {
		return openprint::Estimating::Stitching::summary($Project->id(), $service_id, $specs, $qty_index );
	} else {
		eval('require openprint::Estimating::'.$$specs{'ServiceType'}.';' );
	$openprint::log->warn("ERror requiring openprint::Estimating::$$specs{'ServiceType'}.'::summary: $@)") if $@;
		my $summary = eval('openprint::Estimating::'.$$specs{'ServiceType'}.'::summary( $Project, $service_id, $specs, $qty_index );' );
	$openprint::log->warn("ERror evalling openprint::Estimating::$$specs{'ServiceType'}.'::summary: $@)") if $@;
		return $summary;
	} # end if
	return;
} # end sub summary

1;

__END__
