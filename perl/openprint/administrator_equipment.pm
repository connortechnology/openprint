package openprint::administrator_equipment;

use Text::CSV_XS;

use strict;
require sql;
require misc;

require openprint::Equipment;
require openprint::EquipmentSpecification;
require openprint::logs;

sub import_specs {
	my ( $r, $log, $dbh, $variable, $Equipment ) = @_;

	my %equipment = map { $_->strid(), $_->id() } openprint::Equipment::find();

	my $error = '';
	if ( $openprint::param{'fileSpecifications'} ) {
		sql::start_transaction( $dbh );

		sql::execute( undef, undef, 'DELETE FROM tbl_Equipment_Specifications' . ( $Equipment->id()?' WHERE lngEquipmentIndex=' . $Equipment->id():''));

		my $upload = $r->upload( 'fileSpecifications' );
		my $io = $upload->io();
		$_ = <$io>;

		my $csv = Text::CSV_XS->new();

		while (<$io>) {
			my $status = $csv->parse($_);
			my ( $id, $name, $min, $max, $units, $value, $interpolate ) = misc::trim( $csv->fields() );
			next if $id eq '';
			$min =~ s/[^\d\.]//;
			$max =~ s/[^\d\.]//;
			$interpolate = sets::isin( $interpolate, ['1','Y','true','TRUE'] ) ? 'true' : 'false';

			foreach my $equip_id ( misc::trim( split( ',', $id ) ) ) {
				if ( ! $equipment{$equip_id} ) {
					$error .= "Equipment $equip_id not found.<br>";
				} else {
					sql::insert( $log, $dbh, 'tbl_Equipment_Specifications', [
							'lngEquipmentIndex',    $equipment{$equip_id},
							'dblMin',               ( $min ne '' ? $min : undef ),
							'dblMax',               ( $max ne '' ? $max : undef ),
							'strUnits',             $units,
							'strName',              $name,
							'strValue',             $value,
							'interpolate',			$interpolate,
							] );
					openprint::logs::insertLogRecord('37', "Equipment ID: " . $equipment{$equip_id} . " Name: " . $name . " Value: " . $value . " Units: " . $units,);
				} # end if
			} # end for each
		} # end foreach
		sql::end_transaction( $openprint::dbh );
	} else {
		$error .= "No file given to upload.<br>";
	} # end if
	return $error;

} # end sub import_specs

sub export_specs {
	my ( $r, $log, $dbh, $variable, $Equipment ) = @_;
	my @header = ( 'Equipment ID', 'Field Name','Min', 'Max', 'Units', 'Value','Interpolate' );

	my @data;
	foreach my $Spec ( openprint::EquipmentSpecification::find( 'equipment_id'=>$Equipment->id(), 'order'=>'strName, dblmin' ) ) {
		push @data, $Spec->Equipment()->strid(), $Spec->name(), $Spec->min(), $Spec->max(), $Spec->units(), $Spec->value(), $Spec->interpolate();
	} # end foreach

	misc::export_csv( $r, $log, $variable, 'equipment_specifications'.($Equipment->id()?'_'.$Equipment->strid():'').'.csv', \@header, \@data );
	openprint::logs::insertLogRecord('38',);
} # end sub export_specs

sub edit {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $Equipment = new openprint::Equipment( $openprint::param{'ddmEquipment'} );

	if ( $openprint::param{'btnFunction'} eq '>>' ) {
		$Equipment = $Equipment->Next();
	} elsif ( $openprint::param{'btnFunction'} eq '<<' ) {
		$Equipment = $Equipment->Previous();
	} elsif ( $openprint::param{'btnFunction'} eq 'Copy' ) {
		$Equipment = $Equipment->copy();
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		$Equipment->save( \%openprint::param );
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$Equipment->delete();
		$Equipment = $Equipment->Next();
	} elsif ( $openprint::param{'btnFunction'} eq 'Import Specifications' ) {
		if ( ( my $error = import_specs( $r, $log, $dbh, $variable, $Equipment ) ) ) {
			return misc::error( $log, $dbh, $variable, 'The following errors occurred:', $error );
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Export Specifications' ) {
		export_specs( $r, $log, $dbh, $variable, $Equipment );
	} # end if

	$$variable{'Equipment'} = $Equipment;
} # end sub equipment_edit

sub _specification {
	my $Specification = new openprint::EquipmentSpecification( $openprint::param{'id'} );
	if ( $openprint::param{'field'} eq 'name' ) {
	} elsif ( $openprint::param{'field'} eq 'min' ) {
		$openprint::param{'value'} =~ s/[^\d\.]//g;
	} elsif ( $openprint::param{'field'} eq 'max' ) {
		$openprint::param{'value'} =~ s/[^\d\.]//g;
	} elsif ( $openprint::param{'field'} eq 'value' ) {
	} elsif ( $openprint::param{'field'} eq 'units' ) {
	} # end if
	$$Specification{$openprint::param{'field'}} = $openprint::param{'value'};
	$Specification->save();
	$openprint::variable{'PageContent'} = $$Specification{$openprint::param{'field'}};
} # end sub _specification

1;

__END__

