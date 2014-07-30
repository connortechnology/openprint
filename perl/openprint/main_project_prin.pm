package openprint::main_project_prin;
use strict;
use openprint ();
use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

require openprint::Project;
require openprint::print_project;
require openprint::service;

sub _signature {

	my $Project = new openprint::Project( $param{'project_id'} );
	$variable{ProjectType} = $Project->Type();

	if ( $param{action} eq 'remove_group' ) {
		my @src_sigs = $Project->signatures( { Group => $param{group_id} } );
		if ( ! @src_sigs ) {
			$variable{error} .= 'No signatures found for group ' . $param{group_id} . '<br/>';
			return;
		} # end if
		$Project->lock();
		foreach my $sig_id ( @src_sigs ) {
			my $Service = $Project->Service( $sig_id );
			$Service->delete();
		} # end foreach 
		$Project->unlock();

	} elsif ( $param{action} eq 'copy_group' ) {
		my @src_sigs = $Project->signatures( { Group => $param{group_id} } );
		if ( ! @src_sigs ) {
			$variable{error} .= 'No signatures found for group ' . $param{group_id} . '<br/>';
			return;
		} # end if
		$Project->lock();
		$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='Group'};
		( $variable{Group} ) = sql::execute( $log, $dbh, $_, $Project->id() );
		$variable{Group} += 1;
		$variable{'Signature'} = $variable{Group};
		my $print_service_index = $Project->copy_signature( openprint::service::get_specs_ref( $Project, $src_sigs[0] ), { Group=>$variable{Group} } );;
		$Project->unlock();
		my $sig_specs = openprint::service::get_specs_ref( $Project, $print_service_index );
		foreach my $k ( keys %$sig_specs ) {
			$variable{$k.$variable{'Group'}} = $$sig_specs{$k};
		} # end foreach k

	} elsif ( $param{action} eq 'add_group' ) {
		$Project->lock();
		$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='Group'};
		( $variable{Group} ) = sql::execute( $log, $dbh, $_, $Project->id() );
		$variable{Group} += 1;
		$variable{'Signature'} = $variable{Group};

		my $print_service_index = $Project->add_service( 'Signature' );
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'txtSignatureType', 'Interior Pages' );
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'txtServiceDescription', 'Interior Pages' );
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'Group', $variable{Group} );
		$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
		my ( $signature_count ) = sql::execute( $log, $dbh, $_, $Project->id() );
		$signature_count += 1;
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'SignatureIndex', $signature_count );
		$Project->unlock();

		my $sig_specs = openprint::service::get_specs_ref( $Project, $print_service_index );
		foreach my $k ( keys %$sig_specs ) {
			$variable{$k.$variable{'Group'}} = $$sig_specs{$k};
		} # end foreach k

	} elsif ( $param{'group_id'} ) {
		$variable{'Group'} = $param{'group_id'};
        $variable{'Signature'} = $param{'group_id'};
		if ( ! $Project->signatures({'Group'=>$param{'group_id'}}) ) {
			$Project->lock();
			my $print_service_index = $Project->add_service( 'Signature' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'txtSignatureType', 'Interior Pages' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'txtServiceDescription', 'Interior Pages' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'Group', $param{'group_id'} );
			$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
			my ( $signature_count ) = sql::execute( $log, $dbh, $_, $Project->id() );
			$signature_count += 1;
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'SignatureIndex', $signature_count );
			$Project->unlock();
			my $sig_specs = openprint::service::get_specs_ref( $Project, $print_service_index );
			foreach my $k ( keys %$sig_specs ) {
				$variable{$k.$variable{'Group'}} = $$sig_specs{$k};
			} # end foreach k
		} # end if
    } # end if

} # end sub _signature

sub Signature {
	my $Project = $variable{'Project'} = new openprint::Project( $param{'ProjectIndex'} );
	$variable{'ProjectType'} = $Project->Type();
} # end sub Signature

sub _stock_popup {
} # end sub _stop_popup

sub _stocks {
} # end sub _stocks

sub _impositions {
} # end sub _impositions

1;
__END__
