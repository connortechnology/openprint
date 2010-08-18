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

package openprint::Estimating::SinglePage;

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
	'PrintingType'=>['save'],'rdbTemplateType'=>['save'],
	'help'=>['output'],'alert'=>['output'],
	'ProjectIndex'=>[], 'ServiceIndex'=>[], 'ServiceType'=>[],
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

	my $group_id = '';
	openprint::Estimating::Printing::get_colours( $specs, 'SideOne', \%variables, $group_id );
	openprint::Estimating::Printing::get_colours( $specs, 'SideTwo', \%variables, $group_id );
	openprint::Estimating::Printing::get_inkcoverage( $specs, \%variables, $group_id );

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

	return $$specs{'Status'} = 'calculated';
} # end sub calc

sub calculate_signatures {
	my ( $log, $dbh, $variable, $project_index ) = @_;

	my $status;
$openprint::log->debug("****************************************************************Starting MultiPage::calculate_signatures");
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

# Clear these so that when we start recalculating, we get large signatures first.
if ( 0 ) {
		# Not neccessary anymore?
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			if ( $$sig_specs{'chkOverridePageQuantity'.$qty_index} ne 'Y' ) {
				openprint::service::insert_service_specs( $log, $dbh, $project_index, $signatures[$i], 'PageQuantity'.$qty_index, '' );
			} # end if
		} # end foreach
} # end if

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

	my @groups = sql::execute(undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strname=?', $Project->id(), 'Group' );
	if ( ! @groups ) {
		foreach my $ss_id ( $Project->signatures() ) {
			my $sig_specs = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $ss_id, 'Printing' );
			if ( $$sig_specs{'Status'} ne 'calculated' ) {
				return 'uncalculated';
			} # end if
		} # end if
	} else {
	foreach my $group ( @groups ) {
		my @sigs = sort $Project->signatures( {'Group'=>$group} );
$openprint::log->debug("Sigs in group $group : @sigs " );
		next if ! @sigs;
		my $ss_id = shift @sigs;

		my $sig_specs = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $ss_id, 'Printing' );
# If we couldn't calculate, then delete all the other printing types and retry.
		if ( $$sig_specs{'Status'} eq 'uncalculated' ) {
			if ( 1 < sql::execute( undef, undef, q{SELECT DISTINCT strValue FROM tbl_Equipment_Specifications WHERE strName='Printing Type' } ) ) {
				$openprint::log->debug("Retrying after changing Printing Type");
				foreach my $ss_id2 ( @signatures ) {
					foreach my $qty_index ( $Project->quantity_indexes() ) {
					openprint::service::insert_service_specs( $log, $dbh, $project_index, $ss_id2, 'PrintingType'.$qty_index, '' ) if $$sig_specs{'txtQuantity1'};
					} # end foreach
				} # end foreach Signature
				my $sig_specs2 = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $ss_id, 'Printing' );
				if ( $$sig_specs2{'Status'} eq 'uncalculated' ) {
# Despite removing printing type restrictions, we were still unable to calculate, so give up.
					return 'uncalculated';
				} else {
					$status = $$sig_specs2{'Status'};
				} # end if
			} else {
				return 'uncalculated';
			} # end if
		} elsif ( $$sig_specs{'Status'} eq 'calculated' ) {
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
				my $a_ss_id = shift @sigs;
				my $new_sig_specs = openprint::service::get_specs_ref( $Project, $a_ss_id );
				my %specs = %{$new_sig_specs};
				openprint::Estimating::Printing::calc_from_imposition( $Project, $a_ss_id, \%specs, $sig_specs );

				my $ac = sql::start_transaction( $openprint::dbh );
				sql::update( undef, undef, 'tbl_Project_Contents', ['lngProjectIndex=? AND lngServiceIndex=?', $project_index, $a_ss_id], 'strStatus', $status );

				foreach my $key ( openprint::Estimating::Printing::variables( $project_index, $a_ss_id, $new_sig_specs, \%specs ) ) {
					openprint::service::insert_service_spec( undef, undef, $project_index, $a_ss_id, $key, $specs{$key} );
				} # end foreach
				sql::end_transaction( $openprint::dbh, $ac );

			} # end while Additional Imposition

			# Clean up any leftovers
$openprint::log->debug("Remaining sigs " . @sigs);
			while ( my $ss_id = shift @sigs ) {
				openprint::print_project::delete_service( $log, $dbh, $project_index, $ss_id );
				@signatures = sets::exclude( [ $ss_id ], \@signatures );
			} # end while sigs

		} else {
			$openprint::log->debug("unknown status: $$sig_specs{'Status'} alert: $$sig_specs{'alert'}");
			$status = $$sig_specs{'Status'};
		} # end if
	} # end foreach grooooup
	} # end if no gorups

	return 'calculated';
} # end sub calculate_signatures

# Returns the # of needed remaining spreads... 
sub status {
	my ( $project_index, $printing_specs, $qty_index ) = @_;

	return;
} # end sub status
        
1;
__END__
