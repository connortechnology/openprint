package openprint::handheld_paper_inventory;

use strict;
use warnings;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

require openprint::RFIDTag;
require openprint::Skid;
require openprint::Skid_Verification;
require openprint::User;
require openprint::Project;
require openprint::employee_inventory;

sub rfidtag_details {
	$param{'skid_id'} =~ s/\D//g;
	$param{'rfidtag_id'} =~ s/\D//g;
	if ( length $param{'rfidtag_id'} != 15 ) {
		$variable{'error'} = 'Invalid RFID Tag # ' . $param{'rfidtag_id'} . ' : length 15 != ' . length $param{'rfidtag_id'};
		return;
	} # end if
	@variable{'skid_id','rfidtag_id'} = @param{'skid_id','rfidtag_id'};

	if ( ! $param{'rfidtag_id'} ) {
		$variable{'error'} .= 'Please specify the tag id.<br/>';
		return;
	} # end if
	my $TAG = new openprint::RFIDTag( $param{'rfidtag_id'} );
	if ( ! $TAG->id() ) {
		my $error = $TAG->save({'id'=>$param{'rfidtag_id'}});
		if ( ! $error ) {
			$variable{'information'} .= 'Tag created.<br/>';
		} else {
			$variable{'error'} .= 'Error creating tag: ' . $error . '<br/>';
			return;
		} # end if
	} # end if

	if ( $param{'btnFunction'} eq 'Go' ) {
		delete $param{'location_id'};
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$TAG->location_id( $param{'location_id'} ) if $param{'location_id'};
		if ( $TAG->type() eq 'Skid' ) {
			my $Skid = $TAG->Skid();

			if ( ! $Skid->id() ) {
				$Skid->id( $param{'skid_id'} );
				$Skid->rfidtag_id( $TAG->id() );
				$variable{'error'} .= $Skid->save();
				if ( $Skid->empty() ) {
					$variable{'information'} .= sprintf('Skid <a href="/handheld/paper_inventory/skid.html?skid_id=%1$d">%1$d</a> is empty.<br/>', $Skid->id() );
				} # end if
			} # end if
			my $changed = 0;
			foreach my $paper_id ( keys %{$$Skid{'Paper'}} ) {
				if ( $param{"in_stock-$paper_id"} != $$Skid{'Paper'}{$paper_id} ) {
					$changed = 1;
					$$Skid{'Paper'}{$paper_id} = $param{"in_stock-$paper_id"};
				} # end if
			} # end foreach paper on skid
			$Skid->save() if $changed;
			if ( $param{'verification_code'} ) {
				my $SV = new openprint::Skid_Verification();
				$variable{'error'} .= $SV->save({
						'user_id'	=>	$session{'user_id'},
						'skid_id'	=>	$Skid->id(),
						'code'		=>	$param{'verification_code'},
						});
			} # end if verification_code
		} # end if is a Skid
		$variable{'error'} .= $TAG->save();
		if ( ! $variable{'error'} ) {
			$log->debug("Success");
			$variable{'information'} .= 'TAG saved successfully.';
			delete $variable{'skid_id'};
		} else {
			$log->error($variable{'error'});

		} # end if
		delete $param{'location_id'};
	} # end if Save
	$variable{'RFIDTag'} = $TAG;
} # end sub rfidtag_details

sub skid {

	$param{'skid_id'} =~ s/\D//g;
	$param{'Docket'} =~ s/\D//g;
	$param{'Project'} =~ s/\D//g;
	$param{'Operator'} =~ s/\D//g;

	@variable{'skid_id','rfidtag_id','Quantity','Docket','Project','Operator'} = @param{'skid_id','rfidtag_id','Quantity','Docket','Project','Operator'};
$openprint::log->debug("SKID_ID: $variable{'skid_id'}");
	$variable{'Operator'} = $session{'user_id'} if ! $variable{'Operator'};
	my $Operator = new openprint::User( $variable{'Operator'} );
	$variable{'OperatorName'} = $Operator->name();

	my $Skid = new openprint::Skid( $variable{'skid_id'} );
	$variable{'Skid'} = $Skid;
	if ( ! $param{'skid_id'} ) {
		$variable{'error'} .= 'Please specify the skid #.<br/>';
		return;
	} elsif ( ! $Skid->id() ) {
		$variable{'error'} .= 'Invalid skid #.<br/>';
		return;
	} # end if

	if ( ! ( $param{'Quantity'} and ($param{'Docket'} or $param{'Project'} ) ) ) {
		my @data = sql::execute( $log, $dbh, q{SELECT paper_id, quantity, units, project_id FROM Paper_Allocations WHERE skid_id=?}, $variable{'skid_id'} );
		if ( @data == 4 ) {
			my ( $paper_id, $quantity, $units, $project_id ) = @data;
			my $Project = new openprint::Project( $project_id );
			$variable{'Docket'} = $Project->docket();
			$variable{'Project'} = $Project->id();
			$variable{'Quantity'} = $quantity if ! $variable{'Quantity'};
			$variable{'Units'} = $units;
			$variable{'error'} .= 'Please verify docket and quantity.';
		} elsif ( @data > 4 and $variable{'Docket'} ) {
			while ( @data ) {
				my ( $paper_id, $quantity, $units, $project_id ) = @data;
				my $Project = new openprint::Project( $project_id );
				if ( $Project->docket() == $variable{'Docket'} ) {
					$variable{'Quantity'} = $quantity if ! $variable{'Quantity'};
					$variable{'Units'} = $units;
					$variable{'error'} .= 'Please verify quantity.';
				} # end if
			} # end while
		} # end if 1 or more records
	} # end if Quantity and Docket

	if ( $param{'Quantity'} and ($param{'Docket'} or $param{'Project'} ) ) {
		if ( $param{'btnFunction'} eq 'CheckIn' ) {
			openprint::employee_inventory::check_in( @param{'skid_id','paper_id', 'Quantity','Project','Docket'} );
		} elsif ( $param{'btnFunction'} eq 'CheckOut' ) {
			openprint::employee_inventory::check_out( @param{'skid_id','paper_id', 'Quantity','Project','Docket'} );
		} # end if CHeckin/CheckOut
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		my $TAG = new openprint::RFIDTag( $param{'rfidtag_id'} );
		if ( ! $TAG->id() ) {
			my $error = $TAG->save({'id'=>$param{'rfidtag_id'}});
			if ( ! $error ) {
				$variable{'error'} .= 'Tag created.<br/>';
			} else {
				$variable{'error'} .= 'Error creating tag: ' . $error . '<br/>';
				return;
			} # end if
		} # end if
		my $Skid = new openprint::Skid( $param{'skid_id'} );
		$Skid->rfidtag_id( $param{'rfidtag_id'} );
		$variable{'error'} .= $Skid->save();
		if ( $param{'verification_code'} ) {
			my $SV = new openprint::Skid_Verification();
			$variable{'error'} .= $SV->save({
					'user_id'	=>	$session{'user_id'},
					'skid_id'	=>	$Skid->id(),
					'code'		=>	$param{'verification_code'},
					});
		} # end if
	} # end if quantity and docket
	$variable{'Skid'} = $Skid;
} # end sub skid

1;
__END__
