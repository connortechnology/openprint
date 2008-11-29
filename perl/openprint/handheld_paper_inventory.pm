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

