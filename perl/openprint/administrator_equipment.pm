use strict;
package openprint::administrator_equipment;

require Text::CSV_XS;
require sql;
require misc;

require openprint::Equipment_Category;
require openprint::Equipment_Operator;
require openprint::Equipment;
require openprint::EquipmentSpecification;
require openprint::Fold;
require openprint::FoldSpecification;
require openprint::logs;
require openprint;

use vars qw($r %variable $log $dbh %config %param );
*r = \$openprint::r;
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*param = \%openprint::param;

sub import_specs {
	my ( $r, $Equipment ) = @_;

	my %equipment = map { $_->strid(), $_->id() } openprint::Equipment->find();

	my $error = '';
	if ( $param{fileSpecifications} ) {
		my $ac = sql::start_transaction( $dbh );

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
					$error .= sql::insert( undef, undef, 'tbl_Equipment_Specifications', [
							'lngEquipmentIndex',    $equipment{$equip_id},
							'dblMin',               ( $min ne '' ? $min : undef ),
							'dblMax',               ( $max ne '' ? $max : undef ),
							'strUnits',             $units,
							'strName',              $name,
							'strValue',             $value,
							'interpolate',			$interpolate,
							] );
					#openprint::logs::insertLogRecord('37', "Equipment ID: " . $equipment{$equip_id} . " Name: " . $name . " Value: " . $value . " Units: " . $units,);
				} # end if
				last if $error;
			} # end for each
			last if $error;
		} # end while
		sql::end_transaction( $dbh, $ac );
	} else {
		$error .= 'No file given to upload.<br>';
	} # end if
	return $error;

} # end sub import_specs

sub export_specs {
	my ( $Equipment ) = @_;
	my @header = ( 'Equipment ID', 'Field Name','Min', 'Max', 'Units', 'Value','Interpolate' );

	my @data;
	foreach my $Spec ( openprint::EquipmentSpecification->find( 'equipment_id'=>$Equipment->id(), 'order'=>'strName, dblmin' ) ) {
		push @data, $Spec->Equipment()->strid(), $Spec->name(), $Spec->min(), $Spec->max(), $Spec->units(), $Spec->value(), $Spec->interpolate();
	} # end foreach

	misc::export_csv( $r, $log, \%variable, 'equipment_specifications'.($Equipment->id()?'_'.$Equipment->strid():'').'.csv', \@header, \@data );
	openprint::logs::insertLogRecord('38',);
} # end sub export_specs

sub edit {
	my $Equipment = new openprint::Equipment( $param{ddmEquipment} );
	if ( $param{ddmEquipment} and ! $$Equipment{id} ) {
		$variable{error} .= "Equipment $param{ddmEquipment} not found.<br/>";
	}

	if ( $param{btnFunction} eq 'Next' ) {
		$Equipment = $Equipment->Next();
	} elsif ( $param{btnFunction} eq 'Previous' ) {
		$Equipment = $Equipment->Previous();
	} elsif ( $param{btnFunction} eq 'Copy' ) {
		if ( $Equipment->id() ) {
			$Equipment = $Equipment->copy();
		} else {
			$variable{error} .= "No equipment specified. No copy made.";
		}
	} elsif ( $param{btnFunction} eq 'Save' ) {
		$param{servicetype_id} = [ $param{servicetype_id} ] if ref $param{servicetype_id} ne 'ARRAY';
		$param{category_id} = [ $param{category_id} ] if ref $param{category_id} ne 'ARRAY';
		my @changes = $Equipment->changes( \%param );
		if ( ! ( $variable{error} = $Equipment->save( \%param ) ) ) {
			(new openprint::Log())->save({ object_type=>(ref $Equipment), object_id=>$$Equipment{id}, action=>($param{ddmEquipment}?'Edited Equipment':'Saved Equipment'), note=>join('<br/>', @changes) });
		$variable{ExternalRedirect} = '/administrator/equipment/edit.html?ddmEquipment='.$Equipment->id();
		}
	
	} elsif ( $param{btnFunction} eq 'UnDelete' ) {
		$Equipment->undelete();
		$variable{ExternalRedirect} = '/administrator/equipment/list.html';
	} elsif ( $param{btnFunction} eq 'Delete' ) {
		$Equipment->delete();
		$Equipment = $Equipment->Next();
	} elsif ( $param{btnFunction} eq 'Destroy' ) {
		$Equipment->destroy();
		$variable{ExternalRedirect} = '/administrator/equipment/list.html';
	} elsif ( $param{btnFunction} eq 'Import Specifications' ) {
		$variable{error} .= import_specs( $r, $Equipment );
	} elsif ( $param{btnFunction} eq 'Export Specifications' ) {
		export_specs( $Equipment );
	} elsif ( $param{btnFunction} eq 'Export Folds' ) {
		my @header = ( 'Equipment ID', 'Fold Type', 'Description', 'Pages', 'Horizontal Pages', 'Vertical Pages', 'Folds', 'Angles', 'Spine Direction', 'Min Imposition', 'Max Imposition', 'Min Page Width', 'Max Page Width', 'Min Page Height', 'Max Page Height', 'Min Calliper', 'Max Calliper', 'Printing Type', 'Make Ready Time', 'Make Ready Overs', 'Make Ready Units', 'Run Overs', 'Run Overs Units', 'Inline Cutting', 'When Stitching', 'When Perfect Binding', 'Spine Pasting', 'Min Weight', 'Max Weight', 'Units', 'Speed' );

		my @data;
		foreach my $Fold ( openprint::Fold->find( equipment_id=>$Equipment->id(), order=>'type, pages' ) ) {
			foreach my $Speed ( $Fold->Specifications() ) {
				push @data, $Fold->Equipment()->strid(), $Fold->type(), $Fold->name(), $Fold->pages(), $Fold->page_columns(), $Fold->page_rows(), $Fold->folds(), $Fold->angles(), $Fold->spine_direction(), $Fold->min_imposition(), $Fold->max_imposition(), $Fold->min_width(), $Fold->max_width(), $Fold->min_height(), $Fold->max_height(), $Fold->min_calliper(), $Fold->max_calliper(), $Fold->printing_type(), $Fold->makeready_time(), $Fold->makeready_overs(), $Fold->makeready_overs_units(), $Fold->run_overs(), $Fold->run_overs_units(), $Fold->cutting(), $Fold->stitching(), $Fold->perfectbind(), $Fold->spinepaste(), $Speed->min_weight(), $Speed->max_weight(), $Speed->weight_units(), $Speed->runspeed();
			} # end foreach	
		} # end foreach

		misc::export_csv( $r, $log, \%variable, 'fold_definitionss'.($Equipment->id()?'_'.$Equipment->strid():'').'.csv', \@header, \@data );
		(new openprint::Log())->save({ action=>'Export Fold Definitions' });
	} # end if

	$variable{Equipment} = $Equipment;
} # end sub equipment_edit

