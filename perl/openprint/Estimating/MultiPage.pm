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

package openprint::Estimating::MultiPage;

use POSIX qw{ ceil };
use strict;

require openprint::Estimating::Printing;
require openprint::service;
require sets;

use constant DEBUG => 0;

use vars qw{ @signature_variables };

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
	'PrintingType'=>['save'],'rdbTemplateType'=>['save'],
	'help'=>['output'],'alert'=>['output','save'],
	'ProjectIndex'=>[], 'ServiceIndex'=>[], 'ServiceType'=>[], 'NewBook'=>[],
	'remaining_pages'=>['output'],'next_group_id'=>['output'],'groups'=>['output','save'],
	spine	=>	 ['save'],

	);

@signature_variables = (
'chkCyanSideOne','chkMagentaSideOne','chkYellowSideOne','chkBlackSideOne', 'chkProcessColourSideOne',
                'chkColourCoating1SideOne', 'ColourCoatingType1SideOne', 'ColourCoatingColour1SideOne','ColourCoatingCoverage1SideOne',
                'chkColourCoating2SideOne', 'ColourCoatingType2SideOne', 'ColourCoatingColour2SideOne','ColourCoatingCoverage2SideOne',
                'chkColourCoating3SideOne', 'ColourCoatingType3SideOne', 'ColourCoatingColour3SideOne','ColourCoatingCoverage3SideOne',
                'chkColourCoating4SideOne', 'ColourCoatingType4SideOne', 'ColourCoatingColour4SideOne','ColourCoatingCoverage4SideOne',
                'chkColourCoating5SideOne', 'ColourCoatingType5SideOne', 'ColourCoatingColour5SideOne','ColourCoatingCoverage5SideOne',
                'chkColourCoating6SideOne', 'ColourCoatingType6SideOne', 'ColourCoatingColour6SideOne','ColourCoatingCoverage6SideOne',
                'chkColourCoating7SideOne', 'ColourCoatingType7SideOne', 'ColourCoatingColour7SideOne','ColourCoatingCoverage7SideOne',
                'chkColourCoating8SideOne', 'ColourCoatingType8SideOne', 'ColourCoatingColour8SideOne','ColourCoatingCoverage8SideOne',
                'chkColourCoating9SideOne', 'ColourCoatingType9SideOne', 'ColourCoatingColour9SideOne','ColourCoatingCoverage9SideOne',
                'chkCyanSideTwo','chkMagentaSideTwo','chkYellowSideTwo','chkBlackSideTwo', 'chkProcessColourSideTwo',
                'chkColourCoating1SideTwo', 'ColourCoatingType1SideTwo', 'ColourCoatingColour1SideTwo','ColourCoatingCoverage1SideTwo',
                'chkColourCoating2SideTwo', 'ColourCoatingType2SideTwo', 'ColourCoatingColour2SideTwo','ColourCoatingCoverage2SideTwo',
                'chkColourCoating3SideTwo', 'ColourCoatingType3SideTwo', 'ColourCoatingColour3SideTwo','ColourCoatingCoverage3SideTwo',
                'chkColourCoating4SideTwo', 'ColourCoatingType4SideTwo', 'ColourCoatingColour4SideTwo','ColourCoatingCoverage4SideTwo',
                'chkColourCoating5SideTwo', 'ColourCoatingType5SideTwo', 'ColourCoatingColour5SideTwo','ColourCoatingCoverage5SideTwo',
                'chkColourCoating6SideTwo', 'ColourCoatingType6SideTwo', 'ColourCoatingColour6SideTwo','ColourCoatingCoverage6SideTwo',
                'chkColourCoating7SideTwo', 'ColourCoatingType7SideTwo', 'ColourCoatingColour7SideTwo','ColourCoatingCoverage7SideTwo',
                'chkColourCoating8SideTwo', 'ColourCoatingType8SideTwo', 'ColourCoatingColour8SideTwo','ColourCoatingCoverage8SideTwo',
                'chkColourCoating9SideTwo', 'ColourCoatingType9SideTwo', 'ColourCoatingColour9SideTwo','ColourCoatingCoverage9SideTwo',
                'CyanSpotSideOneCoverage', 'MagentaSpotSideOneCoverage', 'YellowSpotSideOneCoverage', 'BlackSpotSideOneCoverage',
                'CyanSideOneCoverage', 'MagentaSideOneCoverage', 'YellowSideOneCoverage', 'BlackSideOneCoverage',
                'CyanSpotSideTwoCoverage', 'MagentaSpotSideTwoCoverage', 'YellowSpotSideTwoCoverage', 'BlackSpotSideTwoCoverage',
                'CyanSideTwoCoverage', 'MagentaSideTwoCoverage', 'YellowSideTwoCoverage', 'BlackSideTwoCoverage',
                'BleedLeft','BleedRight','BleedTop','BleedBottom','rdbColourBar','txtCropMarkSpace',
		'ddmRunStyle-', 'ddmPress-', 'PrintingType-', 'StockType-', 'txtPlateChangeQuantity-', 'PageQuantity-',
		'Pages', 'OverrideGroupPageQuantity', 'GroupPageQuantity', 'txtSignatureType',
		'chkOverrideDimensions', 'txtFinalHeight', 'txtFinalWidth', 'txtHeight', 'txtWidth',
		'rdbSpecificStock', 'rdbSuppliedStock',
		'ddmStockBrand', 'txtSpecificStockBrand',
		'ddmStockGroup', 'ddmStockQuality',
		'ddmStockFinish', 'txtSpecificStockFinish',
		'ddmStockColour', 'txtSpecificStockColour',
		'ddmStockWeight', 'txtSpecificStockWeight',
		'txtSpecificStockCalliper', 'StockType',
		'txtSpecificStockWidth', 'txtSpecificStockHeight', 
		'txtCustomMWeight', 'basis_mweight', 'basis_width', 'basis_height', 
		'CustomStockPrice', 'txtStockGSM','CustomSheetDoubleSided',
		'cuttable', 'perfecting', 'StockGrade', 'minimum_order','sheets_per_package',
		);

