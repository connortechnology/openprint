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

use strict;
package openprint::marketing;

require openprint::EmailCampaign;
require openprint::MarketingCategory;
require openprint::Banner;
require openprint::Survey;
require openprint::account;

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
    if ( $param{'btnFunction'} eq 'Delete' ) {
        $variable{'error'} .= $Campaign->delete();
    } elsif ( $param{'btnFunction'} eq 'Run' ) {
        $variable{'information'} = $Campaign->send();
    } elsif ( $param{'btnFunction'} eq 'Trial' ) {
        $variable{'information'} = $Campaign->trial( new openprint::User( $openprint::session{'user_id'} )->email() );
	} # end if

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
	my $Campaign = new openprint::EmailCampaign( $param{campaign_id}) ;
	if ( $param{'btnFunction'} eq 'Save' ) {
		$param{'nextrun'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', @param{'nextrun_year','nextrun_month','nextrun_day','nextrun_hour','nextrun_minute'}, 0 ) if $param{'nextrun_year'};
		$variable{error} .= $Campaign->save( \%param );
		$variable{ExternalRedirect} = '/marketing/email_campaigns.html' if ! $variable{error};
    } elsif ( $param{'btnFunction'} eq 'Delete' ) {
        $variable{error} .= $Campaign->delete();
		$variable{ExternalRedirect} = '/marketing/email_campaigns.html' if ! $variable{error};
	} elsif ( $param{'btnFunction'} eq 'Run' ) {
		$variable{'Results'} = $Campaign->send();
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		$Campaign = $Campaign->copy();
		$variable{error} .= $Campaign->save({name=>'Copy of '.$$Campaign{name}});
    } elsif ( $param{'btnFunction'} eq 'Test' ) {
        $variable{'information'} = $Campaign->test();
	} elsif ( $param{'btnFunction'} eq 'Save' ) {
		$param{'nextrun'} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', @param{'nextrun_year','nextrun_month','nextrun_day','nextrun_hour','nextrun_minute'}, 0 );
		$Campaign->save( \%param );
    } elsif ( $param{'btnFunction'} eq 'Download Recipients' ) {
        my @header = ( 'Company','Name','Email','Phone','Last Sent On','Number of Times Sent');
        my @data;
		foreach my $user_id ( $Campaign->recipients() ) {
			my $User = new openprint::User( $user_id );
			push @data, $User->Company()->name(), $User->name(), $User->email(), $User->phone();
			my ( $last_sent, $num_times ) = sql::execute( undef, undef, 'SELECT emailsenton, numemailsent FROM emailcampaign_sent WHERE campaign_id=? AND user_id=? ORDER BY emailsenton DESC LIMIT 1', $Campaign->id(), $User->id() );
			push @data, $last_sent, $num_times;
		} # end foreach

        misc::export_csv( $r, $log, \%variable, $Campaign->name().' Recipients.csv', \@header, \@data );
    } elsif ( $param{'btnFunction'} eq 'View Recipients' ) {
		$variable{'PageContent'} = join('<br/>', map { new openprint::User( $_ )->name() } $Campaign->recipients() );
	} # end if
	$variable{'Campaign'} = $Campaign;
} # end sub email_campaign

sub surveys {
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

sub survey_responses {
    if ( $param{'btnFunction'} eq 'Delete' ) {
		sql::execute( undef, undef, 'DELETE FROM Survey_Responses WHERE survey_id=? and user_id=?', @param{'survey_id','user_id'} );
    } # end if
} # end sub survey_responses

sub email_template {
	require openprint::EmailTemplate;

	my $Template = new openprint::EmailTemplate( $param{'template_id'}) ;
	if ( $param{'btnFunction'} eq 'Run' ) {
		$variable{'Results'} = $Template->send();
	} elsif ( $param{'btnFunction'} eq 'Copy' ) {
		$variable{'error'} .= $Template->save( { name => 'Copy of ' . $Template->name() } );
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
} # end sub email_templates

sub banners {
} # end sub banners

sub subscriptions {
	my $User = $variable{User} = new openprint::User($param{user_id} ? $param{user_id} : $session{user_id});
	$User = $variable{User} = new openprint::User($session{user_id}) if ! $$User{id};
	if ( ( ! $session{user_id} ) and $param{email} ) {
		openprint::account::login();
	} # end if
	if ( $session{user_id} ) {
		if ( ( $param{action} eq 'Save' ) or ( $param{btnFunction} eq 'Login' ) ) {
			if ( ( $param{all} eq 'N' ) and ( $User->mailinglist() eq 'Y' ) ) {
				$variable{error} .= $User->save({mailinglist=>$param{all}});
				$variable{information} .= 'Unsubscribed from all email communications.<br/>' if ! $variable{error};
			} elsif ( ( $param{all} eq 'Y' ) and ( $User->mailinglist() eq 'N' ) ) {
				$variable{error} .= $User->save({mailinglist=>'Y'});
				$variable{information} .= 'Subscribed to all email communications.<br/>' if ! $variable{error};
			} else {
				$variable{information} .= ' No changes made.';
			} # end if
		} # end if	
	} # end if	
} # end sub subscriptions

1;
__END__
