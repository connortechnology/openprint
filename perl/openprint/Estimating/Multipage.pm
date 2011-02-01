# Copyright (C) 2007 Isaac Connor <isaac@connortechnology.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

package openprint::Estimating::Multipage;

use POSIX qw{ ceil };
use strict;

require openprint::Estimating::Printing;
require openprint::service;
require sets;

my $debug = 0;

my %variables = (
	'ddmProjectSize'=>['save','output'],
	'txtFinalWidth'=>['save'],'txtFinalHeight'=>['save'], 
	'txtWidth'=>['save','output'],'txtHeight'=>['save','output'],
	'txtTotalPageQuantity'=>['save'], 
	'rdbCover'=>['save','output'],
	'txtGateFoldedSpreadQuantity'=>['save','output'],
	'txtInsertQuantity'=>['save'],
	'TippingQuantity'=>['save'],
	'BlowingQuantity'=>['save'],
	'ReplyCardQuantity'=>['save'],
	'txtSpreadSize'=>['save','output'],'PrintingType'=>['save'],'rdbTemplateType'=>['save'],
	'help'=>['output'],'alert'=>['output'],
	'ProjectIndex'=>[], 'ServiceIndex'=>[], 'ServiceType'=>[], 'NewBook'=>[],
	'remaining_pages'=>['output'],'next_group_id'=>['output'],'groups'=>['output'],
);

sub variables {
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k if sets::isin( 'save', $variables{$k} );
	} # end foreach;
	return @v;
} # end sub variables

sub no_outputs {
    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k, if ! sets::isin( 'output', $variables{$k} );
    } # end foreach;
    return @v;
}


sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	if ( sets::isin( $$specs{'rdbTemplateType'}, ['SaddleStitching', 'LoopStitching', 'MetalCoil','PlasticCoil','PlasticComb','DoubleLoopWire'] ) ) {
		$$specs{'txtSpreadSize'} = 4;
	} elsif ( sets::isin( $$specs{'rdbTemplateType'}, ['CornerStitching','PerfectBound','SpinePaste'] ) ) {
		$$specs{'txtSpreadSize'} = 2;
	} else {
		$$specs{'txtSpreadSize'} = 2;
	} # end if
	
	if ( $$specs{'rdbTemplateType'} eq 'PerfectBound' and $$specs{'rdbCover'} ne 'Different' ) {
		$variables{'rdbCover'} = [sets::union('output', @{$variables{'rdbCover'}})];
		$$specs{'rdbCover'} = 'Different';
	} elsif ( $$specs{'rdbTemplateType'} eq 'SpinePaste' and $$specs{'rdbCover'} eq 'Different' ) {
		$variables{'rdbCover'} = [sets::union('output', @{$variables{'rdbCover'}})];
		$$specs{'rdbCover'} = 'Self';
	} # end if

	my @Groups = sql::execute( undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?', $project_index, 'Group' );
	if ( $$specs{'rdbCover'} eq 'Different' ) {
		if ( ! sets::isin( 1, \@Groups ) ) {
			push @Groups, 1;
		} # end if
	} else {
		@Groups = sets::exclude( [1], \@Groups );
	} # end if
	if ( ! sets::isin( 2, \@Groups ) ) {
		push @Groups, 2;
	} # end if
	if ( $$specs{txtGateFoldedSpreadQuantity} and ! sets::isin( 3, \@Groups ) ) {
		push @Groups, 3;
	} # end if

	my $Project = new openprint::Project( $project_index );

	my $remaining_pages = $$specs{'txtTotalPageQuantity'};
	my %override_pages;
$openprint::log->debug("Groups: @Groups");
	foreach my $group_id ( @Groups ) {
$openprint::log->debug("Group: $group_id, remaining: $remaining_pages, $override_pages{$group_id}");
		if ( $override_pages{$group_id} ) {
# DO nothing
		} elsif ( exists $$specs{'OverrideGroupPageQuantity'.$group_id} ) {
			$override_pages{$group_id} = $$specs{'GroupPageQuantity'.$group_id} if $$specs{'OverrideGroupPageQuantity'.$group_id} eq 'Y';
		} elsif ( $$specs{'txtSignatureType'.$group_id} eq 'PerfReplyCard' ) {
			$override_pages{$group_id} = 2;
			if ( $$specs{'txtServiceDescription'.$group_id} eq 'Interior Pages' ) {
				$$specs{'txtServiceDescription'.$group_id} = 'Perforated Reply Card';
			} # end if
		} else {
			foreach my $sig_id ( $Project->signatures({'Group'=>$group_id}) ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
				$override_pages{$group_id} = $$sig_specs{'GroupPageQuantity'} if $$sig_specs{'OverrideGroupPageQuantity'} eq 'Y';
				last if $override_pages{$group_id};
			} # end foreach signature
		} # end if
		$remaining_pages -= $override_pages{$group_id};
	} # end foreach group

	# if there is a cover, then force it to be non-zero
	if ( (! $override_pages{1} ) and ($$specs{'OverrideGroupPageQuantity1'} ne 'Y' ) and ($$specs{'rdbCover'} eq 'Different') ) {
		my $new_remaining = int(($remaining_pages-4) / $$specs{'txtSpreadSize'} ) * $$specs{'txtSpreadSize'};
		$override_pages{1} = $remaining_pages - $new_remaining;
		$remaining_pages = $new_remaining;
	} # end if

	foreach my $group_id ( @Groups ) {
$openprint::log->debug("Group: $group_id, remaining: $remaining_pages, $override_pages{$group_id}");
		openprint::Estimating::Printing::get_colours( $specs, 'SideOne', \%variables, $group_id );
		openprint::Estimating::Printing::get_colours( $specs, 'SideTwo', \%variables, $group_id );
		openprint::Estimating::Printing::get_inkcoverage( $specs, \%variables, $group_id );
		if ( ! exists $override_pages{$group_id} ) {
			$override_pages{$group_id} = $remaining_pages;
			$remaining_pages = 0;
		} # end if
		$$specs{'GroupPageQuantity'.$group_id} = $override_pages{$group_id};
		if ( $$specs{'chkOverrideDimensions'.$group_id} ne 'Y' ) {
			$$specs{'txtFinalWidth'.$group_id} = $$specs{'txtFinalWidth'};
			$$specs{'txtFinalHeight'.$group_id} = $$specs{'txtFinalHeight'};
		} # end if
	} # end foreach group_id

	if ( $$specs{'remaining_pages'} = $remaining_pages ) {
		my $max_group = 0;
		foreach my $g_id ( @Groups ) {
			if ( $g_id > $max_group ) {
				$max_group = $g_id;
			} # end if
		} # end foreach g_id
		$max_group += 1;
		push @Groups, $max_group;
		$$specs{'GroupPageQuantity'.$max_group} = $remaining_pages;
	} # end if
	$$specs{'groups'} = join(',', @Groups );

	if ( ! ( $$specs{'txtFinalWidth'} or $$specs{'txtFinalHeight'} ) ) {
		$$specs{'alert'} = 'Please select the dimensions.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	$$specs{'txtHeight'} = $$specs{'txtFinalHeight'};
	if ( $$specs{'txtSpreadSize'} == 2 ) {
		$$specs{'txtWidth'} = $$specs{'txtFinalWidth'};
	} elsif ( $$specs{'txtSpreadSize'} == 4 ) {
		$$specs{'txtWidth'} = 2*$$specs{'txtFinalWidth'};
	} # end if

	if ( ( $$specs{'txtWidth'} < $$specs{'txtFinalWidth'} ) or ( $$specs{'txtHeight'} < $$specs{'txtFinalHeight'} ) ) {
		$$specs{'alert'} .= 'Flat size cannot be smaller than finished size!';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	if ( ! $$specs{'txtTotalPageQuantity'} ) {
		$$specs{'alert'} = 'Please enter the # of pages';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	if ( ! $$specs{'rdbCover'} ) {
		$$specs{'alert'} = 'Please select the cover type.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	if ( $$specs{'rdbCover'} eq 'Different') {
		if ( sets::isin($$specs{'rdbTemplateType1'}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
			if ( $$specs{'rdbPocketSize1'} and ( $$specs{'rdbPocketSize1'} ne 'Other' ) ) {
				$$specs{'PocketSize1'} = $$specs{'rdbPocketSize1'};	
			} else {
				delete $$specs{'PocketSize1'};
			} # end if
			if ( ! $$specs{'rdbPanels1'} ) {
				$$specs{'alert'} .= 'Please select the number of panels.';
				return $$specs{'Status'} = 'uncalculated';
			} elsif ( ! $$specs{'rdbPocketSize1'} ) {
				$$specs{'alert'} .= 'Please select the size of the pockets.';
				return $$specs{'Status'} = 'uncalculated';
			} elsif ( ! ( $$specs{'chkPocketCenter1'} or $$specs{'chkPocketLeft1'} or $$specs{'chkPocketRight1'} ) ) {
				$$specs{'alert'} .= 'Please select where you would like the pockets.';
				return $$specs{'Status'} = 'uncalculated';
			} # end if
		} # end if
	} # end if

	foreach my $sig_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		my %new_specs = %{$sig_specs};
		openprint::Estimating::Printing::set_size( $Project, \%new_specs, $specs );
		foreach my $k ( 'txtWidth','txtHeight','txtFinalWidth','txtFinalSize' ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, $k, $new_specs{$k} );
		} # end foreach k
	} # end foreach

	return $$specs{'Status'} = 'calculated';
} # end sub calc

sub calculate_signatures {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	my $status;
$openprint::log->debug("****************************************************************Starting Multipage::calculate_signatures");
	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

	my @signatures = sort $Project->signatures({'type'=>'Interior Pages'});
	push @signatures, sort $Project->signatures({'type'=>'Cover Pages'});
	push @signatures, sort $Project->signatures({'type'=>'Gate Folded Pages'});
	@signatures = $Project->signatures() if ! @signatures;
$openprint::log->debug( "Signature: @signatures");

	# If we have a specified printing type, then .... if any of the sigs aren't of the same printing type is this even neccessary? 
	for ( my $i = 0; $i < @signatures; $i += 1 ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signatures[$i] );

		if ( $$printing_specs{'PrintingType'} ) {
			if ( 
				 ( $Project->quantity1() and ( $$sig_specs{'PrintingType1'} ne $$printing_specs{'PrintingType'} ) )
				 or ( $Project->quantity2() and ( $$sig_specs{'PrintingType2'} ne $$printing_specs{'PrintingType'} ) )
					or ( $Project->quantity3() and ( $$sig_specs{'PrintingType3'} ne $$printing_specs{'PrintingType'}  ) )
) {
# delete any similar signs
				#$log->debug("Getting rid of extra sigs");
				for ( my $j = $i+1; $j < @signatures; $j += 1 ) {
					my $specs2 = openprint::service::get_specs_ref( $Project, $signatures[$j] );
					if ( openprint::Estimating::Printing::compare_signatures( $sig_specs, $specs2 ) ) {
#$openprint::log->warn('Deleting due to incorrect printing type');
						openprint::print_project::delete_service( $log, $dbh, $project_index, $signatures[$j] );
						splice @signatures, $j, 1;
						$j-=1;
					} # end if
				} # end for
			} # end if
		} # end if
	} # end for

	my @groups = sort( sql::execute(undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strname=?', $Project->id(), 'Group' ) );
	if ( ! @groups ) {
		foreach my $ss_id ( $Project->signatures() ) {
			my $sig_specs = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $ss_id, 'Printing' );
			if ( $$sig_specs{'Status'} ne 'calculated' ) {
				return 'uncalculated';
			} # end if
		} # end if
	} else {
		my @printing_types = sql::execute( undef, undef, q{SELECT DISTINCT strValue FROM tbl_Equipment_Specifications WHERE strName='Printing Type' } );
		foreach my $group ( @groups ) {
			my @sigs = sort $Project->signatures( {'Group'=>$group} );
			$openprint::log->debug("Sigs in group $group : @sigs " );
			next if ! @sigs;
			my $ss_id = shift @sigs;
			$openprint::log->debug("Calcing $ss_id");
			my $sig_specs = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $ss_id, 'Printing' );
			$openprint::log->debug("Done Calcing $ss_id $$sig_specs{'Status'}");
			
			if ( $$sig_specs{'Status'} eq 'calculated' ) {
				$status = $$sig_specs{'Status'};
# Successfully calculated the first sig
# In sig_specs should be an array of Impositions to apply to other signatures, so let's add/delete/apply

				while ( 
						( $$sig_specs{'Additional Impositions1'} and @{$$sig_specs{'Additional Impositions1'}} ) or
						( $$sig_specs{'Additional Impositions2'} and @{$$sig_specs{'Additional Impositions2'}} ) or
						( $$sig_specs{'Additional Impositions3'} and @{$$sig_specs{'Additional Impositions3'}} ) ) {
					if ( ! @sigs ) {
						push @sigs, copy_signature( $project_index, $sig_specs );
					} # endif
$openprint::log->debug("Saving additional imposition");
					my $a_ss_id = shift @sigs;
					my $new_sig_specs = openprint::service::get_specs_ref( $Project, $a_ss_id );
					my %specs = %{$new_sig_specs};
					openprint::Estimating::Printing::calc_from_imposition( $Project, $a_ss_id, \%specs, $sig_specs );

					my $ac = sql::start_transaction( $openprint::dbh );
					sql::update( undef, undef, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $a_ss_id], 'strStatus', $status );

					foreach my $key ( openprint::Estimating::Printing::variables( $project_index, $a_ss_id, $new_sig_specs, \%specs ) ) {
						openprint::service::insert_service_spec( $log, undef, $project_index, $a_ss_id, $key, $specs{$key} );
					} # end foreach
					sql::end_transaction( $openprint::dbh, $ac );

				} # end while Additional Imposition

# Clean up any leftovers
				$openprint::log->debug("Remaining sigs " . @sigs);
				while ( @sigs and ( my $ss_id = shift @sigs ) ) {
					openprint::print_project::delete_service( $log, $dbh, $project_index, $ss_id );
					@signatures = sets::exclude( [ $ss_id ], \@signatures );
				} # end while sigs
			} else {
				$openprint::log->debug("uncomplete status: $$sig_specs{'Status'} alert: $$sig_specs{'alert'}");
				return 'uncalculated';
			} # end if
		} # end foreach group
	} # end if no groups

	return 'calculated';
} # end sub calculate_signatures