sub variables {
	my ( $project_id, $service_id, $specs, $incoming_specs ) = @_;
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k if sets::isin( 'save', $variables{$k} );
	} # end foreach;
	my @Groups = sql::execute( undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?', $project_id, 'Group' );
	foreach my $group_id ( @Groups ) {
		push @v, map { join('', $_,$group_id) } @signature_variables;
	} # end foreach group
	return @v;
} # end sub variables

sub no_outputs {
	my ( $project_index, $service_index, $specs ) = @_;
	my @v;
	my @outputs;
	foreach my $k ( keys %variables ) {
		if ( ! sets::isin( 'output', $variables{$k} ) ) {
			push @v, $k; 
		} else {
			push @outputs, $k;
		} # end if
    } # end foreach;
	my @groups = groups( $project_index, $specs );
	foreach my $Group ( @groups ) {
		my @no_outputs = openprint::Estimating::Printing::no_outputs( $project_index, $service_index, $specs, $Group );
		# Will come with signature appended
		push @v, sets::exclude( \@outputs, \@no_outputs );
	} # end foreach Group
    return @v;
}
sub outputs {
	my ( $project_index, $service_index, $specs ) = @_;
    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k, if sets::isin( 'output', $variables{$k} );
    } # end foreach;
	my @outputs = openprint::Estimating::Printing::outputs( $project_index, $service_index, $specs );
	foreach my $Group ( groups( $project_index, $specs ) ) {
		push @v, map { $_.$Group } @outputs;
		if ( ! $$specs{"chkOverrideDimensions$Group"} ) {
		push @v, map { $_.$Group } ( 'txtFinalWidth','txtFinalHeight' );
		}
	} # end foreach Group
    return @v;
}

