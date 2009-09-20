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
		$Claim->id( $param{'claim_id'} ) if ! $Claim->id();
		$Claim->filed_on( $param{'filed'} ? join('-', @param{'filed_on_year','filed_on_month','filed_on_day'} ) : undef );
		$Claim->sent_to_accounts_on( $param{'sent_to_accounts'} ? join('-', @param{'sent_to_accounts_on_year','sent_to_accounts_on_month','sent_to_accounts_on_day'} ) : undef );
		$Claim->invoiced_on( $param{'invoiced'} ? join('-', @param{'invoiced_on_year','invoiced_on_month','invoiced_on_day'} ) : undef );
		$Claim->cancelled_on( $param{'cancelled'} ? join('-', @param{'cancelled_on_year','cancelled_on_month','cancelled_on_day'} ) : undef );

		$variable{'error'} .= $Claim->save( \%param );
		foreach my $C ( $Claim->Contents() ) {
			# Save any new entries that might have been entered but not added.
			$variable{'error'} .= $C->save( {
					'quantity'		=>	sprintf('%d', $param{"qty_lbs-$$C{id}"}),
					} );
		} # end foreach Contents
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

sub _claim_content {
	if ( $param{'action'} eq 'Remove' ) {
		my $C = new openprint::Claim_Content( $param{'content_id'} );
		$variable{'type_id'} = $C->type_id();
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
		if ( $param{'rfidtag_id'} or $param{'skid_id'} ) {
			@param{'rfidtag_id','skid_id'} = misc::trim(@param{'rfidtag_id','skid_id'});
			my $Tag = new openprint::RFIDTag( $param{'rfidtag_id'} );
			$variable{'error'} .= $Tag->save({'id'=>$param{'rfidtag_id'}}) if $param{'rfidtag_id'} and ! $Tag->id();
			my $Skid = new openprint::Skid( $param{'skid_id'} );
			$Skid = $Tag->Skid() if $Tag->id() and ! $Skid->id();
$log->debug("RFID: $param{'rfidtag_id'}");
			$variable{'error'} .= $Skid->save({'rfidtag_id'=>$param{'rfidtag_id'}}) if ! $Skid->id();
			return if $variable{'error'};

			if ( $Tag->id() and sets::isin( $Tag->id(), map { $_->Skid()->rfidtag_id() } $Claim->Contents() ) ) {
				$variable{'error'} .= 'RFID Tag ' . $Tag->id() . ' has already been scanned.';
			} elsif ( $Skid->id() and sets::isin( $Skid->id(), map { $_->skid_id() } $Claim->Contents() ) ) {
				$variable{'error'} .= 'Skid ' . $Skid->id(). ' has already been scanned.';
			} else {
				my $C = new openprint::Claim_Content();
				$variable{'error'} .= $C->save( {
						'type_id'	=>	$param{'type_id'},
						'skid_id'	=>	$Skid->id(),
						'claim_id'	=>	$Claim->id(),
						'docket'	=>	$param{'docket'},
						'quantity'	=>	sprintf('%d', $param{"qty_lbs"}),
						} );
				$variable{'C'} = $C;
				$variable{'type_id'} = $param{'type_id'};
			} # end if
		} # end if
	} # end if
} # end sub _claim_content

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

1;
__END__
