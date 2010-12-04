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

package openprint::Estimating::ScratchPads;

use POSIX qw{ ceil };
use strict;
use openprint ();
use vars qw( $r %variable $log $dbh %config );
*variable = \%openprint::variable;
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require openprint::Estimating::Printing;
require openprint::service;
require sets;

my $debug = 0;

my %variables = (
	'ddmProjectSize'=>['save','output'],
	'txtFinalWidth'=>['save'],'txtFinalHeight'=>['save'], 
	'txtWidth'=>['save','output'],'txtHeight'=>['save','output'],
	'PageQuantity'=>['save'], 
	'Backing'=>['save','output'],
	'txtSpreadSize'=>['save','output'],'PrintingType'=>['save'],'rdbTemplateType'=>['save'],
	'help'=>['output'],'alert'=>['output'],
	'ProjectIndex'=>[], 'ServiceIndex'=>[], 'ServiceType'=>[], 'NewBook'=>[],
	'remaining_pages'=>['output'],'next_group_id'=>['output'],
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
} # end sub no_outputs


sub outputs {
    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k, if sets::isin( 'output', $variables{$k} );
    } # end foreach;
    return @v;
} # end sub outputs

sub calc {
	my ( undef, undef, undef, $project_index, $service_index, $specs ) = @_;
$log->debug("ScratchPads::calc");
	my @Groups = sql::execute( undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?', $project_index, 'Group' );
	if ( (! sets::isin( 1, \@Groups ) ) and $$specs{'Backing'} eq 'Printed' ) {
		push @Groups, 1;
	} # end if
	if ( ! sets::isin( 2, \@Groups ) ) {
		push @Groups, 2;
	} # end if

	my $Project = new openprint::Project( $project_index );
	my $remaining_pages = $$specs{'PageQuantity'};
	my %override_pages;

	foreach my $group_id ( @Groups ) {
#$openprint::log->debug("Group: $group_id, remaining: $remaining_pages, $override_pages{$group_id}");
		next if $override_pages{$group_id};

		if ( exists $$specs{'OverrideGroupPageQuantity'.$group_id} ) {
			$override_pages{$group_id} = $$specs{'GroupPageQuantity'.$group_id} if $$specs{'OverrideGroupPageQuantity'.$group_id} eq 'Y';
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
	if ( (! $override_pages{1} ) and ($$specs{'OverrideGroupPageQuantity1'} ne 'Y' ) and ($$specs{'Backing'} eq 'Printed') ) {
		my $new_remaining = int(($remaining_pages-1) / $$specs{'txtSpreadSize'} ) * $$specs{'txtSpreadSize'};
		$override_pages{1} = $remaining_pages - $new_remaining;
		$remaining_pages = $new_remaining;
	} # end if

	foreach my $group_id ( @Groups ) {
#$openprint::log->debug("Group: $group_id, remaining: $remaining_pages, $override_pages{$group_id}");
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

	if ( ! ( $$specs{'txtFinalWidth'} or $$specs{'txtFinalHeight'} ) ) {
		$$specs{'help'} = 'Please select the dimensions.';
		return 'uncalculated';
	} # end if
	$$specs{'txtHeight'} = $$specs{'txtFinalHeight'};
	$$specs{'txtWidth'} = $$specs{'txtFinalWidth'};

    if ( $$specs{'remaining_pages'} = $remaining_pages ) {
        my $max_group = 0;
        foreach my $g_id ( @Groups ) {
            if ( $g_id > $max_group ) {
                $max_group = $g_id;
            } # end if
        } # end foreach g_id
        $$specs{'next_group_id'} = $max_group + 1;
    } else {
        $$specs{'next_group_id'} = '';
    } # end if

	if ( ( $$specs{'txtWidth'} < $$specs{'txtFinalWidth'} ) or ( $$specs{'txtHeight'} < $$specs{'txtFinalHeight'} ) ) {
		$$specs{'alert'} .= 'Flat size cannot be smaller than finished size!';
		return 'uncalculated';
	} # end if

	if ( ! $$specs{'PageQuantity'} ) {
		$$specs{'help'} = 'Please enter the # of pages';
		return 'uncalculated';
	} # end if

	if ( ! $$specs{'Backing'} ) {
		$$specs{'help'} = 'Please select the backing type.';
		return 'uncalculated';
	} # end if

	return 'calculated';
} # end sub calc

# Returns the # of needed remaining spreads... 
sub status {
	my ( $project_index, $printing_specs, $qty_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	if ( ! $printing_specs ) {
		$printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
		return if ! $printing_specs;
	} # end if

    my $total_pages = $$printing_specs{'PageQuantity'};
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

sub save {
	my ( $p_id, $s_id, $param ) = @_;
$openprint::log->debug("Scratch Pads : save");
	my $Project = new openprint::Project( $p_id );
	my $services = $Project->services();

	my %needed_pages;
	$needed_pages{'Cover Pages'} = $$param{'OverrideGroupPageQuantity1'} eq 'Y' ? $$param{'GroupPageQuantity1'} : ($$param{'Backing'} eq 'Printed' ? 1 : 0);
	$needed_pages{'Interior Pages'} = ( $$param{'PageQuantity'} - $needed_pages{'Cover Pages'} );

	my %specified_pages;
	my $max_group;

	foreach my $k ( keys %$param ) {
		if ( $k =~ /txtSignatureType(\d*)/ ) {
			my $group_id = $1;

			if ( $$param{'GroupPageQuantity'.$group_id} and ! $Project->signatures({'Group'=>$group_id}) ) {
				my $ac = sql::start_transaction( $dbh );
				$dbh->do( "LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
				my ($print_service_index) = openprint::print_project::insert_service( $log, $dbh, $p_id, 'Signature' );
				if ( $group_id ) {
					openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtSignatureType', 'Cover Pages' );
					openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtServiceDescription', 'Backing' );
				} else {
					openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtSignatureType', 'Interior Pages' );
					openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtServiceDescription', 'Padding Pages' );
				} # end if
				openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'Group', $group_id );
				$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
				my ( $signature_count ) = sql::execute( $log, $dbh, $_, $p_id );
				openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'SignatureIndex', ++$signature_count );
				openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'PrintingType', $$param{'PrintingType'} );
				openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtSpreadSize', 1 );
				sql::end_transaction( $dbh, $ac );
			} # end if

			$specified_pages{$$param{$k}} += $$param{'GroupPageQuantity'.$group_id};
			if ( $group_id > $max_group ) {
				$max_group = $group_id;
			} # end if
		} # end if
	} # end foreach param

	if ( $$param{'Backing'} eq 'Printed' ) {
# now add a cover spread if we need one.
# First, see if we have one.
		if ( ! $Project->signatures({'type'=>'Cover Pages'}) ) {
			my $ac = sql::start_transaction( $dbh );
			$dbh->do( "LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
			my ($cover_index) = openprint::print_project::insert_service( $log, $dbh, $p_id, 'Signature' );
			openprint::service::insert_service_spec( $log, $dbh, $p_id, $cover_index, 'txtSignatureType', 'Cover Pages');
			openprint::service::insert_service_spec( $log, $dbh, $p_id, $cover_index, 'txtServiceDescription', 'Backing');
			openprint::service::insert_service_spec( $log, $dbh, $p_id, $cover_index, 'Group', 1 );
# Used to give each signature a # for reference in proofs, etc.
			$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
			my ( $signature_count ) = sql::execute( $log, $dbh, $_, $p_id );
			openprint::service::insert_service_spec( $log, $dbh, $p_id, $cover_index, 'SignatureIndex', ++$signature_count );
			openprint::service::insert_service_spec( $log, $dbh, $p_id, $cover_index, 'PrintingType', $$param{'PrintingType'} );
			openprint::service::insert_service_spec( $log, $dbh, $p_id, $cover_index, 'txtSpreadSize', 1 );
# Width and Height will be added on auto-calc
			sql::end_transaction( $dbh, $ac );
		} # end if

# Prime this for saving later
		if ( ( ! $$param{'GroupPageQuantity1'} ) and ( $$param{'OverrideGroupPageQuantity1'} ne 'Y' ) ) {
			$$param{'GroupPageQuantity1'} = $needed_pages{'Cover Pages'};
		} # end if
	} else {
# Don't need a cover, so get rid of it
		foreach ( $Project->signatures({'type'=>'Cover Pages'}) ) {
			openprint::print_project::delete_service( $log, $dbh, $p_id, $_ );
		} # end foreach
	} # end if Self or Different Cover

	if ( ! $Project->signatures({'type'=>'Interior Pages'}) ) {
# Must have at least 1 interioer signature
		my $ac = sql::start_transaction( $dbh );
		$dbh->do( "LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
		my ($print_service_index) = openprint::print_project::insert_service( $log, $dbh, $p_id, 'Signature' );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtSignatureType', 'Interior Pages' );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtServiceDescription', 'Padding Pages' );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'Group', 2 );
		$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
		my ( $signature_count ) = sql::execute( $log, $dbh, $_, $p_id );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'SignatureIndex', ++$signature_count );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'PrintingType', $$param{'PrintingType'} );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtSpreadSize', 1 );
		sql::end_transaction( $dbh, $ac );
	} # end if
	if ( ( ! $$param{'GroupPageQuantity2'} ) and ( $$param{'OverrideGroupPageQuantity2'} ne 'Y' ) ) {
		$$param{'GroupPageQuantity2'} = $needed_pages{'Interior Pages'};
	} # end if

	foreach my $ss_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $ss_id );
        my $type = $$sig_specs{'Group'};

# We have to do this for simple printing.  Simple printing calls here, but doesn't have these fields, so it clears out the defaults!
		foreach my $spec (
				'txtSignatureType',
				'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight',
				'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight',
				'txtSpecificStockWidth','txtSpecificStockHeight','txtSpecificStockCalliper',
				'rdbSuppliedStock','rdbSpecificStock','StockType',
				'CustomSheetDoubleSided', 'CustomStockPrice','txtCustomMWeight','txtStockGSM','CustomStockPriceUnits',
				'basis_width','basis_height','basis_mweight','StockGrade',

				'chkCyanSideOne','chkMagentaSideOne','chkYellowSideOne','chkBlackSideOne', 'chkProcessColourSideOne',
				'CyanSpotSideOneCoverage', 'MagentaSpotSideOneCoverage', 'YellowSpotSideOneCoverage', 'BlackSpotSideOneCoverage',
				'CyanSideOneCoverage', 'MagentaSideOneCoverage', 'YellowSideOneCoverage', 'BlackSideOneCoverage',
				'CyanSpotSideTwoCoverage', 'MagentaSpotSideTwoCoverage', 'YellowSpotSideTwoCoverage', 'BlackSpotSideTwoCoverage',
				'CyanSideTwoCoverage', 'MagentaSideTwoCoverage', 'YellowSideTwoCoverage', 'BlackSideTwoCoverage',
				'ColourCoating1SideOne', 'ColourCoatingType1SideOne', 'ColourCoatingColour1SideOne','ColourCoatingCoverage1SideOne',
				'ColourCoating2SideOne', 'ColourCoatingType2SideOne', 'ColourCoatingColour2SideOne','ColourCoatingCoverage2SideOne',
				'ColourCoating3SideOne', 'ColourCoatingType3SideOne', 'ColourCoatingColour3SideOne','ColourCoatingCoverage3SideOne',
				'ColourCoating4SideOne', 'ColourCoatingType4SideOne', 'ColourCoatingColour4SideOne','ColourCoatingCoverage4SideOne',
				'ColourCoating5SideOne', 'ColourCoatingType5SideOne', 'ColourCoatingColour5SideOne','ColourCoatingCoverage5SideOne',
				'ColourCoating6SideOne', 'ColourCoatingType6SideOne', 'ColourCoatingColour6SideOne','ColourCoatingCoverage6SideOne',
				'ColourCoating7SideOne', 'ColourCoatingType7SideOne', 'ColourCoatingColour7SideOne','ColourCoatingCoverage7SideOne',
				'ColourCoating8SideOne', 'ColourCoatingType8SideOne', 'ColourCoatingColour8SideOne','ColourCoatingCoverage8SideOne',
				'ColourCoating9SideOne', 'ColourCoatingType9SideOne', 'ColourCoatingColour9SideOne','ColourCoatingCoverage9SideOne',

				'chkCyanSideTwo','chkMagentaSideTwo','chkYellowSideTwo','chkBlackSideTwo', 'chkProcessColourSideTwo',
				'ColourCoating1SideTwo', 'ColourCoatingType1SideTwo', 'ColourCoatingColour1SideTwo','ColourCoatingCoverage1SideTwo',
				'ColourCoating2SideTwo', 'ColourCoatingType2SideTwo', 'ColourCoatingColour2SideTwo','ColourCoatingCoverage2SideTwo',
				'ColourCoating3SideTwo', 'ColourCoatingType3SideTwo', 'ColourCoatingColour3SideTwo','ColourCoatingCoverage3SideTwo',
				'ColourCoating4SideTwo', 'ColourCoatingType4SideTwo', 'ColourCoatingColour4SideTwo','ColourCoatingCoverage4SideTwo',
				'ColourCoating5SideTwo', 'ColourCoatingType5SideTwo', 'ColourCoatingColour5SideTwo','ColourCoatingCoverage5SideTwo',
				'ColourCoating6SideTwo', 'ColourCoatingType6SideTwo', 'ColourCoatingColour6SideTwo','ColourCoatingCoverage6SideTwo',
				'ColourCoating7SideTwo', 'ColourCoatingType7SideTwo', 'ColourCoatingColour7SideTwo','ColourCoatingCoverage7SideTwo',
				'ColourCoating8SideTwo', 'ColourCoatingType8SideTwo', 'ColourCoatingColour8SideTwo','ColourCoatingCoverage8SideTwo',
				'ColourCoating9SideTwo', 'ColourCoatingType9SideTwo', 'ColourCoatingColour9SideTwo','ColourCoatingCoverage9SideTwo',
               'BleedLeft','BleedRight','BleedTop','BleedBottom','rdbColourBar','txtCropMarkSpace',
                'GroupPageQuantity','OverrideGroupPageQuantity','txtServiceDescription','rdbTemplateType',
                'rdbPanels','PocketSize','chkPocketLeft','chkPocketCenter','chkPocketRight',
                'txtFinalWidth','txtFinalHeight','chkOverrideDimensions','txtQuantity1','txtQuantity2','txtQuantity3',
                ) {
            openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, $spec, $$param{$spec.$type} );
        } # end foreach spec
    } # end foreach

	if ( misc::sum( values %specified_pages ) < $$param{'PageQuantity'} ) {
# Must have at least 1 interioer signature
		my $ac = sql::start_transaction( $dbh );
		$dbh->do( "LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
		my ($print_service_index) = openprint::print_project::insert_service( $log, $dbh, $p_id, 'Signature' );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtSignatureType', 'Interior Pages' );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtServiceDescription', 'Pad Pages' );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'Group', $max_group + 1 );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'GroupPageQuantity', $needed_pages{'Interior Pages'} - $specified_pages{'Interior Pages'} );
		$_ = q{SELECT MAX(strValue) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
		my ( $signature_count ) = sql::execute( $log, $dbh, $_, $p_id );
		$signature_count += 1;
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'SignatureIndex', $signature_count );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'PrintingType', $$param{'PrintingType'} );
		openprint::service::insert_service_spec( $log, $dbh, $p_id, $print_service_index, 'txtSpreadSize', $$param{'txtSpreadSize'} );
		sql::end_transaction( $dbh, $ac );
		$variable{'Redirect'} = '/main/project/prin/ScratchPads.html';
		return;
	} # end if

	if ( $$services{'Padding'} ) {
		foreach my $padding_id ( @{$$services{'Padding'}} ) {
			openprint::service::insert_service_spec( $log, $dbh, $p_id, $padding_id, 'Backing', $$param{'Backing'} );
			openprint::service::insert_service_spec( $log, $dbh, $p_id, $padding_id, 'PageQuantity', $$param{'PageQuantity'} );
		} # end foreach
	} # end if

	openprint::Estimating::MultiPage::calculate_signatures( $log, $dbh, \%variable, $p_id );
	openprint::service::auto_calculate( $r, $log, $dbh, \%variable, $p_id, $s_id );
} # end sub save

1;

__END__
