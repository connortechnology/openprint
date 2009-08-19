package openprint::Estimating::Project;

use openprint ();
use vars qw( $r $log $dbh %session );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;

use strict;

require sql;
require openprint::account;
require openprint::service;
require openprint::ServiceType;
require openprint::ProjectType;
require openprint::Project;
require openprint::Currency;
require openprint::User;
require openprint::ServiceType;
require openprint::logs;
require openprint::Estimating::Multipage;

# Projects are like Orders, in that you can have several in here, but only ONE of them may be unfinished.

my @no_outputs = (
	'txtShippingPostalCode',
	'txtHoleQty','UPSShipping','HoleDrilling',
	'Aqueous','txtTotalPageQuantity','Colours',
	'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight',
	'ddmStockBrand1','ddmStockFinish1','ddmStockColour1','ddmStockWeight1',
	'ddmStockBrand2','ddmStockFinish2','ddmStockColour2','ddmStockWeight2',
	'txtHoleSize', 
	'rdbAqueousSideOne','rdbAqueousSideTwo',
	'chkProcessColourSideOne', 'chkProcessColourSideTwo',
	'TemplateType','PrintingType','FoldType','Dimensions','Turnaround',
	# Presentation Folders
	'rdbPanels','rdbPocketSize','chkPocketLeft','chkPocketRight',
	'txtQuantity1',
	'chkOverrideScoreQty',
);

# creates a new project, first clearing out any previous projects
sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

