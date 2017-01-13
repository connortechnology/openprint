#!/usr/bin/perl
use lib '/var/www/testing/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Project;
require openprint::service;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'database'} = 'topknotch' if ! $sql_server{'database'};
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'login'} = $sql_server{'database'} if ! $sql_server{'login'};
$sql_server{'password'} = $ARGV[2];
$sql_server{'password'} = $sql_server{'login'} if ! $sql_server{'password'};

$openprint::Object::no_cache = 1;
my $projects_count = 100;
my $project_id = 112143;
my $company_id = 0;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;

my $ServiceType = openprint::ServiceType->find_one('name'=>'Signature');
if ( ! $ServiceType ) {
	$ServiceType = new openprint::ServiceType();
	$ServiceType->save({'name'=>'Signature','description'=>'Signature','url'=>'prin/Signature.html','view_visible'=>1,'category'=>'Printing','type'=>'Printing'});
}

foreach my $Project ( openprint::Project->find( 'order'=>'id desc',
	( $project_id ? ( 'id'=>$project_id) : () ),
	( $company_id ? ('company_id'=>$company_id) : () ),
	'limit'=>$projects_count ) ) {
	my $services = $Project->services();

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] ) if $$services{''};

	foreach my $sig_id ( $Project->signatures() ) {
		next if ! $sig_id;
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		if ( $$sig_specs{'ServiceType'} eq 'AdditionalSignature' ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ServiceType', 'Signature' );
		} # end if
	} # end foreach sig_id
	openprint::service::init_cache();
} # end foreach Project
openprint::Object::init_cache();
if ( 1 ) {
	foreach my $Project ( openprint::Project->find( 'order'=>'id desc',
( $project_id ? ( 'id'=>$project_id) : () ),
( $company_id ? ('company_id'=>$company_id) : () ),
'limit'=>$projects_count  ) ) {
		# Skip multipage projects
		next if sets::isin( $Project->Type()->name(), [ 'MultiPage', 'Newsletters','Magazines','Calendars' ] );
		my $services = $Project->services();
		next if $$services{'Signature'};
		next if ! $$services{''};
		next if ! $$services{''}[0];
		my $print_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
		my $new_signature = $Project->copy_signature( $print_specs, {}, openprint::service::status( $Project->id(), $$services{''}[0] ) );
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $$services{''}[0], 'txtPrice'.$qty_index, 0 );
		} # end foreach
            if ( $$services{'Folding'} ) {
                foreach my $service ( @{$$services{'Folding'}} ) {
                    my $specs = openprint::service::get_specs_ref( $Project, $service );
                    foreach my $qty_index ( $Project->quantity_indexes() ) {
                        if ( $$specs{"ddmEquipment-0-$qty_index"} and ! $$specs{"ddmEquipment-1-$qty_index"} ) {
                            openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, "ddmEquipment-1-$qty_index", $$specs{"ddmEquipment-0-$qty_index"} );
                            openprint::service::delete_service_spec( $Project->id(), $service, "ddmEquipment-0-$qty_index" );
                        } # end if
                    }
                } # end foraech service
            } # end if
            if ( $$services{'Proofs'} ) {
                foreach my $service ( @{$$services{'Proofs'}} ) {
                    my $specs = openprint::service::get_specs_ref( $Project, $service );
                    foreach my $key ( keys %{$specs} ) {
                        if ( $key =~ /^txtProofIndex-0-(\d*)-(\d*)$/ ) {
                            my ( $proof_index, $qty_index ) = ( $1, $2 );

                            foreach my $spec (
                                    'txtProofWidth',
                                    'txtProofHeight',
                                    'txtProofQuantity',
                                    'ddmProofType',
                                    'txtProofUnitPrice',
                                    'txtProofIndex',
                                    'chkOverride',) {

                                openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, "$spec-1-$proof_index-$qty_index", $$specs{"$spec-0-$proof_index-$qty_index"} );
                                openprint::service::delete_service_spec( $Project->id(), $service, "$spec-0-$proof_index-$qty_index" );
                            } # end foreach spec
                        } # end if
                    } # end foreach key
                } # end foraech service
            } # end if Proofs
            if ( $$services{'Cutting'} ) {
                foreach my $service ( @{$$services{'Cutting'}} ) {
                    my $specs = openprint::service::get_specs_ref( $Project, $service );
                    foreach my $spec ( "txtStockCalliper-", "chkOverrideCalliper-", "txtAdditionalCuts" ) {
                        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, $spec.'1', $$specs{$spec.'0'} );
                        openprint::service::delete_service_spec( $Project->id(), $service, $spec.'0' );
                    } # end foreach
                    foreach my $spec (
                            "txtCalculatedCuts",
                            "ddmEquipment",
                            "ddmStockCutEquipment",
                            "chkOverrideStockCutEquipment",
                            "chkOverrideCalculatedCuts",
                            "OverrideVerticalCuts",
                            "txtVerticalCuts",
                            "OverrideHorizontalCuts",
                            "txtHorizontalCuts",
                            "OverrideDVerticalCuts",
                            "txtDVerticalCuts",
                            "OverrideDHorizontalCuts",
                            "txtDHorizontalCuts",
                            ) {
                        foreach my $qty_index ( $Project->quantity_indexes() ) {
                            openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, "$spec-1-$qty_index", $$specs{"$spec-0-$qty_index"} );
                            openprint::service::delete_service_spec( $Project->id(), $service, "$spec-0-$qty_index" );
                        } # end foreach qty
                    } # end foreach spec
                } # end foraech service
            } # end if Cutting
            if ( $$services{'Perforating'} ) {
                foreach my $service_id ( @{$$services{'Perforating'}} ) {
                    my $specs = openprint::service::get_specs_ref( $Project, $service_id );
                    foreach my $spec ( 'txtHorizontalQty', 'txtVerticalQty' ) {
                        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $spec.'-1', $$specs{$spec.'-0'} );
                        openprint::service::delete_service_spec( $Project->id(), $service_id, $spec.'0' );
                    } # end foreach specs
                    foreach my $spec ( 'txtLayoutWidth','txtLayoutHeight','txtImposition' ) {
                        foreach my $qty_index ( $Project->quantity_indexes() ) {
                            openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, "$spec-1-$qty_index", $$specs{"$spec-0-$qty_index"} );
                            openprint::service::delete_service_spec( $Project->id(), $service_id, "$spec-0-$qty_index" );
                        } # end foreach qty_index
                    } # end foreach spec

                } # end foreach service_id in Perforating
            } # end if Perforating
           if ( $$services{'Scoring'} ) {
                foreach my $service_id ( @{$$services{'Scoring'}} ) {
                    my $specs = openprint::service::get_specs_ref( $Project, $service_id );
                    foreach my $spec ( 'txtHorizontalQty', 'txtVerticalQty' ) {
                        openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $spec.'-1', $$specs{$spec.'-0'} );
                        openprint::service::delete_service_spec( $Project->id(), $service_id, $spec.'0' );
                    } # end foreach specs
                    foreach my $spec ( 'txtLayoutWidth','txtLayoutHeight','txtImposition','chkOverrideImposition', 'ddmEquipment','chkOverrideEquipment' ) {
                        foreach my $qty_index ( $Project->quantity_indexes() ) {
                            openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, "$spec-1-$qty_index", $$specs{"$spec-0-$qty_index"} );
                            openprint::service::delete_service_spec( $Project->id(), $service_id, "$spec-0-$qty_index" );
                        } # end foreach qty_index
                    } # end foreach spec

                } # end foreach service_id in Scoring
            } # end if Scoring

	} # end foreach Project
	# Only Multipage and Scratch pads have a spceific page, everything else, uses the Signature ServiceType
	$dbh->do(q`UPDATE project_types set url=NULL WHERE url='prin/Signature.html'`);
}
$dbh->do(q`DELETE FROM projecttype_defaults where name='rdbAqueousSideOne'`);
$dbh->do(q`DELETE FROM projecttype_defaults where name='rdbAqueousSideTwo'`);
$dbh->do(q`DELETE FROM projecttype_defaults where name='rdbGripHeight'`);
$dbh->do(q`DELETE FROM projecttype_defaults where name='rdbGripWidth'`);
$dbh->do(q`DELETE FROM projecttype_defaults where name='rdbWaxFree'`);
require openprint::ProjectType_Default;
require openprint::ServiceType_Default;
my $ServiceType = openprint::ServiceType->find_one('name'=>'Signature');
if ( ! $ServiceType ) {
	die 'Should have Signature by now';
}

# Copy ProjectType Defaults into ServiceType Defaults
foreach my $Default ( openprint::ProjectType_Default->find('projecttype'=>'Letterhead') ) {
	my $SD = new openprint::ServiceType_Default();
	$_ = $SD->save({	
			'name'			=>	$Default->name(),
			'value'			=>	$Default->value(),
			'projecttype_id'=>	$Default->projecttype_id(),
			'servicetype_id'	=>	$ServiceType->id(),
			} );
	die $_ if $_;
	$Default->destroy();
} # end foreach
foreach my $Default ( openprint::ProjectType_Default->find('projecttype'=>undef) ) {
	my $SD = new openprint::ServiceType_Default();
	$SD->save({	
			'name'			=>	$Default->name(),
			'value'			=>	$Default->value(),
			'projecttype_id'=>	$Default->projecttype_id(),
			'servicetype_id'	=>	$ServiceType->id(),
			} );
	die $_ if $_;
	$Default->destroy();
} # end foreach
$dbh->do(q`UPDATE project_types set url=NULL where url='prin/prin_broc.html'`);

$dbh->disconnect();
	
1;
__END__
