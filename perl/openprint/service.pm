use strict;
package openprint::service;

use Carp qw( cluck );

require openprint::Equipment;
require openprint::pricing;
require openprint::logs;
require openprint::Project_Service;

use constant DEBUG => 0;

use vars qw( %specs_cache );

sub init_cache {
	%specs_cache = ();
} # end sub init_cache

sub get_price {
	my ( $service, $range, $Equipment ) = @_;

	my %price = get_price_object( $service, $range, $Equipment );
	return $price{'Price'};
} # end sub get_price

sub get_price_object {
	my ( $service, $range, $Equipment ) = @_;
	my $Service = openprint::Service->find_one( name=>$service );
	if ( ! $Service ) {
		if ( DEBUG ) {
			$openprint::log->debug("No Service for $service");
		};
		return;
	}
	return $Service->get_price( $range, $Equipment );
} # end sub get_price_object

sub save_service {
	my ( $r, $log, $dbh, $project_index, $service_index ) = @_;

	$log->debug("***** START OF  save_service ************");
	if ( ! exists $specs_cache{$service_index} ) {
		%{$specs_cache{$service_index}} = sql::execute( $log, $dbh, 
				'SELECT strName, strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?', $project_index, $service_index );
	} # end if
	my $Project = new openprint::Project( $project_index );
	my $specs = $specs_cache{$service_index};

	my $service_type = $openprint::param{'ServiceType'};
	if ( ! $service_type ) {
		my $ServiceType = $Project->ServiceType( $service_index );
		$service_type = $ServiceType->type();
	} # end if
	if ( (! $service_type) and (! $$specs{'ProjectType'}) ) {
		$log->error( "No serviceType in params for service $service_index.  Trying to recover" );
	} # end if
	if ( ! $service_type ) {
		$service_type = $Project->Type()->type();
	} # end if
	my $module = 'openprint::Estimating::'.$service_type;

	eval ( 'require '.$module.';' );
	my @variables = eval( $module.'::variables( $project_index, $service_index, $specs, \%openprint::param )');
	$log->error($@) if $@;
$log->debug("variables: @variables");
# We cannot locak tbl_service_specifications or tbl_project_contents.  Just too nasty.  So use tbl_Projects as the contention point.
	# make this fast by doing it in one transaction, locking does the tranasaction for us
	$Project->lock();
	foreach my $key (@variables) {
#$log->debug("Key: $key ($openprint::param{$key}) ( $$specs{$key})");
		if ( ref $openprint::param{$key} eq 'ARRAY' ) {
#$log->error("Key: $key ($openprint::param{$key}) ( $$specs{$key})");
		} elsif ( ! exists $openprint::param{$key} ) {
			delete_service_spec( $project_index, $service_index, $key );
		} else {
			s/^\s+//, s/\s+$// for $openprint::param{$key};
			insert_service_spec( $log, $dbh, $project_index, $service_index, $key, $openprint::param{$key}, 0 );
		} # end if
	} # end foreach
	$Project->unlock();
	if ( my $function = $module->can('save') ) {
		$function->( $project_index, $service_index, \%openprint::param );
	} # end if

	# FIXME: should clean this up
	if ( $openprint::param{'Additional'} eq 'Y' or $openprint::param{'additional_service'} eq 'Y' ) {
		$Project->add_service( $service_type );
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
		cluck("********* Called get_specifications_pairs with Project Index or Service Index ****************");
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
	if ( ! $s_id ) {
		$openprint::log->error("********* Called get_specs_ref without Service Index ($s_id)****************");
		Carp::cluck("********* Called get_specs_ref without Service Index ($s_id)****************");
		return;
	} # end if
	if ( ! exists $specs_cache{$s_id} ) {
		if ( sets::isin( ref $p_id, [ 'openprint::Project', 'openprint::QuotedProject' ] ) ) {
			$p_id = $p_id->id();
		} # end if
		if ( ! $p_id ) {
			Carp::cluck("********* Called get_specs_ref without Project Index ****************");
			return;
		} # end if
		%{$specs_cache{$s_id}} = sql::execute( $openprint::log, undef, 
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
	if ( $specs_cache{$service_index}{$name} eq $value ) {
		$log->debug("insert_service_spec: return because no change in value: ($name)($value)") if DEBUG;
		return;
	} # end if

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
					'strValue',			$value] ) if $value;
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
	my ( $Project, $exclude ) = @_;

	my $alert;
	my $specs;

	my @signature_indices = $Project->signatures();
	if ( ! @signature_indices ) {
		$openprint::log->warn("service::auto_calculate with no signatures");
		return;
	} # end if

	# If the printing services aren't complete, then there is no sense continuing
	my @statuses = sql::execute( $openprint::log, $openprint::dbh, q{SELECT DISTINCT strStatus FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex IN (}.join(',', @signature_indices).q{)}, $$Project{'id'} );
	if ( sets::isin( 'uncalculated', \@statuses ) ) {
		$openprint::log->warn("service::auto_calculate with uncalcaulted signatures");
		return;
	} # end if
	my $services = $Project->services();

# Folding - first find out if we need it, and make sure we have it or don't as neccessary
	require openprint::Estimating::Folding;
	if ( ! openprint::Estimating::Folding::neccessary( $Project ) ) {
		if ( $$services{Folding} ) {
			while ( my $si = shift @{$$services{'Folding'}} ) {
				openprint::print_project::delete_service( $$Project{'id'}, $si );
			} # end while
			delete $$services{Folding};
		} # end if
	} else {
		if ( ! $$services{Folding} ) {
			push @{$$services{Folding}}, $Project->add_service( 'Folding' );
		} # end if
	} # end if

	if ( openprint::Estimating::Paper::neccessary( $Project ) ) {
		if ( ! $$services{'Paper'} ) {
			push @{$$services{'Paper'}}, $Project->add_service( 'Paper' );
		} # end if
	} # end if

	require openprint::Estimating::Cutting;
	if ( openprint::Estimating::Cutting::neccessary( $Project ) ) {
		if ( ! $$services{'Cutting'} ) {
			push @{$$services{'Cutting'}}, $Project->add_service( 'Cutting' );
		} # end if
	} # end if

require openprint::Estimating::PerfectBound;
	if ( openprint::Estimating::PerfectBound::neccessary( $Project ) ) {
		if ( ! $$services{'PerfectBound'} ) {
			push @{$$services{'PerfectBound'}}, $Project->add_service( 'PerfectBound' );
		} # end if
	} elsif ( $$services{'PerfectBound'} ) {
		while ( my $si = shift @{$$services{'PerfectBound'}} ) {
			openprint::print_project::delete_service( $$Project{'id'}, $si );
		} # end while
		delete $$services{'PerfectBound'};
	} # end if

require openprint::Estimating::Stitching;
	if ( openprint::Estimating::Stitching::neccessary( $Project ) ) {
		if ( ! ( $$services{'SaddleStitching'} or $$services{'LoopStitching'} ) ) {
			push @{$$services{'SaddleStitching'}}, $Project->add_service( 'SaddleStitching' );
		} # end if
	} # end if

	require openprint::Estimating::ThreeKnifeTrim;
	if ( openprint::Estimating::ThreeKnifeTrim::neccessary( $Project ) ) {
		if ( ! $$services{'ThreeKnifeTrim'} ) {
			push @{$$services{'ThreeKnifeTrim'}}, $Project->add_service( 'ThreeKnifeTrim' );
		} # end if
	} # end if

	require openprint::Estimating::Tipping;
	if ( openprint::Estimating::Tipping::neccessary( $Project ) ) {
		if ( ! $$services{'Tipping'} ) {
			$_ = $Project->add_service( 'Tipping' );
			push @{$$services{'Tipping'}}, $_ if $_;
		} # end if
	} # end if

	require openprint::Estimating::Blowing;
	if ( openprint::Estimating::Blowing::neccessary( $Project ) ) {
		if ( ! $$services{'Blowing'} ) {
			$_ = $Project->add_service( 'Blowing' );
			push @{$$services{'Blowing'}}, $_ if $_;
		} # end if
	} # end if

	require openprint::Estimating::Collating;
	if ( openprint::Estimating::Collating::neccessary( $Project ) ) {
		if ( ! $$services{'Collating'} ) {
			$_ = $Project->add_service( 'Collating' );
			push @{$$services{'Collating'}}, $_ if $_;
		} # end if
	} else {
		if ( $$services{'Collating'} ) {
			foreach my $si ( @{$$services{'Collating'}} ) {
				openprint::print_project::delete_service( $$Project{'id'}, $si );
			} # end foreach
			delete $$services{'Collating'};
		} # end if
	} # end if

# Proofs
	if ( ! ( $$services{'Proofs'} or $$services{'NoPrinting'} ) ) {
		push @{$$services{'Proofs'}}, $Project->add_service( 'Proofs' );
	} # end if

	foreach my $si ( @{$$services{'Proofs'}} ) {
		if ( $openprint::config{'Insert Default Proofs'} eq 'Y' ) {
			openprint::Estimating::Proofs::insert_proof_defaults( $openprint::log, $openprint::dbh, $$Project{'id'}, $si );
		} # end if
	} # end foreach

	require openprint::Estimating::Skids;
	if ( ! $$services{'BulkSkids'} ) {
		if ( openprint::Estimating::Skids::neccessary( $Project, 'BulkSkids' ) ) {
			push @{$$services{'BulkSkids'}}, $Project->add_service( 'BulkSkids' );
		} # end if
	} # end if
	if ( ! $$services{'PlainCartons'} ) {
		if ( openprint::Estimating::Skids::neccessary( $Project, 'PlainCartons' ) ) {
			push @{$$services{'PlainCartons'}}, $Project->add_service( 'PlainCartons' );
		} # end if
	} # end if

	foreach my $service_name ( 'Scoring', 'Perforating', 'Counting', 'Grommeting', 'Sewing', 'Imposition' ) {
		next if $$services{$service_name};
		eval 'require openprint::Estimating::'.$service_name.';';
		$openprint::log->error("Error requiring opepnrint::Estimating::$service_name: $@") if $@;
		my $neccessary = eval 'openprint::Estimating::'.$service_name.'::neccessary( $Project )';
		$openprint::log->error("Error opepnrint::Estimating::$service_name::neccessary $@") if $@;

		if ( $neccessary and ! $$services{$service_name} ) {
			$_ = $Project->add_service($service_name);
			push @{$$services{$service_name}}, $_ if $_;
		} # end if
	} # end foreach service_name;

	# Order for these is important.  Stitching must be calc'd before Folding
	foreach my $type ( 'Folding','SaddleStitching','LoopStitching' ) {
		next if ! $$services{$type};
		foreach my $service_index ( @{$$services{$type}} ) {
			my $ServiceType = $Project->ServiceType( $service_index );
			my $service_type = $ServiceType->type();
			$specs = internal_calc( $openprint::log, $openprint::dbh, \%openprint::variable, $$Project{'id'}, $service_index, $service_type );
			$alert .= $$specs{'alert'};
		} # end foreach service_index
	} # end while service_type

	foreach my $type ( keys %{$services} ) {
		if ( ! @{$$services{$type}} ) {
			$openprint::log->error("Have $type but no actual service");
			next;
		} # end if
		next if sets::isin( $type, [ 'SaddleStitching','LoopStitching','Folding','Signature' ] );
		next if $exclude and sets::isin( $type, $exclude );

		foreach my $service_index ( @{$$services{$type}} ) {
			my $ServiceType = $Project->ServiceType( $service_index );
			next if $ServiceType->category() eq 'Shipping';
			my $service_type = $ServiceType->type();
			next if sets::isin( $service_type, ['','Signature'] );
			$specs = internal_calc( $openprint::log, $openprint::dbh, \%openprint::variable, $$Project{'id'}, $service_index, $service_type );
			$alert .= $$specs{'alert'};
		} # end foreach service_index
	} # end while service_type

	foreach my $ServiceType ( openprint::ServiceType->find( category=>'Shipping' ) ) {
		if ( $$services{$ServiceType->name()} ) {
			if ( ! @{$$services{$ServiceType->name()}} ) {
				$openprint::log->error("Have $$ServiceType{name} but no actual service");
				next;
			} # end if
			foreach my $service_index ( @{$$services{$ServiceType->name()}} ) {
				$specs = internal_calc( $openprint::log, $openprint::dbh, \%openprint::variable, $$Project{'id'}, $service_index, $ServiceType->type() );
				$alert .= $$specs{'alert'};
			} # end foreach service_index
		} # end if
	} # end foreach
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
	require "openprint/Estimating/$service_type.pm";
	my $module = 'openprint::Estimating::'.$service_type;
	if ( my $function = $module->can( 'calc' ) ) {
		$specs{'Status'} = $function->( $log, $dbh, $variable, @specs{'ProjectIndex', 'ServiceIndex'}, \%specs, $specs{qty_index} );
	} # end if
	my @results = ();
	my @vars = eval( 'openprint::Estimating::'.$service_type.'::outputs()' );
	if ( ! @vars ) {
		#$log->warn("No outputs for $service_type");
		@vars = keys %specs;
	} # end if

	my @no_outputs = eval( 'return openprint::Estimating::'.$service_type.'::no_outputs( @specs{\'ProjectIndex\', \'ServiceIndex\'}, \%specs )' );
	push @no_outputs, ( 'ProjectIndex', 'ServiceIndex', 'ServiceType' );

	@vars = sets::exclude( \@no_outputs, \@vars );

	foreach my $key ( @vars ) {
#$log->debug( "$key~$specs{$key}" );
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
	my ( $log, $dbh, $variable, $project_index, $service_index, $service_type, $qty_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	$Project->lock();
	#$Project->save({status=>'uncalculated'}) if $Project->status() ne 'uncalculated';
	my $Service = $Project->Service($service_index) if $service_index;
	$Service->save({status=>'uncalculated'}) if $Service->status() ne 'uncalculated';
	my $specs;
	if ( ! $Service ) {
$openprint::log->error("Doing internal calc without service_index or, not found");
		$Service = new openprint::Project_Service();
		$Service->set({ project_id=>$project_index, service_id=>$service_index, service_type=>$service_type });
	} else {
		$specs = $Service->specs();
	} # end if	
	my %specs = %{$specs} if $specs;

	if ( ! $service_type ) {
		$service_type = $Service->service_type();
	} # end if

	my $status;
	my $starttime = time;

	my $package = 'openprint::Estimating::'.$service_type;
	#require $package;
	# We are doing this in an eval because we don't actually want to die.
	eval 'require openprint::Estimating::'.$service_type;
	$log->error("Error in requiring $package $@") if $@;
	if ( DEBUG ) {
		foreach my $key ( eval( 'openprint::Estimating::'.$service_type.'::variables( $project_index, $service_index, \%specs )') ) {
			$log->debug("Internal Calc:: before calc $key $specs{$key} :". $specs_cache{$service_index}{$key});
		} # end foreach
	} # end if
	if ( my $function = $package->can('calc') ) {
		my $status = $function->( $log, $dbh, $variable, $project_index, $service_index, \%specs, $qty_index );
		$specs{Status} = $status;
		my $elapsed = time - $starttime;
		$log->debug( sprintf( '%s calc: (%s) Elapsed seconds: %d (%s)', $service_type, $status, $elapsed, $specs{'alert'} ) );

		$Service->save({status=>$status}) if $status ne $Service->status();

		foreach my $key ( eval( 'openprint::Estimating::'.$service_type.'::variables( $project_index, $service_index, \%specs )') ) {
			$log->debug("Internal Calc:: looking at $key $specs{$key} :". $specs_cache{$service_index}{$key}) if DEBUG;
			openprint::service::insert_service_spec( $log, $dbh, $project_index, $service_index, $key, $specs{$key} );
		} # end foreach
	} else {
		$log->error($package . ' cant calc');
	} # end if
	$Project->unlock();
	return \%specs;
} # end sub internal_calc

# Returns vale in seconds
sub get_runtime {
    my ( $Project, $service_index, $Equipment, $impressions, $speed, $pertains_to ) = @_;
	my $Service = $Project->Service( $service_index );
	return $Service->runtime( $Equipment, $impressions, $speed, $pertains_to );
} # end sub get_runtime

sub summary {
	my ( $Project, $service_id, $qty_index ) = @_;

	my @service_ids = split(',', $service_id );
	$service_id = $service_ids[0];

	$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';
	my $services = $Project->services();
	my $ServiceType = $Project->ServiceType( $service_id );
	return '' if ! $ServiceType->summary_visible();

	my $specs = get_specs_ref( $Project, $service_id );
	if ( $$specs{'ServiceType'} eq 'Signature' or ( $$specs{'ServiceType'} eq '' and ! $$specs{'txtTotalPageQuantity'}  ) ) {
		require openprint::Estimating::Printing;
		return openprint::Estimating::Printing::summary($Project, $service_id, $specs, $qty_index );
	} elsif ( sets::isin( $$specs{'ServiceType'}, ['ShrinkWrap','KraftWrap','Bundling','Banding','CrossBanding'] ) ) {
		require openprint::Estimating::Packaging;
		return openprint::Estimating::Packaging::summary($Project, $service_id, $specs, $qty_index );
	} elsif ( sets::isin( $$specs{'ServiceType'}, ['SaddleStitching','LoopStitching'] ) ) {
		require openprint::Estimating::Stitching;
		return openprint::Estimating::Stitching::summary($Project, $service_id, $specs, $qty_index );
	} else {
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
