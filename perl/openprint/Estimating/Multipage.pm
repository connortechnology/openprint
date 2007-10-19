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

my %variables = (
	'ddmProjectSize'=>['save','output'],
	'txtFinalWidth'=>['save'],'txtFinalHeight'=>['save'], 
	'txtWidth'=>['save','output'],'txtHeight'=>['save','output'],
	'txtTotalPageQuantity'=>['save'], 
	'rdbCover'=>['save','output'],
	'txtGateFoldedSpreadQuantity'=>['save','output'],
	'txtTotalSpreadQuantity'=>['save','output'], 
	'txtInteriorSpreadQuantity'=>['save','output'],
	'txtInsertQuantity'=>['save'],
	'txtSpreadSize'=>['save','output'],'PrintingType'=>['save'],'rdbTemplateType'=>['save'],
	'help'=>['output'],'alert'=>['output'],
	'ProjectIndex'=>[], 'ServiceIndex'=>[], 'ServiceType'=>[], 'NewBook'=>[],
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

	if ( sets::isin( $$specs{'rdbTemplateType'}, ['MetalCoil','PlasticCoil','PlasticComb','DoubleLoopWire'] ) ) {
		$$specs{'txtSpreadSize'} = 4;
	} elsif ( sets::isin( $$specs{'rdbTemplateType'}, ['CornerStitching','PerfectBound','SpinePaste'] ) ) {
		$$specs{'txtSpreadSize'} = 2;
	} else {
		$$specs{'txtSpreadSize'} = 4;
	} # end if
	
	if ( $$specs{'rdbTemplateType'} eq 'PerfectBound' and $$specs{'rdbCover'} ne 'Different' ) {
		$variables{'rdbCover'} = [sets::union('output', @{$variables{'rdbCover'}})];
		$$specs{'rdbCover'} = 'Different';
	} elsif ( $$specs{'rdbTemplateType'} eq 'SpinePaste' and $$specs{'rdbCover'} eq 'Different' ) {
		$variables{'rdbCover'} = [sets::union('output', @{$variables{'rdbCover'}})];
		$$specs{'rdbCover'} = 'Self';
	} # end if

	openprint::Estimating::Printing::get_colours( $specs, 'SideOne', \%variables, 'InteriorSpreads' );
	openprint::Estimating::Printing::get_colours( $specs, 'SideTwo', \%variables, 'InteriorSpreads' );
	openprint::Estimating::Printing::get_colours( $specs, 'SideOne', \%variables, 'CoverSpreads' );
	openprint::Estimating::Printing::get_colours( $specs, 'SideTwo', \%variables, 'CoverSpreads' );
	openprint::Estimating::Printing::get_inkcoverage( $specs, \%variables, 'InteriorSpreads' );
	openprint::Estimating::Printing::get_inkcoverage( $specs, \%variables, 'CoverSpreads' );

	if ( ! ( $$specs{'txtFinalWidth'} or $$specs{'txtFinalHeight'} ) ) {
		$$specs{'help'} = 'Please select the dimensions.';
		return 'uncalculated';
	} # end if
	$$specs{'txtHeight'} = $$specs{'txtFinalHeight'};
	if ( $$specs{'txtSpreadSize'} == 2 ) {
		$$specs{'txtWidth'} = $$specs{'txtFinalWidth'};
	} elsif ( $$specs{'txtSpreadSize'} == 4 ) {
		$$specs{'txtWidth'} = 2*$$specs{'txtFinalWidth'};
	} # end if

	if ( ( $$specs{'txtWidth'} < $$specs{'txtFinalWidth'} ) or ( $$specs{'txtHeight'} < $$specs{'txtFinalHeight'} ) ) {
		$$specs{'alert'} .= 'Flat size cannot be smaller than finished size!';
		return 'uncalculated';
	} # end if

	if ( ! $$specs{'txtTotalPageQuantity'} ) {
		$$specs{'help'} = 'Please enter the # of pages';
		return 'uncalculated';
	} # end if

	if ( ! $$specs{'rdbCover'} ) {
		$$specs{'help'} = 'Please select the cover type.';
		return 'uncalculated';
	} # end if

	$$specs{'txtTotalSpreadQuantity'} = ceil( $$specs{'txtTotalPageQuantity'} / $$specs{'txtSpreadSize'} );
	$$specs{'txtInteriorSpreadQuantity'} = $$specs{'txtTotalSpreadQuantity'} - $$specs{'txtGateFoldedSpreadQuantity'};
	if ( $$specs{'rdbCover'} eq 'Different' ) {
		# Cover is always a 4page spread, unless gatefolded
		if ( $$specs{'txtSpreadSize'} == 4 ) {
			$$specs{'txtInteriorSpreadQuantity'} -= 1;
		} else {
			$$specs{'txtInteriorSpreadQuantity'} -= 2;
		} # end if
	} # end if
	return 'calculated';

} # end sub calc

