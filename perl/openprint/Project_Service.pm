use strict;
package openprint::Project_Service;
our @ISA = qw(openprint::Object);

require openprint;
require openprint::Project;
require openprint::User;
require openprint::ServiceType;

use vars qw( $debug %fields %find_fields %transforms %defaults $table %serial @identified_by );

$debug = 0;
%fields = (
	service_id	=>	'lngserviceindex',
	project_id	=>	'lngprojectindex',
	operator_id	=>	'operator_id',
	status		=>	'strstatus',
	servicetype_id	=>	'servicetype_id',
	service_type	=>	undef,
	created_on		=>	'dtmlastmodified',
);
%find_fields = (
	category	=>	'(SELECT ServiceType_Categories.name FROM ServiceType_Categories,Service_Types WHERE ServiceType_Categories.id=Service_Types.category_id AND Service_Types.id=servicetype_id)',
	servicetype		=>	'(SELECT name FROM service_types WHERE service_types.id=servicetype_id)',
);
%transforms = (
	
);
%defaults = (
	service_id	=>	undef,
	operator_id	=>	undef,
	created_on	=>	q`'NOW()'`,
);
$table = 'tbl_project_contents';
%serial = ( service_id=>'ContentsServiceIndex_seq' );
@identified_by = ( 'project_id', 'service_id' );

sub Project {
	return new openprint::Project( $_[0]{project_id} );
} # end sub Project

sub Operator {
	return new openprint::User( $_[0]{operator_id} );
} # end sub Operator

sub specs {
	if ( ! $_[0]{specs} ) {
		if ( $_[0]{service_id} ) {
			$_[0]{specs} = openprint::service::get_specs_ref( $_[0]->Project(), $_[0]{service_id} );
		} else {
			$_[0]{specs} = {};
		} # end if
	} # end if
	return $_[0]{specs};
} # end sub specs

sub ServiceType {
	return new openprint::ServiceType( $_[0]{'servicetype_id'} );
} # end sub ServiceType

sub service_type {
	if ( @_ > 1 ) {
		$_[0]{service_type} = $_[1];
	} # end if
	if ( ! $_[0]{service_type} ) {
		$_[0]{service_type} = $_[0]->ServiceType()->type();
	} # end if
	return $_[0]{service_type};
} # end sub service_type

sub Equipment {
	my ( $self, $qty_index ) = @_;

	if ( ! $$self{Equipment} ) {
		if ( ! $qty_index ) { 
			# Want ordered quantity
			$qty_index = $self->Project()->ordered_quantity_index();
		} # end if
		
		my $specs = $self->specs();
		my $ServiceType = $self->ServiceType();

		if ( $ServiceType->name() eq 'Cutting' ) {
			$$self{Equipment} = openprint::Equipment->find_one(
					'use_in_scheduling'=>1,
					'Specifications'=>{'Cutting Capable'=>'Y'},
					);
		} elsif ( $ServiceType->name() eq 'Folding' ) {
			$$self{Equipment} = openprint::Equipment->find_one(
					'use_in_scheduling'=>1,
					'Specifications'=>{'Folding Capable'=>'Y'},
					);
		} elsif ( $ServiceType->name() eq 'Stitching' ) {
			if ( $$specs{'ddmEquipment'.$qty_index} ) {
				$$self{Equipment} =  new openprint::Equipment( $$specs{'ddmEquipment'.$qty_index} );
			} else {
			$$self{Equipment} = openprint::Equipment->find_one(
					'use_in_scheduling'=>1,
					'Specifications'=>{'Stitching Capable'=>'Y'},
					);
			} # end if
		} elsif ( ( $ServiceType->name() eq '' ) or $ServiceType->name() eq 'Signature' ) {
			$$self{Equipment} = openprint::Equipment->find_one( strid=>$$specs{'UsePress'} );
		} # end if
	} # end if $$self{Equipment}
	return new openprint::Equipment() if ! $$self{Equipment};
	return $$self{Equipment};
} # end sub Equipment

sub runtime {
    my ( $self, $Equipment, $impressions, $speed, $pertains_to ) = @_;

	my $Project = $self->Project();
    my $qty_index = $Project->ordered_quantity_index();
    my $specs = $self->specs();
#$log->debug("Project Service runtime $$specs{ServiceType}");
    if ( $$specs{ProjectType} or ( $$specs{ServiceType} eq 'Signature' ) ) {
		my $time = openprint::Estimating::Printing::runtime( $Project, $specs, $Equipment, $impressions, $speed );
		return $$time{Total} if $time;
		return 0;
    } elsif ( $$specs{ServiceType} eq 'Cutting' ) {
        return openprint::Estimating::Cutting::runtime( $Project, $self, $Equipment, $qty_index, $impressions, $speed, $pertains_to );
    } elsif ( $$specs{ServiceType} eq 'Folding' ) {
       return openprint::Estimating::Folding::runtime( $Project, $self, $Equipment, $qty_index, $impressions, $speed, $pertains_to );
    } elsif ( $$specs{ServiceType} eq 'Drilling' ) {
        return openprint::Estimating::Drilling::runtime( $Project->id(), $$self{'service_id'}, $specs, $qty_index );
    } elsif ( sets::isin( $$specs{ServiceType}, 'SaddleStitching','LoopStitching' ) ) {
        return openprint::Estimating::Stitching::runtime( $Project, $self, $Equipment, $qty_index, $speed );
    } # end if

} # end sub get_runtime

