# Copyright (C) 2007 Isaac Connor <isaac@connortechnology.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

package openprint::employee_marketing;

use openprint::EmailCampaign;
use openprint::MarketingCategory;
use openprint::Survey;
use Mail::Sendmail;
use MIME::QuotedPrint;
use Email::Valid;
use strict;

sub email_campaigns {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $Campaign = new openprint::EmailCampaign( $openprint::param{'campaign_id'} );
	if ( $openprint::param{'btnFunction'} eq 'Save' ) {
		$Campaign->save( \%openprint::param );
    } elsif ( $openprint::param{'btnFunction'} eq 'Copy' ) {
		$Campaign = $Campaign->copy();
        $Campaign->save( \%openprint::param );
    } elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
        $Campaign->delete();
    } elsif ( $openprint::param{'btnFunction'} eq 'Run' ) {
        $$variable{'Results'} = $Campaign->send();
    } elsif ( $openprint::param{'btnFunction'} eq 'TrialRun' ) {
        $$variable{'Results'} = $Campaign->trial( $openprint::param{'TrialEmailAddress'} );
    } elsif ( $openprint::param{'btnFunction'} eq 'Download Recipients' ) {
        my @header = ( 'Company','Name','Email');
        my @data;
		foreach my $User ( openprint::User::find('id'=>$Campaign->recipients() ) ) {
			push @data, $User->Company()->name(), $User->name(), $User->email();
		} # end foreach

        misc::export_csv( $r, $log, $variable, $Campaign->name().' Recipients.csv', \@header, \@data );
	} # end if

	@{$$variable{'Campaigns'}} = openprint::EmailCampaign::find( 'order' => 'lower(name)' );
	$$variable{'campaign_id'} = $Campaign->id();

} # end sub email_campaigns

sub categories {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $Category = new openprint::MarketingCategory( $openprint::param{'category_id'} );

	if ( $openprint::param{'btnFunction'} eq 'View' ) {
	} elsif ( $openprint::param{'btnFunction'} eq '>>' ) {
		$Category = $Category->next();
	} elsif ( $openprint::param{'btnFunction'} eq '<<' ) {
		$Category = $Category->previous();
	} elsif ( $openprint::param{'btnFunction'} eq 'Save' ) {
		$Category->save( \%openprint::param );
	} elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
		$Category->delete();
		$Category = $Category->next();
	} elsif ( $openprint::param{'btnFunction'} eq 'Add' ) {
		$Category->add_company( $openprint::param{'Company'} );
		$Category->save();
	} elsif ( $openprint::param{'btnFunction'} eq 'Remove' ) {
		$Category->remove_company( $openprint::param{'chkDelete'} );
		$Category->save();
	} # end if
	$$variable{'Category'} = $Category;
} # end sub categories


sub email_campaign {
	my ( $r, $log, $dbh, $variable ) = @_;
	my $Campaign = new openprint::EmailCampaign( $openprint::param{'campaign_id'}) ;
	if ( $openprint::param{'btnFunction'} eq 'Run' ) {
		$$variable{'Results'} = $Campaign->send();
	} elsif ( $openprint::param{'btnFunction'} eq 'Copy' ) {
		$openprint::param{'name'} = 'Copy of ' . $openprint::param{name};
		$openprint::param{'id'} = undef;
		$Campaign->save( %openprint::param );
	} # end if
	$Campaign->load_info( $variable ) if $Campaign;
	$$variable{'Campaign'} = $Campaign;
} # end sub email_campaign

sub surveys {
	my ( $r, $log, $dbh, $variable ) = @_;

	require openprint::Survey;
    $$variable{'Survey'} = new openprint::Survey( $openprint::param{'survey_id'} );
    if ( $openprint::param{'btnFunction'} eq 'Save' ) {
        $$variable{'error'} = $$variable{'Survey'}->save( \%openprint::param );
    } elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
        $$variable{'error'} = $$variable{'Survey'}->delete();
    } elsif ( $openprint::param{'btnFunction'} eq 'Copy' ) {
        $$variable{'Survey'} = $$variable{'Survey'}->copy();
        $$variable{'error'} = $$variable{'Survey'}->save( );
    } elsif ( $openprint::param{'btnFunction'} eq 'Delete' ) {
        $$variable{'error'} = $$variable{'Survey'}->delete( );
    } # end if
	
} # end sub surveys 

1;

__END__

