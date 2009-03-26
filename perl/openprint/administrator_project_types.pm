package openprint::administrator_project_types;

use strict;

require openprint::project;
require openprint::ProjectTypeCategory;
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
		if ( my @project_types = openprint::ProjectType::find( 'name' => $openprint::param{'txtGoProjectTypeID'} ) ) {
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
		$$variable{'error'} .= $ProjectType->save( {
		'name'				=> $openprint::param{'txtID'},
		'description'		=> $openprint::param{'txtName'},
		'url'				=> $openprint::param{'txtURL'},
		'sorting'			=> $openprint::param{'txtSort'},
		'required_services'	=> $openprint::param{'RequiredServices'},
		'category_id'		=> $openprint::param{'category_id'},
		});

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
			my %cache = map { $_->name(), $_->id() } openprint::ProjectType::find();
			
			openprint::logs::insertLogRecord('49', 'Import Project Types: ' );
      	
			my $ac = sql::start_transaction( $dbh );
			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $id, $name, $url, $sort ) = misc::trim( $csv->fields() );
				
				my $PT = new openprint::ProjectType( $cache{$id} );
				if ( $_ .= $PT->save({
							'id'			=>	$id,
							'description'	=>	$name,
							'url'			=>	$url,
							'sorting'		=>	$sort,
							}) ) {
					$error .= "Error saving Project Type $id : $_<br/>";
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
	    my @header = ( 'Project Type ID', 'Project Type Name', 'URL', 'Sort Order');
	    my @data = map { $_->name(), $_->description(), $_->url(), $_->sorting() } openprint::ProjectType::find('order'=>'sorting');
    	misc::export_csv( $r, $log, $variable, 'projectTypes.csv', \@header, \@data );
		# Add record to audit log - action "Export Project Types".
		openprint::logs::insertLogRecord('40',);
	} # end if
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
						'strFieldName', $name, 'strDefaultValue', $value  );
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

		$_ = "SELECT (SELECT name FROM Project_Types WHERE id=lngProjectTypeIndex) AS ID,strFieldName, strDefaultValue\n".
			"FROM tbl_ProjectType_Defaults\n".
			"ORDER BY ID, strFieldName";
		my @data = sql::execute( $log, $dbh, $_ );
		misc::export_csv( $r, $log, $variable, 'projectTypes.csv', \@header, \@data );

	} # end if
	$_ = "SELECT (SELECT name FROM Project_Types WHERE id=lngProjectTypeIndex) AS ID,strFieldName, strDefaultValue\n".
		"FROM tbl_ProjectType_Defaults\n".
		"ORDER BY ID, strFieldName";
	@{$$variable{'Defaults'}} = sql::execute( $log, $dbh, $_ );
} # end sub defaults_edit

sub templates {

	my $status = 'Error: ';

    if ( $param{'btnFunction'} eq 'Save' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $index ( sql::execute( $log, $dbh, q{SELECT id FROM ProjectTemplate WHERE ProjectType_id=?}, $param{'ddmProjectType'} ) ) {
			if ( ! $openprint::param{"type$index"} ) {
				sql::execute( undef, undef, q{DELETE FROM ProjectTemplate WHERE id=?}, $index );
			} else {
				sql::update( $log, $dbh, 'ProjectTemplate', ['id=?', $index], 
					'type',					$param{"type$index"},
					'description',			$param{"description$index"},
					'dblFinishedWidth', 	$param{"finishedwidth$index"},
					'dblFinishedHeight',	$param{"finishedheight$index"},
					'dblFlatWidth',			$param{"flatwidth$index"},
					'dblFlatHeight',		$param{"flatheight$index"},
				);

      		# Add record to audit log - action "Update Project Template".
         	openprint::logs::insertLogRecord('52', "Project Type ID: " . $param{"type$index"} . " - " . $param{"description$index"},);
         	
			} # end if
		} # end foreach	
		if ( $param{'typeNew'} ) {
			sql::insert( $log, $dbh, 'ProjectTemplate',
				'ProjectType_id',		$param{'ddmProjectType'},
				'type',					$param{"typeNew"},
				'description',			$param{"descriptionNew"},
				'dblFinishedWidth', 	$param{"finishedwidthNew"},
				'dblFinishedHeight',	$param{"finishedheightNew"},
				'dblFlatWidth',			$param{"flatwidthNew"},
				'dblFlatHeight',		$param{"flatheightNew"},
			);

   		# Add record to audit log - action "New Project Template".
      	openprint::logs::insertLogRecord('55', "Project Type ID: " . $param{"typeNew"} . " - " . $param{"descriptionNew"},);
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
			$_ = q{SELECT (SELECT name FROM Project_Types WHERE id=ProjectType_id) AS ProjectType, Type, Description, dblFinishedWidth, dblFinishedHeight, dblFlatWidth, dblFlatHeight FROM ProjectTemplate ORDER BY ProjectType,Type};
			my @data = sql::execute( $log, $dbh, $_ );
			misc::export_csv( $r, $log, \%variable, 'Project Templates - All.csv', \@header, \@data );
		} # end if

		# Add record to audit log - action "Export Project Templates".
		openprint::logs::insertLogRecord('54',);
	} # end if
} # end sub templates

1;
__END__
