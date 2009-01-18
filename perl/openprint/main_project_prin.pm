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
	if ( $param{'group_id'} ) {
        $variable{'Group'} = $param{'group_id'};
        $variable{'Signature'} = $param{'group_id'};
		if ( ! $Project->signatures({'Group'=>$param{'group_id'}}) ) {
			my $ac = sql::start_transaction( $dbh );
			$dbh->do( "LOCK TABLE tbl_Service_Specifications IN SHARE ROW EXCLUSIVE MODE" ) or $log->error( DBI->errstr );
			my ($print_service_index) = openprint::print_project::insert_service( $log, $dbh, $Project->id(), 'AdditionalSignature' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'txtSignatureType', 'Interior Pages' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'txtServiceDescription', 'Interior Pages' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'Group', $param{'group_id'} );
			$_ = q{SELECT MAX(strValue) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
			my ( $signature_count ) = sql::execute( $log, $dbh, $_, $Project->id() );
			$signature_count += 1;
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $print_service_index, 'SignatureIndex', $signature_count );
			sql::end_transaction( $dbh, $ac );
			my $sig_specs = openprint::service::get_specs_ref( $Project, $print_service_index );
			foreach my $k ( keys %$sig_specs ) {
				$variable{$k.$variable{'Group'}} = $$sig_specs{$k};
			} # end foreach k
		} # end if
    } # end if

} # end sub _signature
1;
__END__
