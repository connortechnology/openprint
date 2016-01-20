package openprint::administrator_project_types;

use strict;

require openprint::ProjectType;
require openprint::ProjectTypeCategory;
require openprint::ProjectType_Default;
require openprint::ProjectType_Template;
require sql;
require misc;
require openprint::logs;

use openprint ();
use vars qw( $r $log $dbh %variable %param %session );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*param = \%openprint::param;
*session = \%openprint::session;

sub edit {
	my $ProjectType = new openprint::ProjectType( $param{ddmProjectType} );

	if ( $param{btnFunction} eq 'Previous' ) {
		$ProjectType = $ProjectType->prev();
	} elsif ( $param{btnFunction} eq 'Next' ) {
		$ProjectType = $ProjectType->next();
	} elsif ( $param{btnFunction} eq 'Delete' ) {
		$variable{error} .= $ProjectType->delete();
		if ( ! $variable{error} ) {
			$ProjectType = $ProjectType->next();
			$variable{ExternalRedirect} = '/administrator/project_types/edit.html?ddmProjectType='.$ProjectType->id();
		} # end if
	} elsif ( $param{btnFunction} eq 'Copy' ) {
		my @recommendations = sql::execute(undef,undef,'SELECT lngPaperIndex FROM Paper_Recommendations WHERE lngProjectTypeIndex=?', $ProjectType->id() );

		$ProjectType = $ProjectType->copy();
		$ProjectType->name('Copy of ' . $ProjectType->name() );

		my @required_services = $ProjectType->required_services();
		my @blocked_services = $ProjectType->blocked_services();

		$variable{error} .= $ProjectType->save({required_services=>\@required_services, blocked_services=>\@blocked_services });

		foreach my $paper_id ( @recommendations ) {
			sql::insert( undef, undef, 'Paper_recommendations','lngPaperIndex',$paper_id,'lngProjectTypeIndex', $ProjectType->id() );
		} # end foreach
		$variable{ExternalRedirect} = '/administrator/project_types/edit.html?ddmProjectType='.$ProjectType->id();
	} elsif ( $param{btnFunction} eq 'Save' ) {
		$variable{error} .= $ProjectType->save( \%param );

		sql::execute( undef, undef, 'DELETE FROM Paper_Recommendations WHERE lngProjectTypeIndex=?', $ProjectType->id() ) if $param{ddmProjectType};
		foreach my $key ( keys %param ) {
			if ( $key =~ /^Paper\d*$/ ) {
				sql::insert( undef, undef, 'Paper_recommendations','lngPaperIndex',$param{$key},'lngProjectTypeIndex', $ProjectType->id() );
			} # end if
		} # end foreach
		$variable{ExternalRedirect} = '/administrator/project_types/edit.html?ddmProjectType='.$ProjectType->id();
	} elsif ( $param{btnFunction} eq 'Import' ) {
		my $error = '';
		if ( $param{fileImport} ) {
			my $upload = $r->upload( 'fileImport' );
			my $io = $upload->io();
			$_ = <$io>;

			my $csv = Text::CSV_XS->new();
			my %cache = map { $_->name(), $_->id() } openprint::ProjectType->find();
			
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
			return misc::error( $log, $dbh, \%variable, 'Import errors.', $error );
		} # end if

	} elsif ( $param{btnFunction} eq 'Export' ) {
	    my @header = ( 'Name', 'Description', 'URL', 'Sort Order');
	    my @data = map { $_->name(), $_->description(), $_->url(), $_->sorting() } openprint::ProjectType->find('order'=>'sorting');
    	misc::export_csv( $r, $log, \%variable, 'projectTypes.csv', \@header, \@data );
		# Add record to audit log - action "Export Project Types".
		openprint::logs::insertLogRecord('40',);
	} # end if
	$variable{ProjectType} = $ProjectType;
} # end sub edit