sub groups {
	my ( $project_index, $specs ) = @_;
	my @Groups = sql::execute( undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?', $project_index, 'Group' );
	if ( $$specs{rdbCover} eq 'Different' ) {
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
	return @Groups;
} # end sub groups

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	$$specs{Status} = 'calculated';
	$$specs{alert} = '';

	if ( ! $$specs{rdbTemplateType} ) {
		$$specs{alert} .= 'Please select how this project will be bound.<br/>';
	} # end if

	if ( ! ( $$specs{txtFinalWidth} or $$specs{txtFinalHeight} ) ) {
		$$specs{alert} = 'Please select the dimensions.<br/>';
		$$specs{Status} = 'uncalculated';
	} # end if
	if ( ! $$specs{spine} ) {
		$$specs{spine} = 'height';
		$variables{spine} = ['save','output'];
	} # end if
	if ( $$specs{spine} eq 'width' ) {
		@$specs{'txtWidth','txtHeight'} = ( $$specs{txtFinalWidth}, 2*$$specs{txtFinalHeight} );
	} else {
		@$specs{'txtWidth','txtHeight'} = ( 2*$$specs{txtFinalWidth},$$specs{txtFinalHeight} );
	} # end if

	if ( $$specs{rdbTemplateType} eq 'PerfectBound' and $$specs{rdbCover} ne 'Different' ) {
		$variables{rdbCover} = [sets::union('output', @{$variables{rdbCover}})];
		$$specs{rdbCover} = 'Different';
	} elsif ( $$specs{rdbTemplateType} eq 'SpinePaste' and $$specs{rdbCover} ne 'Self' ) {
		$variables{rdbCover} = [sets::union('output', @{$variables{rdbCover}})];
		$$specs{rdbCover} = 'Self';
	} elsif ( ! $$specs{rdbCover} ) {
		$$specs{alert} .= "Please select self or different cover.<br/>";
		$$specs{Status} = 'uncalculated';
	} # end if

	my @Groups = sql::execute( undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?', $project_index, 'Group' );
	if ( $$specs{rdbCover} eq 'Different' ) {
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
	@Groups = sort { $a <=> $b } @Groups;

	my $Project = new openprint::Project( $project_index );
	if ( ! $$Project{id} ) {
		$$specs{alert} = 'Project not found.';
		$$specs{Status} = 'uncalculated';
	} # end if

	my $remaining_pages = $$specs{txtTotalPageQuantity};
	my %override_pages;
	foreach my $group_id ( @Groups ) {
		if ( exists $$specs{'OverrideGroupPageQuantity'.$group_id} ) {
			if ( $$specs{'OverrideGroupPageQuantity'.$group_id} eq 'Y' ) {
				$override_pages{$group_id} = $$specs{'GroupPageQuantity'.$group_id};
				$log->debug("Setting override pages for group $group_id to " . $$specs{'GroupPageQuantity'.$group_id} );
			} # end if
		} elsif ( $$specs{'txtSignatureType'.$group_id} eq 'PerfReplyCard' ) {
			$override_pages{$group_id} = 2;
			if ( $$specs{'txtServiceDescription'.$group_id} eq 'Interior Pages' ) {
				$$specs{'txtServiceDescription'.$group_id} = 'Perforated Reply Card';
			} # end if
		} else {
			if ( ! $group_id ) {
				$log->warn("NO GROUP ID $group_id");
			}
			my @g_signatures = $Project->signatures({Group=>$group_id});
			if ( ! @g_signatures ) {

				# calc shouldn't really alter the project.
				$Project->add_signature( undef, undef, {
						Group=>$group_id,
						( $group_id == 1 ? ( 'txtSignatureType'=>'Cover Pages', 'txtServiceDescription'=>'Cover' ) : () ),
						( $group_id == 2 ? ( 'txtSignatureType'=>'Interior Pages', 'txtServiceDescription'=>'Interior Pages' ) : () ),
						( $group_id == 3 ? ( 'txtSignatureType'=>'Gate Folded Pages', 'txtServiceDescription'=>'Gate Folded Pages' ) : () ),
						} );
			} # end if
			#foreach my $sig_id ( $Project->signatures({'Group'=>$group_id}) ) {
				#my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
				#$override_pages{$group_id} = $$sig_specs{GroupPageQuantity} if $$sig_specs{OverrideGroupPageQuantity} eq 'Y';
				#last if $override_pages{$group_id};
			#} # end foreach signature
		} # end if
		$remaining_pages -= $override_pages{$group_id};
		if ( $$specs{"PageQuantity-$group_id"} and ( $$specs{"PageQuantity-$group_id"} > $$specs{'GroupPageQuantity'.$group_id} ) ) {
			$$specs{alert} .= "You have specified to print more pages per signature than are required for group $group_id.<br/>";
		} # end if
	} # end foreach group

	# if there is a cover, then force it to be non-zero
	if ( (! $override_pages{1} ) and ($$specs{OverrideGroupPageQuantity1} ne 'Y' ) and ($$specs{rdbCover} eq 'Different') ) {
if ( 0 ) {
		# Ithink the idea here is to give the cover either 4 or 6 pages... depending on the total # of pages.
		my $new_remaining = int(($remaining_pages-4) / $$specs{txtSpreadSize} ) * $$specs{txtSpreadSize};
		$override_pages{1} = $remaining_pages - $new_remaining;
		$remaining_pages = $new_remaining;
} else {
		$override_pages{1} = 4;
		
		$remaining_pages -= $override_pages{1};
$openprint::log->warn("FIXM E");
} # end if
	} # end if
	$remaining_pages = 0 if $remaining_pages < 0;

	if ( ! $$specs{txtTotalPageQuantity} ) {
		$$specs{alert} = 'Please enter the # of pages<br/>';
		$$specs{Status} = 'uncalculated';
	} elsif ( $$specs{txtTotalPageQuantity} > 2000 ) {
		$$specs{alert} .= 'The maximum # of pages is 2000.<br/>';
		$$specs{Status} = 'uncalculated';
	} # end if

	if ( $$specs{remaining_pages} ) {
		$$specs{alert} .= 'There are ' . $$specs{remaining_pages} . ' unspecified pages.<br/>';
		$$specs{Status} = 'uncalculated';
	} # end if

	if ( ! $$specs{rdbCover} ) {
		$$specs{alert} = 'Please select the cover type.<br/>';
		$$specs{Status} = 'uncalculated';
	} # end if

	if ( $$specs{rdbCover} eq 'Different') {
		if ( sets::isin($$specs{rdbTemplateType1}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
			if ( $$specs{rdbPocketSize1} and ( $$specs{rdbPocketSize1} ne 'Other' ) ) {
				$$specs{PocketSize1} = $$specs{rdbPocketSize1};	
			} else {
				delete $$specs{PocketSize1};
			} # end if
			if ( ! $$specs{rdbPanels1} ) {
				$$specs{alert} .= 'Please select the number of panels.<br/>';
				$$specs{Status} = 'uncalculated';
			} elsif ( ! $$specs{rdbPocketSize1} ) {
				$$specs{alert} .= 'Please select the size of the pockets.<br/>';
				$$specs{Status} = 'uncalculated';
			} elsif ( ! ( $$specs{chkPocketCenter1} or $$specs{chkPocketLeft1} or $$specs{chkPocketRight1} ) ) {
				$$specs{alert} .= 'Please select where you would like the pockets.<br/>';
				$$specs{Status} = 'uncalculated';
			} # end if
		} # end if
	} # end if

	foreach my $group_id ( @Groups ) {
		$openprint::log->debug("Group: $group_id, remaining: $remaining_pages, override: $override_pages{$group_id}") if DEBUG;
		my %sig_specs =  map { $_, $$specs{$_.$group_id } } @signature_variables;
		
		openprint::Estimating::Printing::get_colours( $specs, 'SideOne', \%variables, $group_id );
		openprint::Estimating::Printing::get_colours( $specs, 'SideTwo', \%variables, $group_id );
		openprint::Estimating::Printing::get_inkcoverage( $Project, $specs, \%variables, $group_id );
		openprint::Estimating::Printing::get_Stocks( $Project, \%sig_specs, \%variables );
		openprint::Estimating::Printing::set_size( $Project, \%sig_specs, $specs );
		$$specs{alert} .= $sig_specs{alert} .' for group ' . $group_id . ' ' . $$specs{'txtServiceDescription'.$group_id}. '<br/>' if $sig_specs{alert};
		@$specs{map { $_.$group_id} @signature_variables} = @sig_specs{@signature_variables};
		if ( ! exists $override_pages{$group_id} ) {
			$override_pages{$group_id} = $remaining_pages;
			$remaining_pages = 0;
		} # end if
		$$specs{'GroupPageQuantity'.$group_id} = $override_pages{$group_id};
		if ( ! ( $variables{'GroupPageQuantity'.$group_id} and @{$variables{'GroupPageQuantity'.$group_id}} ) ) {
			$openprint::log->debug("Setting output on GroupPageQuantity$group_id") if DEBUG;
			$variables{'GroupPageQuantity'.$group_id} = [sets::union('output', @{$variables{'GroupPageQuantity'.$group_id}})];
		} # end if
		if ( $$specs{'chkOverrideDimensions'.$group_id} ne 'Y' ) {
			$$specs{'txtFinalWidth'.$group_id} = $$specs{txtFinalWidth};
			$$specs{'txtFinalHeight'.$group_id} = $$specs{txtFinalHeight};
		} # end if
		$openprint::log->debug("Group: $group_id, remaining: $remaining_pages, $override_pages{$group_id}") if DEBUG;
	} # end foreach group_id

	if ( $$specs{remaining_pages} = $remaining_pages ) {
		my $max_group = 0;
		foreach my $g_id ( @Groups ) {
			if ( $g_id > $max_group ) {
				$max_group = $g_id;
			} # end if
		} # end foreach g_id
		$max_group += 1;
		push @Groups, $max_group;
		$$specs{'GroupPageQuantity'.$max_group} = $remaining_pages;
		$$specs{'GroupPageQuantity'.$max_group} = '' if $$specs{'GroupPageQuantity'.$max_group} < 0;
	} # end if
	$$specs{groups} = join(',', @Groups );



	return $$specs{Status};
} # end sub calc

sub calculate_signatures {
	shift @_ if $_[0] eq 'openprint::Estimating::MultiPage::calculate_signatures';
	my $Project = $_[0];

	my $status;
$openprint::log->debug("****************************************************************Starting MultiPage::calculate_signatures");
	my $services = $Project->services();

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

	my @signatures = sort $Project->signatures({'type'=>'Interior Pages'});
	push @signatures, sort $Project->signatures({'type'=>'Cover Pages'});
	push @signatures, sort $Project->signatures({'type'=>'Gate Folded Pages'});
	@signatures = $Project->signatures() if ! @signatures;
	$openprint::log->debug( "Signatures: @signatures");
	return 'uncalculated' if ! @signatures;

	# If we have a specified printing type, then .... if any of the sigs aren't of the same printing type is this even neccessary? 
	for ( my $i = 0; $i < @signatures; $i += 1 ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signatures[$i] );

		# This has been deprecated
		if ( $$printing_specs{PrintingType} ) {
			if ( 
				 ( $Project->quantity1() and $$sig_specs{PrintingType1} and ( $$sig_specs{PrintingType1} ne $$printing_specs{PrintingType} ) )
				 or ( $Project->quantity2() and $$sig_specs{PrintingType2} and ( $$sig_specs{PrintingType2} ne $$printing_specs{PrintingType} ) )
					or ( $Project->quantity3() and $$sig_specs{PrintingType3} and ( $$sig_specs{PrintingType3} ne $$printing_specs{PrintingType}  ) )
) {
# delete any similar signs
				#$log->debug("Getting rid of extra sigs");
				for ( my $j = $i+1; $j < @signatures; $j += 1 ) {
					my $specs2 = openprint::service::get_specs_ref( $Project, $signatures[$j] );
					if ( openprint::Estimating::Printing::compare_signatures( $Project, $sig_specs, $specs2 ) ) {
#$openprint::log->warn('Deleting due to incorrect printing type');
						openprint::print_project::delete_service( $Project, $signatures[$j] );
						splice @signatures, $j, 1;
						$j-=1;
					} # end if
				} # end for
			} # end if
		} # end if
	} # end for

	my @groups = sort( sql::execute(undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strname=?', $$Project{id}, 'Group' ) );
	@groups = ( undef ) if ! @groups;

	foreach my $group ( @groups ) {
		my @sigs = sort( $Project->signatures( $group ? { Group=>$group } : () ) );
		$openprint::log->debug( "Sigs in group $group : @sigs " );
		next if ! @sigs;
		my $ss_id = shift @sigs;
		$openprint::log->debug("Calcing $ss_id");
		my $sig_specs = openprint::service::internal_calc( $openprint::log, $openprint::dbh, \%openprint::variable, $$Project{id}, $ss_id, 'Printing' );
		$openprint::log->debug("Done Calcing $ss_id $$sig_specs{Status}");
		
		if ( $$sig_specs{Status} eq 'calculated' ) {
			$status = $$sig_specs{Status};
# Successfully calculated the first sig
# In sig_specs should be an array of Impositions to apply to other signatures, so let's add/delete/apply
			$openprint::log->debug("MultiPage::calculate_signatures $status $$sig_specs{'Additional Impositions1'} $$sig_specs{'Additional Impositions2'} $$sig_specs{'Additional Impositions3'} ") if DEBUG;

			# Remove Impos for other groups
			foreach my $qty_index ( $Project->quantity_indexes() ) {
				if ( $$sig_specs{'Additional Impositions'.$qty_index} and @{$$sig_specs{'Additional Impositions'.$qty_index}} ) {
                    my $Imposition = $$sig_specs{'Additional Impositions'.$qty_index}[0];
					my $specs = $Imposition->specs();
					if ( $$specs{Group} and ( $$specs{Group} != $group ) ) {
$openprint::log->debug("Removing impo cuz wrong group") if DEBUG;
						shift @{$$sig_specs{'Additional Impositions'.$qty_index}};
					} # end if
				} # end if
			} # end foreach

			while ( 
					( $$sig_specs{'Additional Impositions1'} and @{$$sig_specs{'Additional Impositions1'}} ) or
					( $$sig_specs{'Additional Impositions2'} and @{$$sig_specs{'Additional Impositions2'}} ) or
					( $$sig_specs{'Additional Impositions3'} and @{$$sig_specs{'Additional Impositions3'}} ) ) {

				if ( ! @sigs ) {

					push @sigs, $Project->copy_signature( $sig_specs, {
							'chkOverrideImposition1' => '',
							'chkOverrideImposition2' => '',
							'chkOverrideImposition3' => '',
							'chkOverridePageQuantity1' => '',
							'chkOverridePageQuantity2' => '',
							'chkOverridePageQuantity3' => '',
							'chkOverridePress1' => '',
							'chkOverridePress2' => '',
							'chkOverridePress3' => '',
							'chkOverrideRunStyle1' => '',
							'chkOverrideRunStyle2' => '',
							'chkOverrideRunStyle3' => '',
							'chkOverrideSheetSize1' => '',
							'chkOverrideSheetSize2' => '',
							'chkOverrideSheetSize3' => '',
					},'calculated' );

				} # endif
				$openprint::log->debug("Saving additional impositions1 " . @{$$sig_specs{'Additional Impositions1'}} ) if $$sig_specs{'Additional Impositions1'} and @{$$sig_specs{'Additional Impositions1'}};
				$openprint::log->debug("Saving additional impositions2 " . @{$$sig_specs{'Additional Impositions2'}} ) if $$sig_specs{'Additional Impositions2'} and @{$$sig_specs{'Additional Impositions2'}};
				$openprint::log->debug("Saving additional impositions3 " . @{$$sig_specs{'Additional Impositions3'}} ) if $$sig_specs{'Additional Impositions3'} and @{$$sig_specs{'Additional Impositions3'}};
				my $a_ss_id = shift @sigs;
				my $new_sig_specs = openprint::service::get_specs_ref( $Project, $a_ss_id );
				my %specs = %{$new_sig_specs};

				foreach my $qty_index ( $Project->quantity_indexes() ) {
					my $Imposition;
					if ( ! ( $$sig_specs{'Additional Impositions'.$qty_index} and @{$$sig_specs{'Additional Impositions'.$qty_index}} ) ) {
						$specs{'ddmPress'.$qty_index} = '' if $specs{'chkOverridePress'.$qty_index} ne 'Y';
						$specs{'PageQuantity'.$qty_index} = '' if $specs{'chkOverridePageQuantity'.$qty_index} ne 'Y';
						$specs{'txtImposition'.$qty_index} = '';
						$specs{'StockType'.$qty_index} = '';
						$specs{'StockWidth'.$qty_index} = '';
						$specs{'StockHeight'.$qty_index} = '';
						$specs{'txtPressSheetQty'.$qty_index} = 0;
						$specs{'hdnNetSheetCount'.$qty_index} = 0;
						$specs{'StockQuantity'.$qty_index} = 0;
						if ( $specs{'OverridePrice'.$qty_index} ne 'Y' ) {
							$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{ProjectMoneyFormat}, 0 );
						} # end if
						$specs{'txtUnitPrice'.$qty_index} = sprintf($openprint::config{UnitPriceFormat}, 0 );
			#$$openprint::log->debug("no additional impos for qty $qty_index");
						$Imposition = new openprint::Imposition();
						$$Imposition{paper} = new openprint::Paper();
					} else {
						$Imposition = shift @{$$sig_specs{'Additional Impositions'.$qty_index}};
					} # end if
					if ( ref $Imposition ne 'openprint::Imposition' ) {
						cluck( "Bad Imposition! $Imposition" );
						$status = 'uncalculated';
						next;
					} # end if
					
					my $price = $$Imposition{price};
					$Imposition->display("Saving for $qty_index");
					if ( $specs{"chkOverrideImposition$qty_index"} eq 'Y' and $specs{"txtImposition$qty_index"} != $$Imposition{imposition} ) {
						$status = 'uncalculated';
					} else {
						$Imposition->save( \%specs, $qty_index );
						openprint::Estimating::Printing::save_price( $Project, \%specs, $price, $Imposition, $qty_index );
					}
					$specs{'hdnBreakdown'.$qty_index} = openprint::Estimating::Printing::breakdown( $price, \%specs );
					
				} # end foreach qty_index
#foreach my $k ( keys %specs ) {
#foreach my $k ( 'txtImposition1' ) {
	#$openprint::log->debug("specs: $k $$new_sig_specs{$k} $specs{$k}");
#}
				
				#openprint::Estimating::Printing::calc_from_imposition( $Project, $a_ss_id, \%specs, $sig_specs );
				my $ac = sql::start_transaction( $openprint::dbh );
				sql::update( undef, undef, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $$Project{id}, $a_ss_id], 'strStatus', $status );

				foreach my $key ( sort { $a cmp $b } ( openprint::Estimating::Printing::variables( $$Project{id}, $a_ss_id, $new_sig_specs, \%specs ) ) ) {
					openprint::service::insert_service_spec( $openprint::log, undef, $$Project{id}, $a_ss_id, $key, $specs{$key} );
				} # end foreach
				sql::end_transaction( $openprint::dbh, $ac );

			} # end while Additional Imposition

# Clean up any leftovers XXX Could be written better, such a small gain though
			$openprint::log->debug("Remaining sigs " . @sigs . " @sigs");
			while ( @sigs and ( my $ss_id = shift @sigs ) ) {
				my $Service = $Project->Service( $ss_id );
				$Service->delete();
				@signatures = sets::exclude( [ $ss_id ], \@signatures );
			} # end while sigs
		} else {
			$openprint::log->warn("uncomplete status: $$sig_specs{Status} alert: $$sig_specs{alert}");
			return 'uncalculated';
		} # end if
	} # end foreach group

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
		$openprint::log->debug("Estimating::Multipage::status : No printing_specs");
		return if ! $printing_specs;
	} # end if

    my $total_pages = $$printing_specs{txtTotalPageQuantity};
	my %specified_pages;
	my %needed_pages;
	foreach my $ssid ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ssid );
		$specified_pages{$$sig_specs{Group}} += $$sig_specs{"PageQuantity$qty_index"};
		$needed_pages{$$sig_specs{Group}} = $$sig_specs{GroupPageQuantity};
	} # end foreach
	my @Groups = sql::execute( undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?', $project_index, 'Group' );
	foreach my $Group ( @Groups ) {
		if ( $needed_pages{$Group} > $specified_pages{$Group} ) {
			return $Group;
		} # end if
	} # end foreach
	return;
} # end sub status
        
sub save {
#$openprint::log->debug("Starting Multipage::save");
	my ( $project_index, $service_index, $param ) = @_;
	my $Project = new openprint::Project( $project_index );	
	my $Service = $Project->Service($service_index);

	my $specs = $Service->specs();
	if ( $$specs{rdbCover} eq 'Different' ) {
		# now add a cover spread if we need one.
		# First, see if we have one.
        if ( ! $Project->signatures({'type'=>'Cover Pages'}) ) {
            $Project->add_signature( undef, undef, {
                        txtSignatureType		=> 'Cover Pages',
                        txtServiceDescription	=> 'Cover',
                        Group					=>  1,
                        PrintingType			=> $$param{PrintingType},
                        txtSpreadSize			=>  4,
                        } );
        } # end if
    } else {
# Don't need a cover, so get rid of it
        foreach ( $Project->signatures({'type'=>'Cover Pages'}) ) {
            openprint::print_project::delete_service( $Project, $_ );
        } # end foreach
        foreach ( $Project->signatures({'Group'=>1}) ) {
            openprint::print_project::delete_service( $Project, $_ );
        } # end foreach
    } # end if Self or Different Cover
	my @variables = openprint::Estimating::Printing::variables();

	foreach my $ssid ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ssid );
		my %new_specs = %$sig_specs;
#$openprint::log->debug("Spreadsize for sig $$sig_specs{SignatureIndex} orig: $new_specs{txtSpreadSize} new: $$sig_specs{txtSpreadSize}");
		openprint::Estimating::Printing::set_size( $Project, \%new_specs, $Service->specs() );
#$openprint::log->debug("Spreadsize for sig $$sig_specs{SignatureIndex} orig: $new_specs{txtSpreadSize} new: $$sig_specs{txtSpreadSize}");
		foreach my $v ( @variables ) {
			if ( $new_specs{$v} ne $$sig_specs{$v} ) {
$openprint::log->debug("Saving $v") if DEBUG;
				openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $Project->id(), $ssid, $v, $new_specs{$v} );
			} else {
$openprint::log->debug("Not Saving $v") if DEBUG;
			} # end if
		} # end foreach v
	}  # end foreach signature
} # end sub save

