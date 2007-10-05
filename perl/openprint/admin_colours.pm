package openprint::admin_colours;

use Text::CSV_XS;

use strict;
require sql;
require misc;
require openprint::logs;

# Colour Definitions Import/Export
sub import_export {
	my ( $r, $log, $dbh, $variable ) = @_;

	if ( $openprint::param{'btnFunction'} eq 'Save' ) {
		my $ac = sql::start_transaction( $openprint::dbh );
		foreach my $id ( sql::execute( undef, undef, q{SELECT id FROM Inks} ) ) {
			if ( $openprint::param{"pmsid-$id"} ) {
			sql::update( undef, undef, 'Inks', ['id=?', $id], [
				'pmsid', $openprint::param{"pmsid-$id"},
				'material_id', $openprint::param{"material_id-$id"} ? $openprint::param{"material_id-$id"} : undef,
				'service_id', $openprint::param{"service_id-$id"} ? $openprint::param{"service_id-$id"} : undef,
				'washups', $openprint::param{"washups-$id"} ? $openprint::param{"washups-$id"} : undef,
			] );
			} else {
				sql::execute(undef,undef,q{DELETE FROM Inks WHERE Id=?}, $id );
			} # end if
		} # end foreach id
		if ( $openprint::param{"pmsid-New"} ) {
			sql::insert( undef, undef, 'Inks', [
					'pmsid', $openprint::param{"pmsid-New"},
					'material_id', $openprint::param{"material_id-New"} ? $openprint::param{"material_id-New"} : undef,
					'service_id', $openprint::param{"service_id-New"} ? $openprint::param{"service_id-New"} : undef,
					'washups', $openprint::param{"washups-New"} ? $openprint::param{"washups-New"} : undef,
					] );
		} # end if
		sql::end_transaction( $openprint::dbh, $ac );
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {

	} elsif ( $openprint::param{'btnFunction'} eq 'Import Colours' ) {
		if ( $openprint::param{'fileColour'} ) {

			my %services = map { $_->name(), $_->id() } openprint::Service::find();
			my %materials = map { $_->name(), $_->id() } openprint::Material::find();
			# get the upload.
			my $upload = $r->upload( 'fileColour' );
			my $io = $upload->io();
			#convert it
			my $csv = Text::CSV_XS->new();
			$_ = <$io>; # drop the title row

			my $ac = sql::start_transaction( $openprint::dbh );
			sql::execute( undef, undef, q{DELETE FROM Inks} );
			while ( <$io> ) {
				my $status = $csv->parse($_);		 # parse a CSV string into fields

				my ( $pms_id, $service, $material, $washups, $desc ) = misc::trim($csv->fields());

				my @params = (
					'pmsid',			$pms_id,
					'service_id',		$services{$service},
					'material_id',		$materials{$material},
					'strColourName',	$desc,
					'washups',			$washups,
				);
				sql::insert( undef, undef, 'Inks', \@params );
			} # end while
      		# Add record to audit log - action "Import Colour Definitions".
         	openprint::logs::insertLogRecord('56', '');
			sql::end_transaction( $openprint::dbh, $ac );
		} else {
			$log->warn( "No file given to upload." );
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Export Colours' ) {
		my @header = ( 'PMSId', 'Serivce ID', 'Material ID', 'Colour Name' );
		$_ = "SELECT PMSID, (SELECT name FROM Services WHERE id=service_id), (SELECT name FROM Materials WHERE id=Material_ID), washups, strColourName FROM Inks";
		my @data = sql::execute( $log, $dbh, $_ );
		misc::export_csv( $r, $log, $variable, 'colours.csv', \@header, \@data );
		# Add record to audit log - action "Export Colour Definitions".
		openprint::logs::insertLogRecord('57',);
	} # end if
} # end sub import_export



1;

__END__