sub defaults_edit {
	my $index = $param{ddmProjectType};

	if ( $param{btnFunction} eq 'Save' ) {

		my $ac = sql::start_transaction( $dbh );

		foreach my $Default ( openprint::ProjectType_Default->find( ( $index ? ( projecttype_id=>$index ) : () ) ) ) {
			if ( $param{"name-$$Default{id}"} ) {
				$variable{error} .= $Default->save({
					projecttype_id	=>	$param{"projecttype_id-$$Default{id}"},
					name			=>	$param{"name-$$Default{id}"},
					value			=>	$param{"name-$$Default{id}"},
				});
			} else {
				$variable{error} .= $Default->delete();
			} # end if
		} # end foreach
		if ( $param{'name-New'} ) {
			my $PTD = new openprint::ProjectType_Default( );
			$variable{error} .= $PTD->save({
					projecttype_id	=>	$param{'projecttype_id-New'},
					name			=>	$param{'name-New'},
					value			=>	$param{'value-New'},
					});
		} # end if
		sql::end_transaction( $dbh, $ac );
	} elsif ( $param{btnFunction} eq 'Import' ) {
		my $error = '';
		if ( $param{fileImport} ne '' ) {
			my $upload = $r->upload('fileImport');
			my $io = $upload->io();
			$_ = <$io>;
			my $csv = Text::CSV_XS->new();
			my $ac = sql::start_transaction( $dbh );
			my %cache = map { $_->name(), $_->id() } openprint::ProjectType->find();
			sql::execute( $log, $dbh, 'DELETE FROM projecttype_defaults' );

			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $id, $name, $value ) = misc::trim( $csv->fields() );
				if ( $id ne '' and ! $cache{$id} ) {
					$error .= "Project Type $id not found.<br>";
					next;
				} # end if
				my $PTD = new openprint::ProjectType_Default();
				$error .= $PTD->save({
					'projecttype_id'	=>	( ( $id eq '' or $id eq 'All' ) ? undef : $cache{$id} ),
					'name'				=>	$name,
					'value'				=>	$value,
				});
			} # end foreach
			sql::end_transaction( $dbh, $ac );

		} else {
			$log->warn( "No file given to upload." );
		} # end if
		if ( $error ne '' ) {
			return misc::error( $log, $dbh, \%variable, 'Import errors.', $error );
		} # end if

	} elsif ( $param{btnFunction} eq 'Export' ) {
		my @header = ( 'Project Type ID', 'Field Name', 'Field Value');
		openprint::ProjectType->find();

		my @data = map { $_->ProjectType()->name(), $_->name(), $_->value() } openprint::ProjectType_Default->find('order'=>'projecttype_id NULLS FIRST, lower(name)');
		misc::export_csv( $r, $log, \%variable, 'ProjectTypes.csv', \@header, \@data );

	} # end if
} # end sub defaults_edit