sub _specification {
	my $Specification = new openprint::EquipmentSpecification( $param{id} );
	my $Equipment = $Specification->Equipment();

	if ( $param{action} eq 'add' ) {
		$variable{error} .= $Specification->save({'name'=>'new','equipment_id'=>$param{equipment_id}});
	} elsif ( $param{action} eq 'delete' ) {
		if ( ! $Specification->delete() ) {
			(new openprint::Log())->save({ object_type=>(ref $Equipment), object_id=>$$Equipment{id}, action=>'Delete Equipment Specification', 
				note=>join(' => ' , @$Specification{'name','value'} ) });
			$variable{PageContent} = ' ';
		}
	} elsif ( $param{action} eq 'copy' ) {
		$Specification = $Specification->copy();
		$Specification->save();
	} elsif ( $param{action} eq 'update' ) {
		if ( $param{field} ne 'interpolate' ) {
			$param{value} =~ s/\xc2\xa0//mg;
			if ( $param{field} eq 'name' ) {
				$param{value} =~ s/\+/ /g;
			} elsif ( $param{field} eq 'min' ) {
				$param{value} =~ s/[^\d\.]//g;
			} elsif ( $param{field} eq 'max' ) {
				$param{value} =~ s/[^\d\.]//g;
			} elsif ( $param{field} eq 'value' ) {
				$param{value} = ssi::unhtmlize( $param{value} );
			} elsif ( $param{field} eq 'units' ) {
			} # end if
			(new openprint::Log())->save({ object_type=>(ref $Equipment), object_id=>$$Equipment{id}, action=>'Save Equipment Specification', 
				note=>$$Specification{name} . ' ' . $param{field} . ' from ' . join(' => ' , $$Specification{$param{field}}, $param{value} ) });
			$variable{error} .= $Specification->save({$param{field}=>$param{value}});
			$variable{PageContent} = $$Specification{$param{field}} ne '' ? $$Specification{$param{field}} : '&nbsp;';
		} else {
			$$Specification{interpolate} = ! $$Specification{interpolate};
			$$Specification{interpolate} = 1 * $$Specification{interpolate};
			$Specification->save();
			$variable{PageContent} = $$Specification{interpolate} ? 'Yes' : 'No';
		} # end if
	} # end if
	$variable{Specification} = $Specification;
} # end sub _specification