# FIrst thing: Normalize the inputs
	$$specs{'Help'} = '';
	$$specs{'alert'} = '';
	$$specs{'txtQuantity1'} =~ s/\D//g;

	my $ProjectType = new openprint::ProjectType( $$specs{'projecttype_id'} );
	my $Project = new openprint::Project( $project_index );
	$Project->Currency( openprint::Currency::get_current() );
	$Project->type_id( $ProjectType->id() );
	if ( $$specs{'txtQuantity1'} != $Project->quantity1() ) {
		sql::update( $log, $dbh, 'tbl_service_specifications', ['lngprojectindex=? and strName=?', $Project->id(), 'txtQuantity1'], 'strvalue', $$specs{'txtQuantity1'} );
	} # end if
	$Project->quantity1( $$specs{'txtQuantity1'} );
	
	$Project->mode( 'Simple' );
	$Project->design( 'ElectronicFile' );
	if ( $_ = $Project->save() ) {
		$log->error( $_ );
	} # end if

	my $services = $Project->services();
	push @{$$services{'Cutting'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'Cutting' ) if ! $$services{'Cutting'};

	if ( $$Project{'id'} ) {
		$openprint::session{'project_id'} = $Project->id();
		$$specs{'ProjectIndex'} = $$Project{'id'};

		if ( ! $$services{''} ) {
			push @{$$services{''}}, openprint::print_project::insert_project_type( $r, $log, $dbh, $$Project{'id'}, $ProjectType->name() );
		} # end if

		my %printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $$Project{'id'}, $$services{''}[0] );
		if ( $printing_specs{'ProjectType'} ne $ProjectType->name() ) {
			openprint::print_project::delete_service( $log, $dbh, $$Project{'id'}, $$services{''}[0] );
			$$services{''}[0] = openprint::print_project::insert_project_type( $r, $log, $dbh, $$Project{'id'}, $ProjectType->name() );
			%printing_specs = openprint::service::get_specifications_pairs( $log, $dbh, $$Project{'id'}, $$services{''}[0] );
		} # end if

		if ( ! sets::isin( $$specs{'Dimensions'}, ['', 'Custom'] ) ) {
			my ( $width, $height, $type ) = $$specs{'Dimensions'} =~ /([\d\.]*)x([\d\.]*)(\w*)/;
			my @args = ( $$specs{'projecttype_id'}, $width, $height );

			if ( $type eq 'Flat' ) {
				$_ = q{SELECT dblfinishedwidth::float, dblfinishedheight::float FROM projecttemplate WHERE projecttype_id=? AND dblFlatWidth=? AND dblFlatHeight=?};
				if ( $$specs{'FoldType'} ) {
					$_ .= q{ AND type=?};
					push @args, $$specs{'FoldType'};
				} # end if
				@$specs{'txtFinalWidth','txtFinalHeight'} = sql::execute( $log, $dbh, $_, @args );
				@$specs{'txtWidth','txtHeight'} = ($width, $height);
				if ( ! $$specs{'txtFinalWidth'} ) {
					if ( ( my ( $pages, $folds ) = $$specs{'FoldType'} =~ /^(\d+)pg(\d)Panel/ ) ) {
						$$specs{'txtFinalWidth'} = sprintf('%.3f', int($$specs{'txtWidth'} * 1000 / $folds)/1000 );
						$$specs{'txtFinalHeight'} = $$specs{'txtHeight'} / (($pages/2)/$folds);
					} elsif ( ( my ( $folds ) = $$specs{'FoldType'} =~ /^(\d)Panel/ ) ) {
						#$folds =~ s/\D//g;
						#$folds += 1;
						$$specs{'txtFinalWidth'} = sprintf('%.3f', int($$specs{'txtWidth'}*1000/$folds)/1000 );
						$$specs{'txtFinalHeight'} = $$specs{'txtHeight'};
					} # end if
				} # end if
			} else {
				$_ = q{SELECT dblFlatWidth::float, dblFlatHeight::float FROM projecttemplate WHERE projecttype_id=? AND dblFinishedWidth=? AND dblFinishedHeight=?};
				if ( $$specs{'FoldType'} ) {
					$_ .= q{ AND type=?};
					push @args, $$specs{'FoldType'};
				} # end if
				@$specs{'txtWidth','txtHeight'} = sql::execute( $log, $dbh, $_, @args );
				@$specs{'txtFinalWidth','txtFinalHeight'} = ($width, $height);
				if ( ! $$specs{'txtWidth'} ) {
					my $folds = $$specs{'FoldType'};
					$folds =~ s/\D//g;
					$folds += 1;
					$$specs{'txtWidth'} = $$specs{'txtFinalWidth'} * $folds;
					$$specs{'txtHeight'} = $$specs{'txtFinalHeight'};
				} # end if
			} # end if
		} else {
			$$specs{'txtWidth'} =~ s/[^\.\d]//g;
			$$specs{'txtFinalWidth'} =~ s/[^\.\d]//g;
			$$specs{'txtHeight'} =~ s/[^\.\d]//g;
			$$specs{'txtFinalHeight'} =~ s/[^\.\d]//g;
		} # end if
		if ( ! ( $$specs{'txtWidth'} and $$specs{'txtHeight'} and $$specs{'txtFinalWidth'} and $$specs{'txtFinalHeight'} ) ) {
			$$specs{'alert'} .= 'No dimensions found for this fold type.';
			return $$specs{'Status'} = 'uncalculated';
		} elsif ( ! $$specs{'txtQuantity1'} ) {
			$$specs{'alert'} .= 'Please enter the quantity.';
			return $$specs{'Status'} = 'uncalculated';
		} # end if

		if ( exists $$specs{'txtTotalPageQuantity'} ) {
			if ( ! $$specs{'txtTotalPageQuantity'} ) {
				$$specs{'alert'} .= 'Please enter the number of pages.<br/>';
				return $$specs{'Status'} = 'uncalculated';
			} # end if
			if ( $$specs{'rdbCover'} eq 'Different' ) {
				if ( ! $$specs{'ddmStockBrand1'} ) {
					$$specs{'alert'} .= 'Please select Cover Stock Brand<br/>';
					return $$specs{'Status'} = 'uncalculated';
				} # end if
				if ( ! $$specs{'ddmStockFinish1'} ) {
					$$specs{'alert'} .= 'Please select Cover Stock Finish<br/>';
					return $$specs{'Status'} = 'uncalculated';
				} # end if
				if ( ! $$specs{'ddmStockColour1'} ) {
					$$specs{'alert'} .= 'Please select Cover Stock Colour<br/>';
					return $$specs{'Status'} = 'uncalculated';
				} # end if
				if ( ! $$specs{'ddmStockWeight1'} ) {
					$$specs{'alert'} .= 'Please select Cover Stock Weight<br/>';
					return $$specs{'Status'} = 'uncalculated';
				} # end if
			} # end if
			if ( ! $$specs{'ddmStockBrand2'} ) {
                    $$specs{'alert'} .= 'Please select Interior Stock Brand<br/>';
                    return $$specs{'Status'} = 'uncalculated';
                } # end if
                if ( ! $$specs{'ddmStockFinish2'} ) {
                    $$specs{'alert'} .= 'Please select Interior Stock Finish<br/>';
                    return $$specs{'Status'} = 'uncalculated';
                } # end if
                if ( ! $$specs{'ddmStockColour2'} ) {
                    $$specs{'alert'} .= 'Please select Interior Stock Colour<br/>';
                    return $$specs{'Status'} = 'uncalculated';
                } # end if
                if ( ! $$specs{'ddmStockWeight2'} ) {
                    $$specs{'alert'} .= 'Please select Interior Stock Weight<br/>';
                    return $$specs{'Status'} = 'uncalculated';
                } # end if

				if ( $$specs{'rdbTemplateType'} eq 'SaddleStitching' and $$specs{'txtTotalPageQuantity'} % 4 ) {
                    $$specs{'alert'} .= '# of pages should be a multiple of 4<br/>';
                    return $$specs{'Status'} = 'uncalculated';
				} elsif ( $$specs{'rdbTemplateType'} eq 'PerfectBound' and $$specs{'txtTotalPageQuantity'} % 2 ) {
                    $$specs{'alert'} .= '# of pages should be a multiple of 2<br/>';
                    return $$specs{'Status'} = 'uncalculated';
				} # end if

# It's a multi-page publication
			my $ac = sql::start_transaction( $dbh );
			foreach my $spec ( 'txtWidth','txtHeight','txtFinalWidth','txtFinalHeight','txtTotalPageQuantity','rdbCover','rdbTemplateType','PrintingType' ) {
				if ( $printing_specs{$spec} ne $$specs{$spec} ) {
					openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $$services{''}[0], $spec, $$specs{$spec} );
					$printing_specs{$spec} = $$specs{$spec};
				} # end if
			} # end foreach
			sql::end_transaction( $dbh, $ac );

			# Sets up the book service
			openprint::service::internal_calc( $log, $dbh, $variable, $$Project{'id'}, $$services{''}[0], 'Multipage' );

			# Setup the colours
			if ( $$specs{'Colours'} eq '4/4' ) {
				$$specs{'chkBlackSideOne2'} = undef;
				$$specs{'chkBlackSideTwo2'} = undef;
				$$specs{'chkProcessColourSideOne2'} = 'ProcessColour';
				$$specs{'chkProcessColourSideTwo2'} = 'ProcessColour';
			} elsif ( $$specs{'Colours'} eq '4/0' ) {
				$$specs{'chkBlackSideOne2'} = undef;
				$$specs{'chkBlackSideTwo2'} = undef;
				$$specs{'chkProcessColourSideOne2'} = 'ProcessColour';
				$$specs{'chkProcessColourSideTwo2'} = '';
			} elsif ( $$specs{'Colours'} eq '4/1' ) {
				$$specs{'chkBlackSideOne2'} = undef;
				$$specs{'chkBlackSideTwo2'} = 'Black';
				$$specs{'chkProcessColourSideOne2'} = 'ProcessColour';
				$$specs{'chkProcessColourSideTwo2'} = undef;
			} elsif ( $$specs{'Colours'} eq '1/1' ) {
				$$specs{'chkBlackSideOne2'} = 'Black';
				$$specs{'chkBlackSideTwo2'} = 'Black';
				$$specs{'chkProcessColourSideOne2'} = undef;
				$$specs{'chkProcessColourSideTwo2'} = undef;
			} # end if
			@$specs{'rdbAqueousSideOne2','rdbAqueousSideTwo2'} = @$specs{'2Aqueous','2Aqueous'};

			if ( $$specs{'rdbCover'} eq 'Different' ) {
				if ( $$specs{'ColoursCover'} eq '4/4' ) {
					$$specs{'chkBlackSideOne1'} = undef;
					$$specs{'chkBlackSideTwo1'} = undef;
					$$specs{'chkProcessColourSideOne1'} = 'ProcessColour';
					$$specs{'chkProcessColourSideTwo1'} = 'ProcessColour';
				} elsif ( $$specs{'ColoursCover'} eq '4/0' ) {
					$$specs{'chkBlackSideOne1'} = undef;
					$$specs{'chkBlackSideTwo1'} = undef;
					$$specs{'chkProcessColourSideOne1'} = 'ProcessColour';
					$$specs{'chkProcessColourSideTwo1'} = undef;
				} elsif ( $$specs{'ColoursCover'} eq '4/1' ) {
					$$specs{'chkBlackSideOne1'} = undef;
					$$specs{'chkBlackSideTwo1'} = 'Black';
					$$specs{'chkProcessColourSideOne1'} = 'ProcessColour';
					$$specs{'chkProcessColourSideTwo1'} = undef;
				} # end if
			@$specs{'rdbAqueousSideOne1','rdbAqueousSideTwo1'} = @$specs{'1Aqueous','1Aqueous'};
			} # end if
# The adding of signatures will be done automatically by multipage_signatures
# This will add bindery services, and a printing service
			$$specs{'Status'} = openprint::print::multipage_signatures( $specs, $log, $dbh, $variable, $$Project{'id'}, $$services{''}[0] );
		} else {
			# Non-book
			if ( $$specs{'Colours'} eq '4/4' ) {
				$$specs{'chkBlackSideOne'} = undef;
				$$specs{'chkBlackSideTwo'} = undef;
				$$specs{'chkProcessColourSideOne'} = 'ProcessColour';
				$$specs{'chkProcessColourSideTwo'} = 'ProcessColour';
			} elsif ( $$specs{'Colours'} eq '4/0' ) {
				$$specs{'chkBlackSideOne'} = undef;
				$$specs{'chkBlackSideTwo'} = undef;
				$$specs{'chkProcessColourSideOne'} = 'ProcessColour';
				$$specs{'chkProcessColourSideTwo'} = '';
			} elsif ( $$specs{'Colours'} eq '4/1' ) {
				$$specs{'chkBlackSideOne'} = undef;
				$$specs{'chkBlackSideTwo'} = 'Black';
				$$specs{'chkProcessColourSideOne'} = 'ProcessColour';
				$$specs{'chkProcessColourSideTwo'} = undef;
			} elsif ( $$specs{'Colours'} eq '1/1' ) {
				$$specs{'chkBlackSideOne'} = 'Black';
				$$specs{'chkBlackSideTwo'} = 'Black';
				$$specs{'chkProcessColourSideOne'} = undef;
				$$specs{'chkProcessColourSideTwo'} = undef;
			} # end if
			if ( ! $$specs{'ddmStockBrand'} ) {
				$$specs{'alert'} .= 'Please select Stock Brand<br/>';
				return $$specs{'Status'} = 'uncalculated';
			} # end if
			if ( ! $$specs{'ddmStockFinish'} ) {
				$$specs{'alert'} .= 'Please select Stock Finish<br/>';
				return $$specs{'Status'} = 'uncalculated';
			} # end if
			if ( ! $$specs{'ddmStockColour'} ) {
				$$specs{'alert'} .= 'Please select Stock Colour<br/>';
				return $$specs{'Status'} = 'uncalculated';
			} # end if
			if ( ! $$specs{'ddmStockWeight'} ) {
				$$specs{'alert'} .= 'Please select Stock Weight<br/>';
				return $$specs{'Status'} = 'uncalculated';
			} # end if

			openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $$services{''}[0], 'SideOneUVCoatingType', $$specs{'SideOneCoatingType'} );
			openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $$services{''}[0], 'SideTwoUVCoatingType', $$specs{'SideTwoCoatingType'} );
			if ( 
					( $$specs{'SideOneCoatingType'} and ( $$specs{'SideOneCoatingType'} ne 'None' ) ) or
					( $$specs{'SideTwoCoatingType'} and ( $$specs{'SideTwoCoatingType'} ne 'None' ) ) 
			   ) {
				if ( ! $$services{'UVCoating'} ) {
					push @{$$services{'UVCoating'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'UVCoating' );
				} # end if
			} elsif ( $$services{'UVCoating'} ) {
				foreach ( @{$$services{'UVCoating'}} ) {
					openprint::print_project::delete_service( $log, $dbh, $$Project{'id'}, $_ );
				} # end foreach
			} # end if

			@$specs{'rdbAqueousSideOne','rdbAqueousSideTwo'} = @$specs{'Aqueous','Aqueous'};
			my $ac = sql::start_transaction( $dbh );
			foreach my $spec ( 'txtWidth','txtHeight','txtFinalWidth','txtFinalHeight', 'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight','txtQuantity1','chkProcessColourSideOne','chkProcessColourSideTwo','chkBlackSideOne','chkBlackSideTwo','rdbAqueousSideOne','rdbAqueousSideTwo','PageQuantity' ) {
				if ( $printing_specs{$spec} ne $$specs{$spec} ) {
					openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $$services{''}[0], $spec, $$specs{$spec} );
					$printing_specs{$spec} = $$specs{$spec};
				} # end if
			} # end foreach
			if ( $$specs{'PrintingType'} ) {
				openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $$services{''}[0], 'PrintingType1', $$specs{'PrintingType'} );
				openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $$services{''}[0], 'OverridePrintingType1', 'Y' );
			} else {
				openprint::service::delete_service_spec( $$Project{'id'}, $$services{''}[0], 'OverridePrintingType1' );
			} # end if
			if ( $ProjectType->name() eq 'PresentationFolders' ) {
				foreach my $spec ( 'rdbPanels','rdbPocketSize','chkPocketLeft','chkPocketRight','chkPocketCenter' ) {
					if ( $printing_specs{$spec} ne $$specs{$spec} ) {
						openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $$services{''}[0], $spec, $$specs{$spec} );
						$printing_specs{$spec} = $$specs{$spec};
					} # end if
				} # end foreach
			} else {
				openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $$services{''}[0], 'rdbTemplateType', $$specs{'FoldType'} );
			} # end if
			sql::end_transaction( $dbh, $ac );
			my $sig_specs = openprint::service::internal_calc( $log, $dbh, $variable, $$Project{'id'}, $$services{''}[0], 'Printing' );
			@$specs{'txtWidth','txtHeight','chkPocketCenter','alert','Status'} = @$sig_specs{'txtWidth','txtHeight','chkPocketCenter','alert','Status'};
			%printing_specs = %{$sig_specs};
		} # end if printing

		if ( $$specs{'Status'} eq 'uncalculated' ) {
			delete $$specs{'txtPrice1'};
			$$specs{'alert'} .= 'Problem calculating printing';
			return $$specs{'Status'};
		} # end if

		# Force a reload
		$services = $Project->services();

		#$log->debug("Adding Required Services");
		foreach my $servicetype_id ( sql::execute( $log, $dbh, q{SELECT (SELECT name FROM Service_Types WHERE id = servicetype_id ) FROM projecttype_requiredservices WHERE projecttype_id = ?}, $Project->type_id() ) ) {
			if ( ! $$services{$servicetype_id} ) {
				push @{$$services{$servicetype_id}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, $servicetype_id );
			} # end if
		} # end foreach

		# Force a reload
		$services = $Project->services();

		push @{$$services{'Proofs'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'Proofs' ) if ! $$services{'Proofs'};
$openprint::log->debug("Proofs: $$specs{'proof_type'}");
		if ( exists $$specs{'proof_type'} ) {
			my $proof_specs = openprint::service::get_specs_ref( $Project, $$services{'Proofs'}[0] );
			my %proof_indexes;
			foreach my $signature_service_index ( $Project->signatures() ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
				my $signature_index = $$sig_specs{'SignatureIndex'};
				foreach my $key ( keys %{$proof_specs} ) {
					if ( $key =~ /^txtProofIndex-$signature_index-(\d*)-1$/ ) {
						push @{$proof_indexes{$signature_index}}, $1;
					} # end if
				} # end foreach keys

				if ( ( ! sets::isin( 1, $proof_indexes{$signature_index} ) ) and $openprint::config{'Add Default Layout Proof'} eq 'Y' ) {
					push @{$proof_indexes{$signature_index}}, 1;
					openprint::Estimating::Proofs::insert_layout_proof( $log, $dbh, $$Project{id}, $$services{'Proofs'}[0], $signature_service_index, 1, 1, $proof_specs );
				} # end if
				if ( ( ! sets::isin( 2, $proof_indexes{$signature_index} ) ) and $openprint::config{'Add Default Colour Proof'} eq 'Y' ) {
					push @{$proof_indexes{$signature_index}}, 2;
					openprint::Estimating::Proofs::insert_colour_proof( $log, $dbh, $$Project{id}, $$services{'Proofs'}[0], $signature_service_index, 2, 1, $proof_specs );
				} # end if
#$openprint::log->debug("Adding press proof $openprint::config{'Add Default Press Proof'}");
				if ( ( ! sets::isin( 3, $proof_indexes{$signature_index} ) ) and $openprint::config{'Add Default Press Proof'} eq 'Y' ) {
#$openprint::log->debug("Adding press proof");
					push @{$proof_indexes{$signature_index}}, 3;
					openprint::Estimating::Proofs::insert_press_proof( $log, $dbh, $$Project{id}, $$services{'Proofs'}[0], $signature_service_index, 3, 1, $proof_specs );
				} # end if
				my $proof_index = 0;
				if ( $$specs{'proof_type'} ) {
					foreach ( @{$proof_indexes{$signature_index}} ) {
$openprint::log->debug("Looking at $_ " . $$proof_specs{"ddmProofType-$signature_index-$_-1"} . ' for ' . $$specs{'proof_type'} );
						if ( $$proof_specs{"ddmProofType-$signature_index-$_-1"} eq $$specs{'proof_type'} ) {
							$proof_index = $_;
							last;
						} # end if
					} # end foreach proof_index
					if ( ! $proof_index ) {
						$proof_index = sets::max( $proof_indexes{$signature_index} ) + 1;
	#$openprint::log->debug("Adding proof $proof_index");
						foreach my $qty_index ( $Project->quantity_indexes() ) {
							#$$proof_specs{"txtProofQuantity-$signature_index-$proof_index-$qty_index"} = 1;
							#$$proof_specs{"ddmProofType-$signature_index-$proof_index-$qty_index"} = $$specs{'proof_type'};
							#$$proof_specs{"txtProofIndex-$signature_index-$proof_index-$qty_index"} = $proof_index;
							openprint::service::insert_service_spec( $log, $dbh, $$Project{id}, $$services{'Proofs'}[0], "txtProofQuantity-$signature_index-$proof_index-$qty_index", 1);
							openprint::service::insert_service_spec( $log, $dbh, $$Project{id}, $$services{'Proofs'}[0], "txtProofWidth-$signature_index-$proof_index-$qty_index", '' );
							openprint::service::insert_service_spec( $log, $dbh, $$Project{id}, $$services{'Proofs'}[0], "txtProofHeight-$signature_index-$proof_index-$qty_index", '' );
							openprint::service::insert_service_spec( $log, $dbh, $$Project{id}, $$services{'Proofs'}[0], "ddmProofType-$signature_index-$proof_index-$qty_index", $$specs{'proof_type'} );
							openprint::service::insert_service_spec( $log, $dbh, $$Project{id}, $$services{'Proofs'}[0], "txtProofIndex-$signature_index-$proof_index-$qty_index", $proof_index );
						} # end foreach qty_index
					} # end if ! $proof_index
				} # end if $$specs{'proof_type'}

				foreach ( @{$proof_indexes{$signature_index}} ) {
					if ( ( $_ > 3 ) and ( $_ != $proof_index ) ) {
						foreach my $qty_index ( $Project->quantity_indexes() ) {

							openprint::service::insert_service_spec( $log, $dbh, $$Project{id}, $$services{'Proofs'}[0], "ddmProofType-$signature_index-$_-$qty_index", '' );
							openprint::service::insert_service_spec( $log, $dbh, $$Project{id}, $$services{'Proofs'}[0], "txtProofQuantity-$signature_index-$_-$qty_index", 0 );
						} # end foreach qty_index
					} # end if
				} # end foreach proof_index
			} # end foreach signature

		} # end if

		if ( openprint::Estimating::Folding::neccessary( $$Project{'id'} ) ) {
			#$openprint::log->debug('Adding Folding');
			push @{$$services{'Folding'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'Folding' ) if ! $$services{'Folding'};
			if ( (exists $$specs{'FoldType'}) and ((! $$specs{'FoldType'} ) or ( $$specs{'FoldType'} eq 'NoFold' )) ) {
				$$specs{'alert'} .= 'It appears that your project needs folding, but you have not selected the fold type.<br/>';
				$$specs{'Status'} = 'uncalculated';
			} # end if
		} elsif ( $$services{'Folding'} ) {
			foreach ( @{$$services{'Folding'}} ) {
$openprint::log->debug('Deleting Folding');
				openprint::print_project::delete_service( $log, $dbh, $$Project{'id'}, $_ );
			} # end foreach
			delete $$services{'Folding'};
		} # end if

		if ( $$specs{'HoleDrilling'} eq 'Y' ) {
			push @{$$services{'Drilling'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'Drilling' ) if ! $$services{'Drilling'};
			my $ac = sql::start_transaction( $dbh );
			foreach my $sid ( @{$$services{'Drilling'}} ) {
				foreach my $spec ( 'txtHoleQty','txtHoleSize' ) {
					if ( $$specs{$spec} ne '' ) {
						openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $sid, $spec, $$specs{$spec} ) 
					} else {
						@no_outputs = sets::exclude( [$spec], \@no_outputs );
					} # end if
				} # end foreach
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} elsif ( $$services{'Drilling'} ) {
			foreach ( @{$$services{'Drilling'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$Project{'id'}, $_ );
			} # end if
			delete $$services{'Drilling'};
		} # end if

		if ( ($$specs{'Scoring'} ne 'Y') and openprint::Estimating::Scoring::neccessary( $Project ) ) {
			$$specs{'Scoring'} = 'Y';
		} # end if

		if ( $$specs{'Scoring'} eq 'Y' ) {
			if ( ! $$services{'Scoring'} ) {
				push @{$$services{'Scoring'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'Scoring' );
			} # end if
			my $scoring_specs = openprint::service::get_specs_ref( $Project, $$services{'Scoring'}[0] );
			my @sigs = $Project->signatures();
			my $sig_specs = openprint::service::get_specs_ref( $Project, $sigs[0] );

			# Preload auto-calc # of scores, so we can determine if we need to override
			openprint::Estimating::Scoring::get_scores( $Project, $scoring_specs, $sig_specs );

			foreach my $sid ( @{$$services{'Scoring'}} ) {
				if ( ! ( $$specs{'chkOverrideScoreQty'} or $$scoring_specs{"txtVerticalQty-$$sig_specs{SignatureIndex}"} or $$scoring_specs{"txtHorizontalQty-$$sig_specs{SignatureIndex}"} ) ) {
					$$specs{'chkOverrideScoreQty'} = 'Y';
					$$specs{'txtScoreQty'} = 1;
				} # end if
				openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $sid, "chkOverrideQty-$$sig_specs{SignatureIndex}", $$specs{'chkOverrideScoreQty'} );
				if ( $$specs{'chkOverrideScoreQty'} eq 'Y' ) {
					openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $sid, "txtVerticalQty-$$sig_specs{SignatureIndex}", $$specs{'txtScoreQty'} );
					openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $sid, "txtHorizontalQty-$$sig_specs{SignatureIndex}", 0 );
				} # end if
			} # end foreach
		} else {
			foreach ( @{$$services{'Scoring'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$Project{'id'}, $_ );
			} # end foreach
			delete $$services{'Scoring'};
		} # end if

		if ( $$specs{'Perfing'} eq 'Y' ) {
			push @{$$services{'Perforating'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'Perforating' ) if ! $$services{'Perforating'};
			foreach my $sid ( @{$$services{'Perforating'}} ) {
				openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $sid, 'txtVerticalQty-0', $$specs{'txtPerfQty'} );
				openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $sid, 'chkOverrideQty-0', 'Y' );
			} # end foreach
		} else {
			foreach ( @{$$services{'Perforating'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$Project{'id'}, $_ );
			} # end foreach
			delete $$services{'Perforating'};
		} # end if


# Handle cartons
		push @{$$services{'PlainCartons'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'PlainCartons' ) if ! $$services{'PlainCartons'};
		if ( $$specs{'UPSShipping'} eq 'Y' ) {
			push @{$$services{'UPS'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'UPS' ) if ! $$services{'UPS'};
			my $ac = sql::start_transaction( $dbh );
			foreach my $sid ( @{$$services{'UPS'}} ) {
				foreach my $spec ( 'txtShippingPostalCode' ) {
					openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $sid, $spec, $$specs{$spec} );
				} # end foreach
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} else {
			foreach my $sid ( @{$$services{'UPS'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$Project{'id'}, $sid );
			} # end foreach
			delete $$services{'UPS'};
		} # end if

		push @{$$services{'Turnaround'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'Turnaround' ) if ! $$services{'Turnaround'};


		if ( $$specs{'ShrinkWrapping'} eq 'Y' ) {
			if ( ! $$services{'ShrinkWrap'} ) {
				push @{$$services{'ShrinkWrap'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'ShrinkWrap' );
			} # end if
			openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $$services{'ShrinkWrap'}[0], 'txtItemsPerPackage', $$specs{'txtItemsPerShrinkWrap'} );

		} else {
			foreach ( @{$$services{'ShrinkWrap'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$Project{'id'}, $_ );
			} # end foreach
		} # end if

		if ( $$specs{'Bundling'} eq 'Y' ) {
			if ( ! $$services{'Bundling'} ) {
				push @{$$services{'Bundling'}}, openprint::print_project::insert_service( $log, $dbh, $$Project{'id'}, 'Bundling' );
			} # end if
			openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $$services{'Bundling'}[0], 'txtItemsPerPackage', $$specs{'txtItemsPerBundle'} );

		} else {
			foreach ( @{$$services{'Bundling'}} ) {
				openprint::print_project::delete_service( $log, $dbh, $$Project{'id'}, $_ );
			} # end foreach
		} # end if

		my $ac = sql::start_transaction( $dbh );
		foreach my $sid ( @{$$services{'Turnaround'}} ) {
			foreach my $spec ( 'TurnaroundDays' ) {
				openprint::service::insert_service_spec( $log, $dbh, $$Project{'id'}, $sid, $spec, $$specs{$spec} );
			} # end foreach
		} # end foreach
		sql::end_transaction( $dbh, $ac );
$openprint::log->warn("Before auto");
		$$specs{'alert'} .= openprint::service::auto_calculate( $r, $log, $dbh, $variable, $$Project{'id'} );
$openprint::log->warn("Aftere auto");

		if ( $$services{'Scoring'} ) {
			my $score_specs = openprint::service::get_specs_ref( $$Project{'id'}, $$services{'Scoring'}[0] );
			if ( $$specs{'chkOverrideScoreQty'} ne 'Y' ) {
				$$specs{'txtScoreQty'} = 0;
				foreach my $ss_id ( $Project->signatures() ) {
					my $sig_specs = openprint::service::get_specs_ref( $$Project{'id'}, $ss_id );
					$$specs{'txtScoreQty'} += $$score_specs{'txtVerticalQty-'.$$sig_specs{'SignatureIndex'}} + $$score_specs{'txtHorizontalQty-'.$$sig_specs{'SignatureIndex'}};
				} # end foreach
			} # end if
			if ( ! $$specs{'txtScoreQty'} ) {
				$$specs{'alert'} .= 'Please enter the # of scores.';
				$$specs{'Status'} = 'uncalculated';
			} # end if
		} # end if
		if ( $$services{'Drilling'} ) {
			my $drill_specs = openprint::service::get_specs_ref( $$Project{'id'}, $$services{'Drilling'}[0] );
			$$specs{'txtHoleQty'} = $$drill_specs{'txtHoleQty'};
		} # end if

		$$specs{'txtPrice1'} = 0;
		$$specs{'txtUnitPrice1'} = 0;
# add up the prices
		if ( $$specs{'Status'} ne 'uncalculated' ) {
			foreach my $service_name ( keys %{$services} ) {
				foreach my $service_index ( @{$$services{$service_name}} ) {
					my $service_specs = openprint::service::get_specs_ref( $$Project{'id'}, $service_index );
					$$specs{'txtPrice1'} += $$service_specs{'txtPrice1'};	
$log->debug("Prices for $service_name : $$service_specs{'txtPrice1'}");
				} # end foreach service_index
			} # end foreach service_name
		} # end if
		$$specs{'txtPrice1'} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{'txtPrice1'} );
		$$specs{'txtUnitPrice1'} = sprintf( '%.2f', $$specs{'txtPrice1'}/$$specs{'txtQuantity1'} );	
		$Project->price1( $$specs{'txtPrice1'} );
		if ( $_ = $Project->save() ) {
			$log->error( $_ );
		} # end if

		my %printing_types;
		foreach my $ss_id ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $ss_id );
			$printing_types{$$sig_specs{'PrintingType1'}} = 1;
		} # end foreach
		my @printing_types = keys %printing_types;
		if ( ! @printing_types ) {
		} elsif ( @printing_types == 1 ) {
			if ( $printing_types[0] eq 'Offset' ) {
				$$specs{'alert'} .= 'This quote is for printing on an ' . join(',', keys %printing_types ) . ' press.<br/>';
			} else {
				$$specs{'alert'} .= 'This quote is for printing on a ' . join(',', keys %printing_types ) . ' press.<br/>';
			} # end if
		} else {
			$$specs{'alert'} .= 'This quote is for printing on ' . join(',', keys %printing_types ) . ' presses.<br/>';
		} # end if

	} # end if project_id
	$$specs{'Status'} = $Project->update_status( $variable );
	if ( $$specs{'Status'} ne 'Unordered' ) {
		$$specs{'alert'} = 'There was an error in calculations.  Please contact us for help.' if ! $$specs{'alert'};
		$$specs{'txtPrice1'} = '';
		$$specs{'txtUnitPrice1'} = '';
	} # end if
	delete $$variable{'Redirect'};
	return $$specs{'Status'};
} # end sub calc

1;

__END__
