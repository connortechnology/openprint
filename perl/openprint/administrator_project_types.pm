package openprint::administrator_project_types;

use strict;

require openprint::project;
require openprint::ProjectTypeCategory;
require openprint::ProjectType_Template;
require openprint::ProjectType;
require openprint::Object;
require sql;
require misc;
require openprint::logs;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session);
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;

sub edit {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $ProjectType = new openprint::ProjectType( $openprint::param{'ddmProjectType'} );

	if ( $openprint::param{'btnFunction'} eq 'Go' ) {
		if ( my @project_types = openprint::ProjectType::find( 'strid' => $openprint::param{'txtGoProjectTypeID'} ) ) {
			$ProjectType = shift @project_types;
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq '<<' ) {
		$ProjectType = $ProjectType->prev();
	} elsif ( $openprint::param{'btnFunction'} eq '>>' ) {
		$ProjectType = $ProjectType->next();
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$ProjectType->delete();
		$ProjectType = $ProjectType->next();
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		$ProjectType->strid( $openprint::param{'txtID'} );
		$ProjectType->name( $openprint::param{'txtName'} );
		$ProjectType->url( $openprint::param{'txtURL'} );
		$ProjectType->sort( $openprint::param{'txtSort'} );
		$ProjectType->required_services( $openprint::param{'RequiredServices'} );
		$ProjectType->category_id( $openprint::param{'category_id'} );
		$$variable{'error'} .= $ProjectType->save();

		sql::execute( undef, undef, 'DELETE FROM Paper_Recommendations WHERE lngProjectTypeIndex=?', $ProjectType->id() );
		foreach my $key ( keys %openprint::param ) {
			if ( $key =~ /^Paper\d*$/ ) {
				sql::insert( undef, undef, 'Paper_recommendations','lngPaperIndex',$openprint::param{$key},'lngProjectTypeIndex', $ProjectType->id() );
			} # end if
		} # end foreach
	} elsif ( $openprint::param{'btnFunction'} eq 'Import' ) {
		my $error = '';
		if ( $openprint::param{'fileImport'} ) {
			my $upload = $r->upload( 'fileImport' );
			my $io = $upload->io();
			$_ = <$io>;

			my $csv = Text::CSV_XS->new();
			my $ac = sql::start_transaction( $dbh );
			my %cache = sql::execute( $log, $dbh, 'SELECT strID, lngIndex FROM Project_Types' );
			
# Add record to audit log - action "Import Project Types".
			openprint::logs::insertLogRecord('49', "(Single Import) Project Type ID: " . $ProjectType->id() . " Project Type: " . $ProjectType->name());
			
			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $id, $name, $url, $sort ) = misc::trim( $csv->fields() );
				my @sql = (
					'strName',			$name,
					'strDetailedURL',	$url,
					'lngSort',			$sort,
				);
				if ( $cache{$id} ) {
					if ( $_ = sql::update( $log, $dbh, 'Project_Types', "lngIndex=$cache{$id}", \@sql ) ) {
						$error .= "Error updatinging Project Type $id : $_<br>";
					} # end if
				} else {
					if ( $_ = sql::insert( $log, $dbh, 'Project_Types', 'strID', $id, @sql ) ) {
						$error .= "Error inserting Project Type $id : $_<br>";
					} # end if
				} # end if
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} else {
			$log->warn( "No file given to upload." );
		} # end if
		if ( $error ne '' ) {
			return misc::error( $log, $dbh, $variable, 'Import errors.', $error );
		} # end if

	} elsif ( $openprint::param{'btnFunction'} eq 'Export' ) {
		my @header = ( 'Project ID', 'Project Name', 'URL', 'Sort Order');
		my @data = sql::execute( $log, $dbh, 'SELECT strID, strName, strDetailedUrl, lngSort FROM Project_Types ORDER BY lngSort' );
		misc::export_csv( $r, $log, $variable, 'projectTypes.csv', \@header, \@data );
		# Add record to audit log - action "Export Project Types".
		openprint::logs::insertLogRecord('40',);
	} # end if
	my @required_services;
	$$variable{'ProjectType'} = $ProjectType;
} # end sub types_edit