sub check {
	my ( $Project, $Service, $qty_index ) = @_;

	my $error;
	my $specs = $Service->specs();

	my $total_pages = $$specs{txtTotalPageQuantity};
    my %specified_pages;
    my %needed_pages;
    foreach my $ssid ( $Project->signatures({ sort=>1}) ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project, $ssid );
        $specified_pages{$$sig_specs{Group}} += $$sig_specs{"PageQuantity$qty_index"};
        $needed_pages{$$sig_specs{Group}} = $$specs{'GroupPageQuantity'.$$sig_specs{Group}};
    } # end foreach
    foreach my $Group ( sort keys %needed_pages ) {
$openprint::log->debug( "Grouup $Group needed $needed_pages{$Group} specd: $specified_pages{$Group}" );
        if ( $needed_pages{$Group} > $specified_pages{$Group} ) {
            $error .= 'Group ' . $Group . ' ' . $$specs{'txtSignatureType'.$Group} . ' needs another ' . ( $needed_pages{$Group} - $specified_pages{$Group} ) . ' pages.<br/>';
		} elsif ( $needed_pages{$Group} < $specified_pages{$Group} ) {
            $error .= 'Group ' . $Group . ' ' . $$specs{'txtSignatureType'.$Group} . ' has ' . ( $specified_pages{$Group} - $needed_pages{$Group} ) . ' too many pages.<br/>';
        } # end if
    } # end foreach
	if ( $error ) {
		if ( $error ne $$specs{alert} ) {
			openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $Project->id(), $Service->service_id(), 'alert', $error ) if $error;
		} # end if
	} else {
		if ( $$specs{alert} =~ /^Group/ ) {
			openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $Project->id(), $Service->service_id(), 'alert', $error );
		} # end if
	} # end if
	
    return $error;
} # end sub check

sub summary {
	my ( $Project, $service_index, $specs, $qty_index ) = @_;
	my @Groups = groups( $$Project{id}, $specs );
	my $html;
	if ( $qty_index ) {
	} else {
		foreach my $group_id ( @Groups ) {
			my $group_html = join(' ',
					( $$specs{"ddmRunStyle-$group_id"} ? $$specs{"ddmRunStyle-$group_id"} : () ),
					( $$specs{"ddmPress-$group_id"} ? ' on ' . $$specs{"ddmPress-$group_id"} : () ),
					( $$specs{"PrintingType-$group_id"} ? $$specs{"PrintingType-$group_id"} : () ),
					( $$specs{"PageQuantity-$group_id"} ? 'as ' . $$specs{"PageQuantity-$group_id"} . 'page signatures' : () ),
					( $$specs{"StockType-$group_id"} ? 'on ' . $$specs{"StockType-$group_id"} . ' stock' : () ),
					);
			if ( $group_html ) {
				$html .= 'Group ' . $group_id . ' is overriden to run ' . $group_html. '<br/>';
			} # end if
		} # end foreach group
	} # end if
	return $html;
} # end sub summary

1;
__END__
