package openprint::employee_claim;
use MIME::QuotedPrint;
use Text::CSV_XS;
use strict;
require sql;
require misc;
require openprint::paper;

require openprint::RFIDTag;
require openprint::Claim;
require openprint::Claim_Content;
require openprint::PurchaseOrder;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub history {
} # end sub history

sub view {
	$param{'claim_id'} =~ s/\s//g;
	my $Claim = new openprint::Claim( $param{'claim_id'} );
	if ( $param{'btnFunction'} eq 'Delete' ) {
		$variable{'error'} .= $Claim->delete();
		if ( ! $variable{'error'} ) {
			$variable{'Redirect'} = '/employee/inventory/claims.html';
			%param = ();
		} # end if
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		if ( ! $Claim->id() ) {
			$Claim->id( $param{'claim_id'} );
			$variable{'error'} .= $Claim->save();
		} # end if
		foreach my $C ( $Claim->Contents() ) {
			# Save any new entries that might have been entered but not added.
			$variable{'error'} .= $C->save( {
					'quantity'		=>	sprintf('%d', $param{"qty_lbs-$$C{id}"}),
					'cost'			=>	$param{"cost-$$C{id}"},
					'skid_id'		=>	$param{"skid_id-$$C{id}"},
					'reason'		=>	$param{"reason-$$C{id}"},
					'cost_units'	=>	$param{"cost_units-$$C{id}"},
					} );
		} # end foreach Contents
		$Claim->filed_on( $param{'filed'} ? join('-', @param{'filed_on_year','filed_on_month','filed_on_day'} ) : undef );
		$Claim->sent_to_accounts_on( $param{'sent_to_accounts'} ? join('-', @param{'sent_to_accounts_on_year','sent_to_accounts_on_month','sent_to_accounts_on_day'} ) : undef );
		$Claim->invoiced_on( $param{'invoiced'} ? join('-', @param{'invoiced_on_year','invoiced_on_month','invoiced_on_day'} ) : undef );
		$Claim->cancelled_on( $param{'cancelled'} ? join('-', @param{'cancelled_on_year','cancelled_on_month','cancelled_on_day'} ) : undef );

		$variable{'error'} .= $Claim->save( \%param );
		if ( ! $variable{'error'} ) {
			$variable{'information'} .= 'Information successfully stored.<br/>';
		} # end if
		%param = ();
	} # end if btnfunction
	$variable{'Claim'} = $Claim;
} # end sub view

sub edit {
	$variable{'Claim'} = new openprint::Claim($param{'claim_id'});
	if ( $param{'btnFunction'} eq 'Save' ) {
		my $Claim = $variable{'Claim'};
		$Claim->id( $param{'claim_id'} ) if ! $Claim->id();
		$Claim->filed_on( $param{'filed'} ? join('-', @param{'filed_on_year','filed_on_month','filed_on_day'} ) : undef );
		$Claim->sent_to_accounts_on( $param{'sent_to_accounts'} ? join('-', @param{'sent_to_accounts_on_year','sent_to_accounts_on_month','sent_to_accounts_on_day'} ) : undef );
		$Claim->invoiced_on( $param{'invoiced'} ? join('-', @param{'invoiced_on_year','invoiced_on_month','invoiced_on_day'} ) : undef );
		$Claim->cancelled_on( $param{'cancelled'} ? join('-', @param{'cancelled_on_year','cancelled_on_month','cancelled_on_day'} ) : undef );

		$variable{'error'} .= $Claim->save( \%param );
	} # end if
} # end sub edit