sub defaults_edit {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $index = $openprint::param{'ddmProjectType'};

	if ( $openprint::param{'btnFunction'} eq 'Save' ) {
		my $error = '';

		my $ac = sql::start_transaction( $openprint::dbh );

		my %cache = map { $_->strid(), $_->id() } openprint::ProjectType::find();
		sql::execute( $log, $dbh, 'DELETE FROM tbl_ProjectType_Defaults' );
		foreach my $key ( keys %openprint::param ) {
			if ( $key =~ /txtID-(.*)/ and $openprint::param{"txtName-$1"} ne '' ) {
				$error .= sql::insert( $log, $dbh, 'tbl_ProjectType_Defaults', 
						'lngProjectTypeIndex', ( $openprint::param{$key} eq '' ? undef : $cache{$openprint::param{$key}} ),
						'strFieldName', $openprint::param{"txtName-$1"},
						'strDefaultValue', $openprint::param{"txtValue-$1"}
						);
			} # end if
		} # end foreach
		sql::end_transaction( $openprint::dbh, $ac );
		
		if ( $error ne '' ) {
			return misc::error( $log, $dbh, $variable, 'Save errors.', $error );
		} # end if
	} elsif ( $openprint::param{'btnFunction'} eq 'Import' ) {
		my $error = '';
		if ( $openprint::param{'fileImport'} ne '' ) {
			my $upload = $r->upload('fileImport');
			my $io = $upload->io();
			$_ = <$io>;
			my $csv = Text::CSV_XS->new();
			my $ac = sql::start_transaction( $openprint::dbh );
			my %cache = map { $_->strid(), $_->id() } openprint::ProjectType::find();
			sql::execute( $log, $dbh, 'DELETE FROM tbl_ProjectType_Defaults' );

			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $id, $name, $value ) = misc::trim( $csv->fields() );
				if ( $id ne '' and ! $cache{$id} ) {
					$error .= "Project Type $id not found.<br>";
					next;
				} # end if
				sql::insert( $log, $dbh, 'tbl_ProjectType_Defaults', 
						'lngProjectTypeIndex', ( ( $id eq '' or $id eq 'All' ) ? undef : $cache{$id} ),
						'strFieldName', $name, 'strDefaultValue', $value	);
			} # end foreach
			sql::end_transaction( $openprint::dbh, $ac );

		} else {
			$log->warn( "No file given to upload." );
		} # end if
		if ( $error ne '' ) {
			return misc::error( $log, $dbh, $variable, 'Import errors.', $error );
		} # end if

	} elsif ( $openprint::param{'btnFunction'} eq 'Export' ) {
		my @header = ( 'Project Type ID', 'Field Name', 'Field Value');

		$_ = "SELECT (SELECT strID FROM Project_Types WHERE lngIndex=lngProjectTypeIndex) AS ID,strFieldName, strDefaultValue\n".
			"FROM tbl_ProjectType_Defaults\n".
			"ORDER BY ID, strFieldName";
		my @data = sql::execute( $log, $dbh, $_ );
		misc::export_csv( $r, $log, $variable, 'projectTypes.csv', \@header, \@data );

	} # end if
	$_ = "SELECT (SELECT strID FROM Project_Types WHERE lngIndex=lngProjectTypeIndex) AS ID,strFieldName, strDefaultValue\n".
		"FROM tbl_ProjectType_Defaults\n".
		"ORDER BY ID, strFieldName";
	@{$$variable{'Defaults'}} = sql::execute( $log, $dbh, $_ );
} # end sub defaults_edit