sub templates {

	my $status = 'Error: ';

	if ( $param{btnFunction} eq 'Save' ) {
		my $ac = sql::start_transaction( $dbh );
		foreach my $Template ( openprint::ProjectType_Template->find( projecttype_id=>$param{ddmProjectType}) ) {
			$variable{error} .= $Template->save({
					type				=>	$param{"type$$Template{id}"},
					name				=>	$param{"name$$Template{id}"},
					description			=>	$param{"description$$Template{id}"},
					finished_width		=>	$param{"finishedwidth$$Template{id}"},
					finished_height		=>	$param{"finishedheight$$Template{id}"},
					flat_width			=>	$param{"flatwidth$$Template{id}"},
					flat_height			=>	$param{"flatheight$$Template{id}"},
					message				=>	$param{"message$$Template{id}"},
					} );
			if ( $variable{error} ) {
				$dbh->rollback();
				last;
			} # end if
			# Add record to audit log - action "Update Project Template".
			(new openprint::Log())->save({action=>'Update ProjectType Template', note=>"$$Template{type} - $$Template{description}" });
		} # end foreach Template
		if ( (!$variable{error}) and $param{typeNew} ) {
			$variable{error} .= new openprint::ProjectType_Template()->save({
					projecttype_id	=>	$param{ddmProjectType},
					type			=>	$param{typeNew},
					name			=>	$param{nameNew},
					description		=>	$param{descriptionNew},
					finished_width	=>	$param{finishedwidthNew},
					finished_height	=>	$param{finishedheightNew},
					flat_width		=>	$param{flatwidthNew},
					flat_height		=>	$param{flatheightNew},
					message			=>	$param{messageNew},
				} );
			# Add record to audit log - action "New Project Template".
			(new openprint::Log())->save({action=>'New ProjectType Template', note=>"$param{typeNew} - $param{descriptionNew}" });
		} # end if
		sql::end_transaction( $dbh, $ac );
	} elsif ( $param{btnFunction} eq 'Import Templates' ) {
		if ( $param{fileImport} ) {
			my $ac = sql::start_transaction( $dbh );
			my %project_types = map { $_->name(), $_->id() } openprint::ProjectType->find();

			if ( $param{ddmProjectType} ) {
				sql::execute( $log, $dbh, q{DELETE FROM ProjectTemplate WHERE ProjectType_id=?}, $param{ddmProjectType} );
			} else {
				sql::execute( $log, $dbh, q{DELETE FROM ProjectTemplate} );
			} # end if
			my $upload = $r->upload('fileImport');
			my $io = $upload->io();
			$_ = <$io>;
			my $csv = Text::CSV_XS->new();

			while ( <$io> ) {
				my $status = $csv->parse($_);
				my ( $projecttype_id, $id, $type, $name, $desc, $fwidth, $fheight, $width, $height );
				my @data = misc::trim( $csv->fields() );
				if ( @data == 8 ) {
					( $id, $type, $name, $desc, $fwidth, $fheight, $width, $height ) = @data;
				} elsif ( @data == 7 ) {
					( $type, $name, $desc, $fwidth, $fheight, $width, $height ) = @data;
				} else {
					$variable{error} .= "Wrong # of columns in input!<br/>";
					next;
				} # end if

				if ( $param{ddmProjectType} ) {
					$projecttype_id = $param{ddmProjectType};
				} else {
					$projecttype_id = $project_types{$id};
				} # end if

				if ( ! $projecttype_id ) {
					$variable{error} .= "Unknown Project Type $id<br/>";
					next;
				} # end if	
				my @params = (
						'ProjectType_id',		$projecttype_id,
						'type',					$type,
						'name',					$name,
						'Description',			$desc,
						'dblFinishedWidth',		$fwidth * 1,
						'dblFinishedHeight',	$fheight * 1,
						'dblFlatWidth',			$width * 1,
						'dblFlatHeight',		$height * 1,
						);
				if ( ($_) = sql::insert( $log, $dbh, 'ProjectTemplate', @params ) ) {
					$variable{error} .= "Line Entry: $_<br/><br/>";
				} # end if
			} # for each
			sql::end_transaction( $dbh, $ac );
			$variable{ExternalRedirect} = '/administrator/project_types/templates.html?ddmProjectType='.$param{ddmProjectType};
			
		} else {
			$log->warn( "No file given to upload." );
		} # end if
	} elsif ( $param{btnFunction} eq 'Export Templates' ) {
		if ( $param{ddmProjectType} ) {
			my $ProjectType = new openprint::ProjectType( $param{ddmProjectType} );

			my @header = ( 'Template Type', 'Name', 'Description', 'Finished Width', 'Finished Height', 'Flat Width','Flat Height' );
			$_ = q{SELECT Type, Name, Description, dblFinishedWidth, dblFinishedHeight, dblFlatWidth, dblFlatHeight FROM ProjectTemplate WHERE projecttype_id=? ORDER BY Type};
			my @data = sql::execute( $log, $dbh, $_, $param{ddmProjectType} );
			misc::export_csv( $r, $log, \%variable, "Project Templates - $$ProjectType{name}.csv", \@header, \@data );
		} else {
			my @header = ( 'Project Type', 'Template Type', 'Name','Description', 'Finished Width', 'Finished Height', 'Flat Width','Flat Height' );
			$_ = q{SELECT (SELECT name FROM Project_Types WHERE id=ProjectType_id) AS ProjectType, Type, Name, Description, dblFinishedWidth, dblFinishedHeight, dblFlatWidth, dblFlatHeight FROM ProjectTemplate ORDER BY ProjectType,Type};
			my @data = sql::execute( $log, $dbh, $_ );
			misc::export_csv( $r, $log, \%variable, 'Project Templates - All.csv', \@header, \@data );
		} # end if

		# Add record to audit log - action "Export Project Templates".
		(new openprint::Log())->save({action=>'Export ProjectType Templates'});
	} # end if
} # end sub templates