# Returns the # of needed remaining spreads... 
sub status {
	my ( $project_index, $printing_specs, $qty_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	if ( $$services{''} and @{$$services{''}} and ! $printing_specs ) {
		$printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	} # end if
	if ( ! $printing_specs ) {
		$printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
		$openprint::log->debug("Estimating::Multopage::status : No printing_specs");
		return if ! $printing_specs;
	} # end if

    my $total_pages = $$printing_specs{'txtTotalPageQuantity'};
	my %specified_pages;
	my %needed_pages;
	foreach my $ssid ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ssid );
		$specified_pages{$$sig_specs{'Group'}} += $$sig_specs{"PageQuantity$qty_index"};
		$needed_pages{$$sig_specs{'Group'}} = $$sig_specs{'GroupPageQuantity'.$qty_index};
	} # end foreach
	my @Groups = sql::execute( undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?', $project_index, 'Group' );
	foreach my $Group ( @Groups ) {
		if ( $needed_pages{$Group} > $specified_pages{$Group} ) {
			return $Group;
		} # end if
	} # end foreach
	return;
} # end sub status
        
sub copy_signature {
	my ( $project_index, $sig_specs ) = @_;
$openprint::log->debug("ADding signature");
	my $Project = new openprint::Project( $project_index );
	my $new_service_index = openprint::print_project::insert_service( $openprint::log, $openprint::dbh, $project_index, 'AdditionalSignature' );
	my $new_specs = openprint::service::get_specs_ref( $Project, $new_service_index );
	my $ac = sql::start_transaction( $openprint::dbh );
	$openprint::dbh->do( 'LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE' ) or $openprint::log->error( DBI->errstr );
	$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
	my ( $sig_index ) = sql::execute( undef, undef, $_, $project_index );
	$sig_index += 1;
	openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $project_index, $new_service_index, 'SignatureIndex', $sig_index );

	# Releases the lock
	$openprint::dbh->commit();

	foreach my $key ( openprint::Estimating::Printing::variables( $project_index, undef, undef, $sig_specs ) ) {
		openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $project_index, $new_service_index, $key, $$sig_specs{$key}, ! exists $$new_specs{$key} );
	} # end foreach

	sql::end_transaction( $openprint::dbh, $ac );
	return $new_service_index;
} # end sub copy_signature

sub save {
} # end sub save

1;
__END__