sub _fold {
	my $Fold = new openprint::Fold( $param{id} );
	if ( $param{action} eq 'add' ) {
		foreach my $k ( 'equipment_id' ) {
			$$Fold{$k} = $param{$k};
		} # end foreach
		$Fold->save();
		$variable{Fold} = $Fold;
	} elsif ( $param{action} eq 'copy' ) {
		my $NewFold = $Fold->copy();
		delete $param{id};
		$NewFold->save(\%param);
		foreach my $Spec ( $Fold->Specifications() ) {
			$Spec = $Spec->copy();
			$Spec->fold_id( $NewFold->id() );
			$Spec->save();
		} # end foreach Spec
		$variable{Fold} = $NewFold;
		$param{id} = $NewFold->id();
		
	} elsif ( $param{action} eq 'save' ) {
		my @changes = $Fold->changes( \%param );
		$variable{error} = $Fold->save(\%param);
		if ( ! $variable{error} ) {
			my $Equipment = $Fold->Equipment();
			(new openprint::Log())->save({ object_type=>(ref $Equipment), object_id=>$$Equipment{id}, action=>'Save Fold', 
				note=>$$Fold{name} . ' ' . join('<br/>', @changes ) });
		} # end if
		$variable{Fold} = $Fold;
	} elsif ( $param{action} eq 'delete' ) {
		$Fold->delete();
		$variable{PageContent} = ' ';
	} # end if
} # end sub _fold

sub _fold_specification {
	my $FoldSpecification = new openprint::FoldSpecification( $param{id} );
	if ( $param{action} eq 'add' ) {
		foreach my $k ( 'fold_id' ) {
			$$FoldSpecification{$k} = $param{$k};
		} # end foreach
		$FoldSpecification->save();
		$variable{Specification} = $FoldSpecification;
	} elsif ( $param{action} eq 'delete' ) {
		$FoldSpecification->delete();
		$variable{PageContent} = ' ';
	} elsif ( $param{action} eq 'update' ) {
		if ( $param{field} ne 'interpolate' ) {
			$$FoldSpecification{$param{field}} = $param{value};
			$FoldSpecification->save();
			$variable{PageContent} = $$FoldSpecification{$param{field}};
		} else {
			$$FoldSpecification{interpolate} = ! $$FoldSpecification{interpolate};
			$$FoldSpecification{interpolate} = 1 * $$FoldSpecification{interpolate};
			$FoldSpecification->save();
			$variable{PageContent} = $$FoldSpecification{interpolate} ? 'Yes' : 'No';
		} # end if
	} # end if
} # end sub _fold_specification

sub _stock_setting_popup {
	$variable{Equipment} = new openprint::Equipment( $param{equipment_id} );
} # end sub _stock_settings_popup

sub _stocks {
	$variable{Equipment} = new openprint::Equipment( $param{equipment_id} );
	if ( $param{action} eq 'add' ) {
		my $Setting = new openprint::Equipment_Stock_Setting();
		$variable{error} .= $Setting->save(\%param);
		%param = ();
	} # end if
	ssi::save_params('/administrator/equipment/edit.html', 'Group','Manufacturer','Name','Finish','Colour','Weight','Types', 'material_id' );
} # end sub _stocks

sub _stock_settings {
	$variable{Equipment} = new openprint::Equipment( $param{equipment_id} );
	if ( $param{action} eq 'delete' ) {
		my $Setting = new openprint::Equipment_Stock_Setting( $param{id} );
		$variable{error} .= $Setting->delete();
		%param = ();
	} elsif ( $param{action} eq 'save' ) {
		foreach my $Setting ( $variable{Equipment}->Stock_Settings() ) {
			$variable{error} .= $Setting->save({'grain'=>$param{"grain_$$Setting{id}"}});
		} # end foreach Setting
		%param = ();
	} # end if
} # end sub _stock_settings

sub _operators {
	my $Equipment = $variable{Equipment} = new openprint::Equipment( $param{equipment_id} );
	if ( $param{action} eq 'delete' ) {
		my $EO = new openprint::Equipment_Operator( { equipment_id=>$param{equipment_id}, user_id=>$param{user_id} } );
		$variable{error} .= $EO->delete();
	} elsif ( $param{action} eq 'add' ) {
		my $EO = new openprint::Equipment_Operator();
		$variable{error} .= $EO->save( { equipment_id=>$param{equipment_id}, user_id=>$param{user_id} } );
	} # end if
} # end sub _operators

sub list {
	_list();
	ssi::setup_date_select( '/administrator/equipment/list.html', 'created_on_start', '' );
	ssi::setup_date_select( '/administrator/equipment/list.html', 'created_on_end', '' );
	$openprint::session{'/administrator/equipment/list.html?deleted'} = '0' if ! exists $openprint::session{'/administrator/equipment/list.html?deleted'};
}
sub _list {
    ssi::save_params( '/administrator/equipment/list.html', (
                ( map { 'created_on_start_' . $_ } ( 'year','month','day' ) ),
				'deleted',
                ) );
}

1;
__END__