sub _contents {
	if ( $param{'action'} eq 'Delete' ) {
		my $C = new openprint::Claim_Content( $param{'content_id'} );
		$variable{'Claim'} = $C->Claim();
		$variable{'error'} .= $C->delete();
	} elsif ( $param{'action'} eq 'Add' ) {
		if ( ! $param{'claim_id'} ) {
			$variable{'error'} .= 'No claim id.  Please enter the claim id before adding items to it.<br/>';
			return;
		} # end if
		my $Claim = new openprint::Claim( $param{'claim_id'} );
		$variable{'Claim'} = $Claim;
		if ( $param{'claim_id'} and ! $Claim->id() ) {
			$variable{'error'} .= $Claim->save({'id'=>$param{'claim_id'}});
		} # end if
		foreach my $C ( $Claim->Contents() ) {
			if ( ( $C->skid_id() != $param{'skid_id-'.$C->id()} )
					or ( $C->reason() ne $param{'reason-'.$C->id()} )
					or ( $C->quantity() != $param{'qty_lbs-'.$C->id()} )
					or ( $C->cost() != $param{'cost-'.$C->id()} )
			   ) {
				$variable{'error'} .= $C->save( {
						'skid_id'	=>	$param{'skid_id-'.$C->id()},
						'reason'	=>	$param{'reason-'.$C->id()},
						'quantity'	=>	sprintf('%d', $param{'qty_lbs-'.$C->id()}),
						'cost'		=>	$param{'cost-'.$C->id()},
						'cost_units'	=>	$param{'cost_units-'.$C->id()},
						} );
			} # end if Content has changed
		} # end foreach C
		if ( $param{'rfidtag_id-new'} or $param{'skid_id-new'} ) {
			@param{'rfidtag_id-new','skid_id-new'} = misc::trim(@param{'rfidtag_id-new','skid_id-new'});
			my $Tag = new openprint::RFIDTag( $param{'rfidtag_id-new'} );
			$variable{'error'} .= $Tag->save({'id'=>$param{'rfidtag_id-new'}}) if $param{'rfidtag_id-new'} and ! $Tag->id();
			my $Skid = new openprint::Skid( $param{'skid_id-new'} );
			$Skid = $Tag->Skid() if $Tag->id() and ! $Skid->id();
			$variable{'error'} .= $Skid->save({'rfidtag_id'=>$param{'rfidtag_id-new'}}) if ! $Skid->id();
			return if $variable{'error'};

			if ( $Tag->id() and sets::isin( $Tag->id(), map { $_->Skid()->rfidtag_id() } $Claim->Contents() ) ) {
				$variable{'error'} .= 'RFID Tag ' . $Tag->id() . ' has already been added.<br/>';
			} elsif ( $Skid->id() and sets::isin( $Skid->id(), map { $_->skid_id() } $Claim->Contents() ) ) {
				$variable{'error'} .= 'Skid ' . $Skid->id(). ' has already been added.<br/>';
			} else {
				my $C = new openprint::Claim_Content();
				if ( ! $param{'qty_lbs-new'} ) {
					my @SkidContents  = Skid->Contents();
					if ( @SkidContents == 1 ) {
						$param{'qty_lbs-new'} = $SkidContents[0]->quantity();
					} # end if
				} # end if
				$variable{'error'} .= $C->save( {
						'claim_id'	=>	$Claim->id(),
						'skid_id'	=>	$Skid->id(),
						'reason'	=>	$param{'reason-new'},
						'quantity'	=>	sprintf('%d', $param{'qty_lbs-new'}),
						'cost'		=>	$param{'cost-new'},
						} );
				$variable{'C'} = $C;
			} # end if
		} # end if
	} # end if
} # end sub _contents

sub claims {
	if ( $param{'btnFunction'} eq 'Delete' ) {
		foreach my $claim_id ( ref $param{'claims'} eq 'ARRAY' ? @{$param{'claims'}} : split(',',$param{'claims'}) ) {
			my $Claim = new openprint::Claim( $claim_id );
			$variable{'error'} .= $Claim->delete();

		} # end foreach claim_id
	} # end if
	ssi::save_params( '/employee/inventory/claims.html', ( 'received_on_start_year','received_on_start_month','received_on_start_day','received_on_end_year','received_on_end_month','received_on_end_day','supplier_id' ) );
} # end sub claims

sub _claims {
	ssi::save_params( '/employee/inventory/claims.html', ( 'received_on_start_year','received_on_start_month','received_on_start_day','received_on_end_year','received_on_end_month','received_on_end_day','supplier_id' ) );
} # end sub _claims

sub _select_vendor {
} # end sub _select_vendor
sub _select_contact {
} # end sub _select_contact

sub _check_for_skid {
} # end sub _check_for_skid

1;
__END__
