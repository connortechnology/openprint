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

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub email_campaigns {
	my $Campaign = new openprint::EmailCampaign( $param{'campaign_id'} );
	if ( $param{'btnFunction'} eq 'Save' ) {
		$Campaign->save( \%param );
    } elsif ( $param{'btnFunction'} eq 'Copy' ) {
		$Campaign = $Campaign->copy();
        $Campaign->save( \%param );
    } elsif ( $param{'btnFunction'} eq 'Delete' ) {
        $Campaign->delete();
    } elsif ( $param{'btnFunction'} eq 'Run' ) {
        $variable{'Results'} = $Campaign->send();
    } elsif ( $param{'btnFunction'} eq 'TrialRun' ) {
        $variable{'Results'} = $Campaign->trial( $param{'TrialEmailAddress'} );
    } elsif ( $param{'btnFunction'} eq 'Download Recipients' ) {
        my @header = ( 'Company','Name','Email','Phone');
        my @data;
		foreach my $User ( openprint::User::find('id'=>$Campaign->recipients() ) ) {
			push @data, $User->Company()->name(), $User->name(), $User->email(), $User->phone();
		} # end foreach

        misc::export_csv( $r, $log, \%variable, $Campaign->name().' Recipients.csv', \@header, \@data );
	} # end if

	@{$variable{'Campaigns'}} = openprint::EmailCampaign::find( 'order' => 'lower(name)' );
	$variable{'campaign_id'} = $Campaign->id();

} # end sub email_campaigns

sub categories {

	my $Category = new openprint::MarketingCategory( $param{'category_id'} );

	if ( $param{'btnFunction'} eq 'View' ) {
	} elsif ( $param{'btnFunction'} eq '>>' ) {
		$Category = $Category->next();
	} elsif ( $param{'btnFunction'} eq '<<' ) {
		$Category = $Category->previous();
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$Category->save( \%openprint::param );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		$Category->delete();
		$Category = $Category->next();
	} elsif ( $param{'btnFunction'} eq 'Add' ) {
		$Category->add_company( $param{'Company'} );
		$Category->save();
	} elsif ( $param{'btnFunction'} eq 'Remove' ) {
		$Category->remove_company( $param{'chkDelete'} );
		$Category->save();
	} # end if
	$variable{'Category'} = $Category;
} # end sub categories


sub email_campaign {
	my $Campaign = new openprint::EmailCampaign( $param{'campaign_id'}) ;
	if ( $param{'btnFunction'} eq 'Run' ) {
		$variable{'Results'} = $Campaign->send();
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		$Campaign = $Campaign->copy();
		$variable{'error'} .= $Campaign->save( );
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$Campaign->save( \%param );
	} # end if
	$Campaign->load_info( \%variable ) if $Campaign;
	$variable{'Campaign'} = $Campaign;
} # end sub email_campaign

sub surveys {
	my ( $r, $log, $dbh, $variable ) = @_;

	require openprint::Survey;
    $variable{'Survey'} = new openprint::Survey( $param{'survey_id'} );
    if ( $param{'btnFunction'} eq 'Save' ) {
        $variable{'error'} = $variable{'Survey'}->save( \%param );
    } elsif ( $param{'btnFunction'} eq 'Copy' ) {
        $variable{'Survey'} = $variable{'Survey'}->copy();
        $variable{'error'} = $variable{'Survey'}->save( );
    } elsif ( $param{'btnFunction'} eq 'Delete' ) {
        $variable{'error'} = $variable{'Survey'}->delete( );
    } # end if
	
} # end sub surveys 

sub email_template {
	require openprint::EmailTemplate;

	my $Template = new openprint::EmailTemplate( $param{'template_id'}) ;
	if ( $param{'btnFunction'} eq 'Run' ) {
		$variable{'Results'} = $Template->send();
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		$Template = $Template->copy();
		$variable{'error'} .= $Template->save( );
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$Template->save( \%param );
	} # end if
	$variable{'Template'} = $Template;
} # end sub email_campaign

sub email_templates {
	require openprint::EmailTemplate;

	if ( $param{'btnFunction'} eq 'Copy' ) {
		my $Template = new openprint::EmailTemplate( $param{'template_id'}) ;
		$Template = $Template->copy();
		$variable{'error'} .= $Template->save( );
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		my $Template = new openprint::EmailTemplate( $param{'template_id'}) ;
		$variable{'error'} .= $Template->save( \%param );
	} elsif ( $param{'btnFunction'} eq 'Delete' ) {
		my $Template = new openprint::EmailTemplate( $param{'template_id'}) ;
		$variable{'error'} .= $Template->delete( );
	} # end if
} # end sub email_campaign

1;

__END__