sub templates {

	my $status = 'Error: ';

	if ( $param{'btnFunction'} eq 'Save' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $Template ( openprint::ProjectType_Template->find('projecttype_id'=>$param{'ddmProjectType'}) ) {
			$variable{'error'} .= $Template->save({
					type				=>	$param{"type$$Template{id}"},
					description			=>	$param{"description$$Template{id}"},
					finished_width		=>	$param{"finishedwidth$$Template{id}"},
					finished_height		=>	$param{"finishedheight$$Template{id}"},
					flat_width			=>	$param{"flatwidth$$Template{id}"},
					flat_height			=>	$param{"flatheight$$Template{id}"},
					message				=>	$param{"message$$Template{id}"},
				} );
			# Add record to audit log - action "Update Project Template".
			openprint::logs::insertLogRecord('52', "Project Type ID: $$Template{type} - $$Template{description}" );
		} # end foreach Template
		if ( $param{'typeNew'} ) {
			$variable{'error'} .= new openprint::ProjectType_Template()->save({
					projecttype_id	=>	$param{ddmProjectType},
					type			=>	$param{typeNew},
					description		=>	$param{descriptionNew},
					finished_width	=>	$param{finishedwidthNew},
					finished_height	=>	$param{finishedheightNew},
					flat_width		=>	$param{flatwidthNew},
					flat_height		=>	$param{flatheightNew},
					message			=>	$param{messageNew},
				} );
			# Add record to audit log - action "New Project Template".
			openprint::logs::insertLogRecord('55', "Project Type ID: $param{typeNew} - $param{descriptionNew}",);
		} # end if
		sql::end_transaction( $dbh, $ac );
	} elsif ( $param{'btnFunction'} eq 'Import Templates' ) {
		if ( $param{'fileImport'} ) {
			my $ac = sql::start_transaction( $dbh );
			my %project_types = map { $_->strid(), $_->id() } openprint::ProjectType::find();

			if ( $param{'ddmProjectType'} ) {
				sql::execute( $log, $dbh, q{DELETE FROM ProjectTemplate WHERE ProjectType_id=?}, $param{'ddmProjectType'} );
			} else {
				sql::execute( $log, $dbh, q{DELETE FROM ProjectTemplate} );
			} # end if
			my $upload = $r->upload('fileImport');
			my $io = $upload->io();
			$_ = <$io>;
			my $csv = Text::CSV_XS->new();

			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $projecttype_id, $id, $name, $desc, $fwidth, $fheight, $width, $height );
				my @data = misc::trim( $csv->fields() );
				if ( @data == 7 ) {
					( $id, $name, $desc, $fwidth, $fheight, $width, $height ) = @data;
				} elsif ( @data == 6 ) {
					( $name, $desc, $fwidth, $fheight, $width, $height ) = @data;
				} else {
					$variable{'error'} .= "Wrong # of columns in input!<br/>";
					next;
				} # end if

				if ( $param{'ddmProjectType'} ) {
					$projecttype_id = $param{'ddmProjectType'};
				} else {
					$projecttype_id = $project_types{$id};
				} # end if

				if ( ! $projecttype_id ) {
					$variable{'error'} .= "Unknown Project Type $id<br/>";
					next;
				} # end if	
				my @params = (
						'ProjectType_id',		$projecttype_id,
						'Type',					$name,
						'Description',			$desc,
						'dblFinishedWidth',		$fwidth * 1,
						'dblFinishedHeight',	$fheight * 1,
						'dblFlatWidth',			$width * 1,
						'dblFlatHeight',		$height * 1,
						);
				if ( ($_) = sql::insert( $log, $dbh, 'ProjectTemplate', @params ) ) {
					$variable{'error'} .= "Line Entry: $_<br/><br/>";
				} # end if
			} # for each
			sql::end_transaction( $dbh, $ac );
			
		} else {
			$log->warn( "No file given to upload." );
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Export Templates' ) {
		if ( $param{'ddmProjectType'} ) {
			my ($name) = sql::execute( $log, $dbh, q{SELECT strid FROM project_types WHERE lngIndex=?}, $param{'ddmProjectType'} );
			my @header = ( 'Template Type', 'Description', 'Finished Width', 'Finished Height', 'Flat Width','Flat Height' );
			$_ = q{SELECT Type, Description, dblFinishedWidth, dblFinishedHeight, dblFlatWidth, dblFlatHeight FROM ProjectTemplate WHERE projecttype_id=? ORDER BY Type};
			my @data = sql::execute( $log, $dbh, $_, $param{'ddmProjectType'} );
			misc::export_csv( $r, $log, \%variable, "Project Templates - $name.csv", \@header, \@data );
		} else {
			my @header = ( 'Project Type', 'Template Type', 'Description', 'Finished Width', 'Finished Height', 'Flat Width','Flat Height' );
			$_ = q{SELECT (SELECT strID FROM Project_Types WHERE lngIndex=ProjectType_id) AS ProjectType, Type, Description, dblFinishedWidth, dblFinishedHeight, dblFlatWidth, dblFlatHeight FROM ProjectTemplate ORDER BY ProjectType,Type};
			my @data = sql::execute( $log, $dbh, $_ );
			misc::export_csv( $r, $log, \%variable, 'Project Templates - All.csv', \@header, \@data );
		} # end if

		# Add record to audit log - action "Export Project Templates".
		openprint::logs::insertLogRecord('54',);
	} # end if
} # end sub templates

sub _templates {
} # end sub _templates

sub _template_line {
	$variable{'Template'} = new openprint::ProjectType_Template( $param{'template_id'} );
	if ( $param{'action'} eq 'X' ) {
		if ( ! ( $variable{'error'} .= $variable{'Template'}->delete() ) ) {
			delete $variable{'Template'};
		} # end if
	} elsif ( $param{'action'} eq 'C' ) {
		$variable{'Template'} = $variable{'Template'}->copy();
		$variable{'error'} .= $variable{'Template'}->save();
	} # end if
} # end sub _template_line

1;
__END__