sub calculate_signatures {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $status;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	my $unspecified_spreads = 0;
	my $printing_specs = openprint::service::get_specs_ref( $project_index, $$services{''}[0] );
	return if ! $$printing_specs{'txtTotalPageQuantity'};

	my @signatures = sort $Project->signatures('Interior Spreads');
	push @signatures, sort $Project->signatures('Cover Spreads');
	push @signatures, sort $Project->signatures('GateFolded Spreads');

	# If we have a specified printing type, then .... if any of the sigs aren't of the same printing type is this even neccessary? 
	for ( my $i = 0; $i < @signatures; $i += 1 ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $signatures[$i] );

# Clear these so that when we start recalculating, we get large signatures first.
		foreach my $qty_index ( 1 .. 3 ) {
			if ( ( $$sig_specs{'chkOverrideSignatureSpreadQuantity'.$qty_index} ne 'Y' ) and ( $$sig_specs{'chkOverridePageQuantity'.$qty_index} ne 'Y' ) ) {
				openprint::service::insert_service_specs( $log, $dbh, $project_index, $signatures[$i], 'txtSignatureSpreadQuantity'.$qty_index, '' );
				openprint::service::insert_service_specs( $log, $dbh, $project_index, $signatures[$i], 'PageQuantity'.$qty_index, '' );
			} # end if
		} # end foreach

		if ( $$printing_specs{'PrintingType'} ) {
			$log->debug("PrintingType: $$printing_specs{'PrintingType'}");
			if ( $$sig_specs{'PrintingType1'} ne $$printing_specs{'PrintingType'} 
					or $$sig_specs{'PrintingType2'} ne $$printing_specs{'PrintingType'}
					or $$sig_specs{'PrintingType3'} ne $$printing_specs{'PrintingType'} ) {
# delete any similar signs
				$log->debug("Getting rid of extra sigs");
				for ( my $j = $i+1; $j < @signatures; $j += 1 ) {
					my $specs2 = openprint::service::get_specs_ref( $project_index, $signatures[$j] );
					if ( openprint::Estimating::Printing::compare_signatures( $sig_specs, $specs2 ) ) {
$openprint::log->warn('Deleting due to incorrect printing type');
						openprint::print_project::delete_service( $log, $dbh, $project_index, $signatures[$j] );
						splice @signatures, $j, 1;
						$j-=1;
					} # end if
				} # end for
			} # end if
		} # end if
	} # end for


