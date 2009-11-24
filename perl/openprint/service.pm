package openprint::service;

use strict;

require openprint::Equipment;
require openprint::pricing;
require openprint::project;

require openprint::Estimating::Cutting;
require openprint::Estimating::Counting;
require openprint::Estimating::Folding;
require openprint::Estimating::Proofs;
require openprint::Estimating::Scoring;
require openprint::Estimating::Drilling;
require openprint::Estimating::Scanning;
require openprint::Estimating::Prepress;
require openprint::Estimating::Stitching;
require openprint::Estimating::ThreeKnifeTrim;
require openprint::Estimating::Tipping;
require openprint::Estimating::Blowing;
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

use vars qw( %specs_cache );
my %cache_index_by_id;
my %cache_id_by_index;

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
	my ( $service, $range, $Equipment ) = @_;

	my %price = get_price_object( $service, $range, $Equipment );
	return $price{'Price'};
} # end sub get_price

sub get_price_object {
	my ( $service, $range, $Equipment ) = @_;

	my $index = get_index_by_id( $service );
	return if ! $index;

	my $list_id = openprint::pricing::get_pricelist_id( );
	my %price = openprint::pricing::get_best_price_object( $openprint::log, $openprint::dbh, $openprint::session{'company_id'}, $index, $list_id, 'openprint::service_priceset', $range, $$Equipment{'id'} );
	return if ! %price;

	my $Pricelist = new openprint::Pricelist( $list_id );
	$price{'currency_id'} = $$Pricelist{'currency_id'};
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

	my $service_type = $openprint::param{'ServiceType'};
	if ( ! $service_type ) {
		my $Project = new openprint::Project( $project_index );
		my $ServiceType = $Project->ServiceType( $service_index );
		$service_type = $ServiceType->type();
	} # end if
	if ( (! $service_type) and (! $$specs{'ProjectType'}) ) {
		$log->error( "No serviceType in params for service $service_index.  Trying to recover" );
	} # end if
	if ( sets::isin( $service_type, [ '', 'AdditionalSignature' ] ) ) {
		$service_type = 'Printing';
	} # end if
	eval ( 'require openprint::Estimating::'.$service_type.';' );
	my @variables = eval( 'openprint::Estimating::'.$service_type.'::variables( $project_index, $service_index, $specs, \%openprint::param )');
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
	eval( 'openprint::Estimating::'.$service_type.'::save( $project_index, $service_index, \%openprint::param )');
	$log->error($@) if $@;

	if ( $openprint::param{'Additional'} eq 'Y' ) {
		openprint::print_project::insert_service( $log, $dbh, $project_index, $service_type );
	} # end if

	$log->debug("***** END  OF  save_service ************");
} # end sub save_service

