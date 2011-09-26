use strict;
package openprint::Project_Service;
our @ISA = qw(openprint::Object);

use openprint ();

require openprint::Project;
require openprint::User;
require openprint::ServiceType;

use vars qw( $log $dbh $debug %fields %find_fields %transforms %defaults $table $serial @identified_by );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$debug = 0;
%fields = (
	'service_id'	=>	'lngserviceindex',
	'project_id'	=>	'lngprojectindex',
	'operator_id'	=>	'operator_id',
	'status'		=>	'strstatus',
	'servicetype_id'	=>	'servicetype_id',
	'created_on'	=>	'dtmlastmodified',
);
%find_fields = (
	'category'	=>	'(SELECT ServiceType_Categories.name FROM ServiceType_Categories,Service_Types WHERE ServiceType_Categories.id=Service_Types.category_id AND Service_Types.id=servicetype_id)',
);
%transforms = (
);
%defaults = (
	'operator_id'	=>	undef,
	'created_on'	=>	q`'NOW()'`,
);
$table = 'tbl_project_contents';
$serial = 'ContentsServiceIndex_seq';
@identified_by = ( 'project_id', 'service_id' );

sub Project {
	return new openprint::Project( $_[0]{'project_id'} );
} # end sub Project

sub Operator {
	return new openprint::User( $_[0]{'operator_id'} );
} # end sub Operator

sub specs {
	if ( ! $_[0]{'specs'} ) {
		$_[0]{'specs'} = openprint::service::get_specs_ref( $_[0]->Project(), $_[0]{'service_id'} );
	} # end if
	return $_[0]{'specs'};
} # end sub specs

sub ServiceType {
	return new openprint::ServiceType( $_[0]{'servicetype_id'} );
} # end sub ServiceType

sub Equipment {
	my ( $self, $qty_index ) = @_;

	if ( ! $qty_index ) { 
		# Want ordered quantity
		$qty_index = $self->Project()->ordered_quantity_index();
	} # end if
	my $specs = $self->specs();
	if ( $self->ServiceType()->name() eq 'Cutting' ) {
		return openprint::Equipment->find_one(
				'use_in_scheduling'=>1,
				'Specifications'=>{'Cutting Capable'=>'Y'},
				);
	} elsif ( $self->ServiceType()->name() eq 'Folding' ) {
		return openprint::Equipment->find_one(
				'use_in_scheduling'=>1,
				'Specifications'=>{'Folding Capable'=>'Y'},
				);
	} elsif ( $self->ServiceType()->name() eq 'Stitching' ) {
		if ( $$specs{'ddmEquipment'.$qty_index} ) {
			return new openprint::Equipment( $$specs{'ddmEquipment'.$qty_index} );
		} else {
		return openprint::Equipment->find_one(
				'use_in_scheduling'=>1,
				'Specifications'=>{'Stitching Capable'=>'Y'},
				);
		} # end if
	} # end if
} # end sub Equipment

sub runtime {
    my ( $self, $Equipment, $impressions, $speed, $pertains_to ) = @_;

	my $Project = $self->Project();
    my $qty_index = $Project->ordered_quantity_index();
    my $specs = $self->specs();
$log->debug("Project Service runtime $$specs{'ServiceType'}");
    if ( $$specs{'ProjectType'} or ( $$specs{'ServiceType'} eq 'AdditionalSignature' ) ) {
		my $time = openprint::Estimating::Printing::runtime( $Project, $specs, $Equipment, $impressions, $speed );
		return $$time{'Total'} if $time;
		return 0;
    } elsif ( $$specs{'ServiceType'} eq 'Cutting' ) {
        return openprint::Estimating::Cutting::runtime( $Project, $self, $Equipment, $qty_index, $impressions, $speed, $pertains_to );
    } elsif ( $$specs{'ServiceType'} eq 'Folding' ) {
       return openprint::Estimating::Folding::runtime( $Project, $self, $Equipment, $qty_index, $impressions, $speed, $pertains_to );
    } elsif ( $$specs{'ServiceType'} eq 'Drilling' ) {
        return openprint::Estimating::Drilling::runtime( $Project->id(), $$self{'service_id'}, $specs, $qty_index );
    } elsif ( sets::isin( $$specs{'ServiceType'}, 'SaddleStitching','LoopStitching' ) ) {
        return openprint::Estimating::Stitching::runtime( $Project, $self, $Equipment, $qty_index, $speed );
    } # end if

} # end sub get_runtime

sub delete {
	my ( $self ) = @_;
	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( undef, $openprint::dbh, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=?}, @$self{'project_id','service_id'} );
	sql::execute( undef, $openprint::dbh, q{DELETE FROM tbl_Project_Contents WHERE lngProjectIndex=? AND lngServiceIndex=?}, @$self{'project_id', 'service_id'} );
	my $Project = $self->Project();
	delete $$Project{'Services'};
	delete $$Project{'signatures'};
	delete $$Project{'service_types'};
	my $Job = openprint::ScheduledJob->find_one('project_id'=>$$self{'project_id'}, 'service_id'=>$$self{'service_id'} );
	$Job->save( { 'service_id' => [ sets::exclude( [ $$self{'service_id'} ], $Job->service_id() ) ] } ) if $Job;
	sql::end_transaction( $openprint::dbh, $ac );
} # end sub delete

sub ordered_price {
	my $specs = $_[0]->specs();
	return $$specs{'txtPrice'.$_[0]->Project()->ordered_quantity_index()};
} # end sub ordered_price

1;
__END__