# the loop_count stuff is to prevent endless loops
	my $loop_count = 0;
	while ( ( $loop_count < @signatures ) and ( $status ne 'calculated' ) ) {
		foreach my $ss_id ( @signatures ) {
$openprint::log->debug("Loop Count: $loop_count Sig: $ss_id: " . @signatures . ' Status: ' . $status); 
			my $sig_specs = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $ss_id, 'Printing' );
$openprint::log->debug( "XXX$$sig_specs{txtSignatureSpreadQuantity1}XXXXXXXXXXXXXXXXX$$sig_specs{PageQuantity1} $$sig_specs{PageQuantity2} $$sig_specs{PageQuantity3} $$sig_specs{Status}" );
			# If we couldn't calculate, then delete all the other printing types and retry.
			if ( $$sig_specs{'Status'} eq 'uncalculated' ) {
				if ( 1 < sql::execute( undef, undef, q{SELECT DISTINCT strValue FROM tbl_Equipment_Specifications WHERE strName='Printing Type' } ) ) {
					$openprint::log->debug("Retrying after changing Printing Type");
					foreach my $ss_id2 ( @signatures ) {
						openprint::service::insert_service_specs( $log, $dbh, $project_index, $ss_id2, 'PrintingType1', '' ) if $$sig_specs{'txtQuantity1'};
						openprint::service::insert_service_specs( $log, $dbh, $project_index, $ss_id2, 'PrintingType2', '' ) if $$sig_specs{'txtQuantity2'};
						openprint::service::insert_service_specs( $log, $dbh, $project_index, $ss_id2, 'PrintingType3', '' ) if $$sig_specs{'txtQuantity3'};
					} # end foreach Signature
					my $sig_specs2 = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $ss_id, 'Printing' );
					if ( $$sig_specs2{'Status'} eq 'uncalculated' ) {
# Fix PrintingTypes
						foreach my $ss_id2 ( @signatures ) {
							openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $ss_id2, 'Printing' );
						} # end foreach
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
				if ( ( @signatures > 1 ) and $$printing_specs{'txtTotalPageQuantity'} and ! ( $$sig_specs{'txtSignatureSpreadQuantity1'}
							or $$sig_specs{'txtSignatureSpreadQuantity2'}
							or $$sig_specs{'txtSignatureSpreadQuantity3'} ) ) {
$openprint::log->warn('Deleting due to no spreads');
					openprint::print_project::delete_service( $log, $dbh, $project_index, $ss_id );
					@signatures = sets::exclude( [ $ss_id ], \@signatures );
				} # end if
			} else {
$openprint::log->debug("unknown status: $$sig_specs{'Status'} alert: $$sig_specs{'alert'}");
				$status = $$sig_specs{'Status'};
			} # end if
		} # end foreach Interior Signature
		$loop_count += 1;
	} # end while

#So all signatures were able to be calculated... which is good, but we may have too many, or not enough signatures
$openprint::log->debug("after initial recalc");

	# Chekc for unspecified spreads
		foreach my $ss_id ( @signatures ) {
			my $sig_specs = openprint::service::get_specs_ref( $project_index, $ss_id );
			foreach my $qty_index ( 1 .. 3 ) {
				next if ! $$sig_specs{'txtQuantity'.$qty_index};
				$unspecified_spreads = openprint::Estimating::Printing::get_unspecified_spreads( $Project, undef, $printing_specs, $sig_specs, $qty_index );
				last if $unspecified_spreads;
			} # end foreach

	$openprint::log->warn("Unspecified: for $$sig_specs{'txtSignatureType'} $unspecified_spreads");
			if ( $unspecified_spreads == 0 ) {
				if ( ! ( $$sig_specs{'txtSignatureSpreadQuantity1'}
							or $$sig_specs{'txtSignatureSpreadQuantity2'}
							or $$sig_specs{'txtSignatureSpreadQuantity3'} ) ) {
					openprint::print_project::delete_service( $log, $dbh, $project_index, $ss_id );
					@signatures = sets::exclude( [ $ss_id ], \@signatures );
				} # end if
			} elsif ( ( $unspecified_spreads > 0 ) and ( $$sig_specs{'txtSignatureType'} ne 'Cover Spreads' ) ) {
	# Need to add signatures
				my $check_unspecified_spreads = $unspecified_spreads;
				while ( $unspecified_spreads > 0 ) {
					if ( $service_index ) {
						$sig_specs = openprint::service::get_specs_ref( $Project, $service_index );
					} # end if
					my $new_service_index = copy_signature( $project_index, $sig_specs );
					my $new_sig_specs = openprint::service::get_specs_ref( $Project, $new_service_index );
					foreach my $qty_index ( 1 .. 3 ) {
						next if ! $$new_sig_specs{'txtQuantity'.$qty_index};
						if ( $$new_sig_specs{'txtSignatureSpreadQuantity'.$qty_index} > $unspecified_spreads ) {
							openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $project_index, $new_service_index, 'chkOverrideSignatureSpreadQuantity'.$qty_index, '' );
							openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $project_index, $new_service_index, 'chkOverridePageQuantity'.$qty_index, '' );
							openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $project_index, $new_service_index, 'chkOverrideImposition'.$qty_index, '' );
						} # end if
					} # end foreach
					$new_sig_specs = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $new_service_index, 'Printing' );
					last if $$new_sig_specs{'Status'} eq 'uncalculated';

					foreach my $qty_index ( 1 .. 3 ) {
						next if ! $$new_sig_specs{'txtQuantity'.$qty_index};
						$unspecified_spreads = $$new_sig_specs{'txtUnspecifiedSpreadQuantity'.$qty_index};
						last if $unspecified_spreads;
					} # end foreach
					last if $unspecified_spreads == $check_unspecified_spreads;
					$check_unspecified_spreads = $unspecified_spreads;
				} # end while unspecified_spreads
			} elsif ( $unspecified_spreads < 0 ) {
	# Need to remove spreads
				while ( @signatures ) {
					my $ss_id = pop @signatures;
					my $sig_specs = openprint::service::get_specs_ref( $project_index, $ss_id );
					foreach my $qty_index ( 1 .. 3 ) {
						$unspecified_spreads = openprint::Estimating::Printing::get_unspecified_spreads( $Project, undef, $printing_specs, $sig_specs, $qty_index );
						last if $unspecified_spreads >= 0;
					} # end foreach
					if ( (@signatures > 1 ) and ( $unspecified_spreads < 0 ) ) {
						openprint::print_project::delete_service( $log, $dbh, $project_index, $ss_id );
						@signatures = sets::exclude( [ $ss_id ], \@signatures );
					} else {
						last;
					} # end if

				} # end while
			} # end if
		} # end foreach signature

	return 'calculated';
} # end sub calculate_signatures