sub get_specifications {
	my ( $log, $dbh, $project_index, $service_index, @specs ) = @_;
	if ( ! ( $project_index or $service_index ) ) {
		$log->error(" ***** get_specifications requested without Project or Service Index *********");
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
	if ( sets::isin( ref $p_id, [ 'openprint::Project', 'openprint::QuotedProject' ] ) ) {
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
	my ( $r, $log, $dbh, $variable, $project_index, $exclude ) = @_;

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
	if ( ! openprint::Estimating::Folding::neccessary( $project_index ) ) {
		while ( my $si = shift @{$services{'Folding'}} ) {
			openprint::print_project::delete_service( $log, $dbh, $project_index, $si );
		} # end while
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
$openprint::log->debug("Apres Paper");

	if ( openprint::Estimating::Cutting::neccessary( $Project ) ) {
		if ( ! $services{'Cutting'} ) {
			if ( $Project->mode() ne 'Detailed' ) { 
				push @{$services{'Cutting'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Cutting' );
			} # end if
		} # end if
	} # end if
$openprint::log->debug("Apres Cutting");

	if ( openprint::Estimating::PerfectBound::neccessary( $Project ) ) {
		if ( ! $services{'PerfectBound'} ) {
			push @{$services{'PerfectBound'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'PerfectBound' );
		} # end if
	} elsif ( $services{'PerfectBound'} ) {
		while ( my $si = shift @{$services{'PerfectBound'}} ) {
			openprint::print_project::delete_service( $log, $dbh, $project_index, $si );
		} # end while
	} # end if
$openprint::log->debug("Apres PF");

	if ( openprint::Estimating::Stitching::neccessary( $log, $dbh, $project_index ) ) {
		if ( ! ( $services{'SaddleStitching'} or $services{'LoopStitching'} ) ) {
			push @{$services{'SaddleStitching'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'SaddleStitching' );
		} # end if
	} # end if

	if ( openprint::Estimating::ThreeKnifeTrim::neccessary( $log, $dbh, $project_index ) ) {
		if ( ! $services{'ThreeKnifeTrim'} ) {
			push @{$services{'ThreeKnifeTrim'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'ThreeKnifeTrim' );
		} # end if
	} # end if

	if ( openprint::Estimating::Tipping::neccessary( $Project ) ) {
		if ( ! $services{'Tipping'} ) {
			push @{$services{'Tipping'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Tipping' );
		} # end if
	} # end if

	if ( openprint::Estimating::Blowing::neccessary( $Project ) ) {
		if ( ! $services{'Blowing'} ) {
			push @{$services{'Blowing'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Blowing' );
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
$openprint::log->debug("Apres Collat");

# Proofs
	if ( ! ( $services{'Proofs'} or $services{'NoPrinting'} ) ) {
		push @{$services{'Proofs'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Proofs' );
	} # end if

	foreach my $si ( @{$services{'Proofs'}} ) {
		if ( $openprint::config{'Insert Default Proofs'} eq 'Y' ) {
			openprint::Estimating::Proofs::insert_proof_defaults( $log, $dbh, $project_index, $si );
		} # end if
	} # end foreach
$openprint::log->debug("Apres porrat");

	if ( ! $services{'BulkSkids'} ) {
		if ( openprint::Estimating::Skids::neccessary( $Project, 'BulkSkids' ) ) {
			push @{$services{'BulkSkids'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'BulkSkids' );
		} # end if
	} # end if
	if ( ! $services{'PlainCartons'} ) {
		if ( openprint::Estimating::Skids::neccessary( $Project, 'PlainCartons' ) ) {
			push @{$services{'PlainCartons'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'PlainCartons' );
		} # end if
	} # end if
$openprint::log->debug("Apres Skdis");

	if ( ! $services{'PlainCartons'} ) {
		if ( openprint::Estimating::Skids::neccessary( $Project, 'PlainCartons' ) ) {
			push @{$services{'PlainCartons'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'PlainCartons' );
		} # end if
	} # end if

	if ( ! $services{'Scoring'} ) {
		if ( openprint::Estimating::Scoring::neccessary( $Project ) ) {
			push @{$services{'Scoring'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Scoring' );
		} # end if
	} # end if
	if ( ! $services{'Perforating'} ) {
		if ( openprint::Estimating::Perforating::neccessary( $Project ) ) {
			push @{$services{'Perforating'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Perforating' );
		} # end if
	} # end if

	if ( openprint::Estimating::Counting::neccessary( $Project ) ) {
		push @{$services{'Counting'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'Counting' ) if ! $services{'Counting'};
	} # end if

	# Order for these is important.  Stitching must be calc'd before Folding
	foreach my $type ( 'Folding','SaddleStitching','LoopStitching' ) {
		next if ! $services{$type};
		foreach my $service_index ( @{$services{$type}} ) {
			my $ServiceType = $Project->ServiceType( $service_index );
			my $service_type = $ServiceType->type();
			$specs = internal_calc( $log, $dbh, $variable, $project_index, $service_index, $service_type );
			$alert .= $$specs{'alert'};
		} # end foreach service_index
	} # end while service_type

	foreach my $type ( keys %services ) {
		next if sets::isin( $type, [ 'SaddleStitching','LoopStitching','Folding' ] );
		next if $exclude and sets::isin( $type, $exclude );

		foreach my $service_index ( @{$services{$type}} ) {
			my $ServiceType = $Project->ServiceType( $service_index );
			my $service_type = $ServiceType->type();
			next if sets::isin( $service_type, ['','AdditionalSignature'] );
			$specs = internal_calc( $log, $dbh, $variable, $project_index, $service_index, $service_type );
			$alert .= $$specs{'alert'};
		} # end foreach service_index
	} # end while service_type
	return $alert;

} # end sub auto_calculate

# Gets or Sets
sub status {
	my ( $project_index, $service_index, $new_status ) = @_;
	if ( defined $new_status ) {
		sql::update( undef, undef, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index],
				'strStatus',    $new_status );
		return $new_status;
	} # end if
	( $_ ) = sql::execute( undef, undef, q{SELECT strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, $service_index );
	return $_;
} # end sub status

sub operator_id {
	my ( $project_index, $service_index, $operator_id ) = @_;
	if ( defined $operator_id ) {
		sql::update( undef, undef, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index], 'operator_id', $operator_id );
		return $operator_id;
	} # end if
	( $_ ) = sql::execute( undef, undef, q{SELECT operator_id FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, $project_index, $service_index );
	return $_;
} # end sub operator_id


sub external_calc {
	my ( $r, $log, $dbh, $variable, $service_type, %specs ) = @_;

	# Not sure this is a good idea, but it's neccessary for printing...
	$specs_cache{$specs{ServiceIndex}} = \%specs;
	my %initial_specs = %specs;
#blah
	eval 'require openprint::Estimating::'.$service_type;
		$log->error("Error requiring opepnrint::Estimating::$service_type: $@") if $@;
	eval q/$specs{'Status'} = openprint::Estimating::/.$service_type.'::calc( $log, $dbh, $variable, @specs{\'ProjectIndex\', \'ServiceIndex\'}, \%specs );';
		$log->error("Error requiring openprint::Estimating::$service_type: in eval: $@") if $@;
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

	my $Project = new openprint::Project( $project_index );
	my $specs = get_specs_ref( $Project, $service_index );
	my %specs = %{$specs};

	if ( ! $service_type ) {
		my $ServiceType = $Project->ServiceType( $service_index );
		$service_type = $ServiceType->type();
	} # end if

	my $status;
	my $starttime = time;
	eval 'require openprint::Estimating::'.$service_type;
	$log->error("Error in requiring openprint::Estiamting::$service_type ::calc: $@") if $@;
	if ( ! eval '$status = openprint::Estimating::'.$service_type.'::calc( $log, $dbh, $variable, $project_index, $service_index, \%specs );' ) {
		$log->error("Error in openprint::Estiamting::$service_type ::calc: $@") if $@;
	} # end if
	$specs{'Status'} = $status;
	my $elapsed = time - $starttime;
	$log->debug( "\033" . sprintf( '[41;37m %s calc: (%s) Elapsed seconds: %d', $service_type, $status, $elapsed ) );

	my $ac = sql::start_transaction( $dbh );
	status( $project_index, $service_index, $status );

	foreach my $key ( eval( 'openprint::Estimating::'.$service_type.'::variables( $project_index, $service_index, \%specs )') ) {
$log->debug("Internal Calc:: looking at $key $specs{$key} :". $specs_cache{$service_index}{$key}) if $debug;

		openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, $key, $specs{$key} );
	} # end foreach
	sql::end_transaction( $dbh, $ac );
	return \%specs;
} # end sub internal_calc

sub get_runtime {
    my ( $Project, $service_index ) = @_;

    my $qty_index = $Project->ordered_quantity_index();
    my $specs = openprint::service::get_specs_ref( $Project, $service_index );

    if ( $$specs{'ProjectType'} or ( $$specs{'ServiceType'} eq 'AdditionalSignature' ) ) {
		if ( ! $$specs{'UsePress'} ) {
			$$specs{'UsePress'} = $$specs{'ddmPress'.$qty_index};
		} # end if

		my @Equipment = openprint::Equipment::find( 'strid'=>$$specs{'UsePress'} );
		return 0 if ! @Equipment;
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
        return openprint::Estimating::Cutting::runtime( $Project->id(), $service_index, $specs, $qty_index );
    } elsif ( $$specs{'ServiceType'} eq 'Folding' ) {
       return openprint::Estimating::Folding::runtime( $Project->id(), $service_index, $specs, $qty_index );
    } elsif ( $$specs{'ServiceType'} eq 'Drilling' ) {
        return openprint::Estimating::Drilling::runtime( $Project->id(), $service_index, $specs, $qty_index );
    } elsif ( sets::isin( $$specs{'ServiceType'}, 'SaddleStitching','LoopStitching' ) ) {
        return openprint::Estimating::Stitching::runtime( $Project->id(), $service_index, $specs, $qty_index );
    } # end if

} # end sub get_runtime

sub summary {
	my ( $Project, $service_id, $qty_index ) = @_;

	$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';
	my $services = $Project->services();

	my $specs = get_specs_ref( $Project, $service_id );
	if ( $$specs{'ServiceType'} eq 'AdditionalSignature' or ( $$specs{'ServiceType'} eq '' and ! $$specs{'txtTotalPageQuantity'}  ) ) {
		return openprint::Estimating::Printing::summary($Project, $service_id, $specs, $qty_index );
	} elsif ( sets::isin( $$specs{'ServiceType'}, ['ShrinkWrap','KraftWrap','Bundling','Banding','CrossBanding'] ) ) {
		return openprint::Estimating::Packaging::summary($Project, $service_id, $specs, $qty_index );
	} elsif ( sets::isin( $$specs{'ServiceType'}, ['SaddleStitching','LoopStitching'] ) ) {
		return openprint::Estimating::Stitching::summary($Project, $service_id, $specs, $qty_index );
	} else {
		my $ServiceType = $Project->ServiceType( $service_id );
		my $ServiceTypeType = $ServiceType->type();
		return if ! $ServiceTypeType;
		
		eval('require openprint::Estimating::'.$ServiceTypeType.';' );
		$openprint::log->error("ERror requiring openprint::Estimating::$ServiceTypeType ::summary: $@)") if $@;
		my $summary = eval('openprint::Estimating::'.$ServiceTypeType.'::summary( $Project, $service_id, $specs, $qty_index );' );
		$openprint::log->error("ERror evalling openprint::Estimating:: $ServiceTypeType ::summary: $@)") if $@;
		return $summary;
	} # end if
	return;
} # end sub summary

sub breakupsummary {
	my ( $Project, $service_id, $qty_index ) = @_;

	$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';
	my $services = $Project->services();

	my $specs = get_specs_ref( $Project, $service_id );

	if ( $$specs{'ServiceType'} eq 'Proofs' ) {
		my $ServiceType = $Project->ServiceType( $service_id );
		my $ServiceTypeType = $ServiceType->type();
		return if ! $ServiceTypeType;
		
#		eval('require openprint::Estimating::'.$ServiceTypeType.';' );
#		$openprint::log->error("ERror requiring openprint::Estimating::$ServiceTypeType ::breakupsummary: $@)") if $@;
		my $summary = openprint::Estimating::Proofs::breakupsummary( $Project, $service_id, $specs, $qty_index );
		$openprint::log->error("ERror evalling openprint::Estimating:: $ServiceTypeType ::breakupsummary: $@)") if $@;
		return $summary;
	} # end if
	return;
} # end sub summary

1;

__END__