sub _templates {
} # end sub _templates

sub _template_line {
	$variable{Template} = new openprint::ProjectType_Template( $param{template_id} );
	if ( $param{action} eq 'X' ) {
		if ( ! ( $variable{error} .= $variable{Template}->delete() ) ) {
			delete $variable{Template};
		} # end if
	} elsif ( $param{action} eq 'C' ) {
		$variable{Template} = $variable{Template}->copy();
		$variable{error} .= $variable{Template}->save();
	} # end if
} # end sub _template_line

sub _paper_recommendations {
	$variable{ProjectType} = new openprint::ProjectType( $param{projecttype_id} );
	if ( $param{btnFunction} eq 'Add' ) {
		sql::execute( undef, undef, 'DELETE FROM Paper_recommendations WHERE lngPaperIndex=? AND lngProjectTypeIndex=?', @param{'paper_id','projecttype_id'} );
		sql::insert( undef, undef, 'Paper_recommendations','lngPaperIndex',$param{paper_id},'lngProjectTypeIndex', $param{projecttype_id} );
	} elsif ( $param{btnFunction} eq 'Remove' ) {
		sql::execute( undef, undef, 'DELETE FROM Paper_recommendations WHERE lngPaperIndex=? AND lngProjectTypeIndex=?', @param{'paper_id','projecttype_id'} );
	} # end if
} # end sub _paper_recommendations

sub categories {
	my $ProjectTypeCategory = new openprint::ProjectTypeCategory( $param{category_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$variable{error} .= $ProjectTypeCategory->save(\%param);
		foreach my $pt_id ( ref $param{projecttype_id} eq 'ARRAY' ? @{$param{projecttype_id}} : $param{projecttype_id} ) {
			my $ProjectType = new openprint::ProjectType( $pt_id );
			$variable{error} .= $ProjectType->save({'category_id'=>$ProjectTypeCategory->id()});
		} # end foreach pt_id
	} elsif ( $param{btnFunction} eq 'Delete' ) {
		$variable{error} .= $ProjectTypeCategory->delete();
	} # end if
	$variable{ProjectTypeCategory} = $ProjectTypeCategory;
} # end sub categories

sub category {
	my $ProjectTypeCategory = $variable{ProjectTypeCategory} = new openprint::ProjectTypeCategory( $param{category_id} );
	if ( $param{btnFunction} eq 'Save' ) {
		$variable{error} .= $ProjectTypeCategory->save(\%param);
		foreach my $Type ( $ProjectTypeCategory->ProjectTypes() ) {
			next if sets::isin( $$Type{id}, $param{projecttype_id} );
			$variable{error} .= $Type->save({category_id=>undef});
		} # end if
		foreach my $pt_id ( ref $param{projecttype_id} eq 'ARRAY' ? @{$param{projecttype_id}} : $param{projecttype_id} ) {
			my $ProjectType = new openprint::ProjectType( $pt_id );
			$variable{error} .= $ProjectType->save({ category_id=>$ProjectTypeCategory->id()});
		} # end foreach pt_id
		$variable{ExternalRedirect} = '/administrator/project_types/categories.html' if ! $variable{error};
	} elsif ( $param{btnFunction} eq 'Delete' ) {
		$variable{error} .= $ProjectTypeCategory->delete();
		if ( ! $variable{error} ) {
			$variable{ExternalRedirect} = '/administrator/project_types/categories.html';
		}
	} # end if
} # end sub category

1;
__END__