sub delete {
	my ( $self ) = @_;
if ( ! $$self{project_id} ) {
	$openprint::log->error("Attempt to delete a Project Service with no project.");
	return;
} # end if
	my $ac = sql::start_transaction( $openprint::dbh );
	my $Project = $self->Project();
	$Project->lock();
	my $specs = $self->specs();
$openprint::log->warn("Deleting " . $self->service_type() . ' ' . $self->to_string() );
	sql::execute( undef, $openprint::dbh, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?}, @$self{'project_id','service_id'} );
	sql::execute( undef, $openprint::dbh, q{DELETE FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, @$self{'project_id', 'service_id'} );
$openprint::log->warn("Deleting Service from " . $Project->to_string() );
	delete $$Project{'Services'};
	delete $$Project{'signatures'};
	delete $$Project{'Signature'};
	delete $$Project{'service_types'};
	$Project->unlock();
	foreach my $Job ( openprint::ScheduledJob->find( project_id=>$$self{project_id}, 'service_id any'=>$$self{service_id} ) ) {
		$Job->save( { 
				service_id => [ sets::exclude( [ $$self{service_id} ], $Job->service_id() ) ],
				pertains_id => [ sets::exclude( [ $$self{service_id} ], $Job->pertains_id() ) ],
				} );
	} # end foreach Job
	foreach my $Job ( openprint::ScheduledJob->find( project_id=>$$self{project_id}, 'pertains_id any'=>$$self{service_id} ) ) {
		$Job->save( {
				pertains_id => [ sets::exclude( [ $$self{service_id} ], $Job->pertains_id() ) ],
				} );
	} # end foreach Job

	$Project->add_to_log( @openprint::session{'company_id','user_id'}, "Deleted service ".$self->ServiceType()->type() . " $$specs{ServiceName} " . join(' $', map { $$specs{"txtPrice$_"} } $Project->quantity_indexes() ). "." );
	sql::end_transaction( $openprint::dbh, $ac );
	return;
} # end sub delete

sub ordered_price {
	my $specs = $_[0]->specs();
	return $$specs{'txtPrice'.$_[0]->Project()->ordered_quantity_index()};
} # end sub ordered_price

sub overrides {
	my ( $self, $qty_index ) = @_;
	my $module = 'openprint::Estimating::'.$_[0]->ServiceType()->type();
	$module = 'openprint::Estimating::Printing' if $module eq 'openprint::Estimating::Signature';
	$module = 'openprint::Estimating::Printing' if $module eq 'openprint::Estimating::AdditionalSignature';
	$module = 'openprint::Estimating::Printing' if $module eq 'openprint::Estimating::';
	eval ( 'require '.$module.';' );
	if ( my $function = $module->can( 'has_overrides' ) ) {
		my $specs = $_[0]->specs();
		my @o = $function->( $self->Project(), $$self{'service_id'}, $specs, $qty_index );
		return @o;
	} else {
		$openprint::log->warn("No has_overrides for " . $_[0]->ServiceType()->type() );
	} # end if
	return ();
} # end sub overrides

sub summary {
	my ( $qty_index ) = @_;

	my $Project = $_[0]->Project();
	my $services = $Project->services();
	my $ServiceType = $_[0]->ServiceType( $_[0]{service_id} );
	return '' if ! $ServiceType->summary_visible();

	my $specs = $_[0]->specs;
	if ( $$specs{ServiceType} eq 'Signature' or ( $$specs{ServiceType} eq '' and ! $$specs{txtTotalPageQuantity}  ) ) {
		require openprint::Estimating::Printing;
		return openprint::Estimating::Printing::summary($Project, $_[0]{service_id}, $specs, $qty_index );
	} elsif ( sets::isin( $$specs{ServiceType}, ['ShrinkWrap','KraftWrap','Bundling','Banding','CrossBanding'] ) ) {
		require openprint::Estimating::Packaging;
		return openprint::Estimating::Packaging::summary($Project, $_[0]{service_id}, $specs, $qty_index );
	} elsif ( sets::isin( $$specs{ServiceType}, ['SaddleStitching','LoopStitching'] ) ) {
		require openprint::Estimating::Stitching;
		return openprint::Estimating::Stitching::summary($Project, $_[0]{service_id}, $specs, $qty_index );
	} else {
		my $ServiceTypeType = $ServiceType->type();
		return if ! $ServiceTypeType;

		eval('require openprint::Estimating::'.$ServiceTypeType.';' );
		$openprint::log->error("ERror requiring openprint::Estimating::$ServiceTypeType ::summary: $@)") if $@;
		my $summary = eval('openprint::Estimating::'.$ServiceTypeType.'::summary( $Project, $_[0]{service_id}, $specs, $qty_index );' );
		$openprint::log->error("ERror evalling openprint::Estimating:: $ServiceTypeType ::summary: $@)") if $@;
		return $summary;
	} # end if
	return;
} # end sub summary

1;
__END__