# Returns the # of needed remaining spreads... 
sub status {
	my ( $project_index, $printing_specs, $qty_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	if ( ! $printing_specs ) {
		$printing_specs = openprint::service::get_specs_ref( $project_index, $$services{''}[0] );
		return if ! $printing_specs;
	} # end if

    my $total_spreads = $$printing_specs{'txtTotalSpreadQuantity'};
	my %specified_spreads;
	foreach my $ssid ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $ssid );
		$specified_spreads{$$sig_specs{'txtSignatureType'}} += $$sig_specs{"txtSignatureSpreadQuantity$qty_index"};
	} # end foreach

	if ( $$printing_specs{'rdbCover'} eq 'Different') {
		#if ( $$printing_specs{'txtSpreadSize'} == 4 ) {
return 'Cover Spreads' if ( $specified_spreads{'Cover Spreads'} != 1 );
		#} elsif ( $$printing_specs{'txtSpreadSize'} == 2 ) {
			#return 1 if ( $specified_spreads{'Cover Spreads'} != 1 );
		#} # end if
	} # end if

	return 'Interior Spreads' if $$printing_specs{'txtInteriorSpreadQuantity'} > $specified_spreads{'Interior Spreads'};
} # end sub status
        
sub copy_signature {
	my ( $project_index, $sig_specs ) = @_;
$openprint::log->debug("ADding signature");
	my $new_service_index = openprint::print_project::insert_service( $openprint::log, $openprint::dbh, $project_index, 'AdditionalSignature' );
	my $new_specs = openprint::service::get_specs_ref( $project_index, $new_service_index );
	my $ac = sql::start_transaction( $openprint::dbh );
	$openprint::dbh->do( 'LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE' ) or $openprint::log->error( DBI->errstr );
	$_ = q{SELECT MAX(strValue) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
	my ( $sig_index ) = sql::execute( undef, undef, $_, $project_index );
	openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $project_index, $new_service_index, 'SignatureIndex', ++$sig_index );

	# Releases the lock
	$openprint::dbh->commit();
	foreach my $key ( openprint::Estimating::Printing::variables() ) {
		openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $project_index, $new_service_index, $key, $$sig_specs{$key}, ! exists $$new_specs{$key} );
	} # end foreach

	sql::end_transaction( $openprint::dbh, $ac );
	return $new_service_index;
} # end sub copy_signature

1;
__END__
