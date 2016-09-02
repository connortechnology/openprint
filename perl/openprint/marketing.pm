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
require openprint::Sales_Log;

use vars qw( $r $log $dbh %variable %param %session %config );
*r = \$openprint::r;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*variable = \%openprint::variable;
*session = \%openprint::session;
*param = \%openprint::param;
*config = \%openprint::config;

sub email_campaigns {
	my $Campaign = new openprint::EmailCampaign( $param{campaign_id} );
    if ( $param{btnFunction} eq 'Delete' ) {
        $variable{error} .= $Campaign->delete();
    } elsif ( $param{btnFunction} eq 'Run' ) {
        $variable{information} = $Campaign->send();
    } elsif ( $param{btnFunction} eq 'Trial' ) {
        $variable{information} = $Campaign->trial( new openprint::User( $openprint::session{user_id} )->email() );
	} # end if

	$variable{campaign_id} = $Campaign->id();
	ssi::setup_date_select( $r->uri(), 'called_on_start', -30 );
	ssi::setup_date_select( $r->uri(), 'called_on_end', '' );
	$session{'/marketing/email_campaigns.html?deleted'} = '0' if ! $session{'/marketing/email_campaigns.html?deleted'};
} # end sub email_campaigns

sub _email_campaigns {

	    ssi::save_params( '/marketing/email_campaigns.html', (
                ( map { 'called_on_start_' . $_ } ( 'year','month','day' ) ),
                ( map { 'called_on_end_' . $_ } ( 'year','month','day' ) ),
				'user_id', 'deleted', 'active',
		) );
} # end sub _email_campaigns

sub categories {

	my $Category = new openprint::MarketingCategory( $param{category_id} );

	if ( $param{btnFunction} eq 'View' ) {
	} elsif ( $param{btnFunction} eq '>>' ) {
		$Category = $Category->next();
	} elsif ( $param{btnFunction} eq '<<' ) {
		$Category = $Category->previous();
	} elsif ( $param{btnFunction} eq 'Save' ) {
		$variable{error} .= $Category->save( \%openprint::param );
		if ( ! $variable{error} ) {
			$variable{Redirect} = '/marketing/categories.html?category_id='.$Category->id();
		} # end if
	} elsif ( $param{btnFunction} eq 'Delete' ) {
		$Category->delete();
		$Category = $Category->next();
	} elsif ( $param{btnFunction} eq 'Add' ) {
		$Category->add_company( $param{Company} );
		$Category->save();
	} elsif ( $param{btnFunction} eq 'Remove' ) {
		$Category->remove_company( $param{chkDelete} );
		$Category->save();
	} # end if
	$variable{Category} = $Category;
} # end sub categories


sub email_campaign {
	my $Campaign = new openprint::EmailCampaign( $param{campaign_id}) ;
	if ( $param{btnFunction} eq 'Save' ) {
		$param{nextrun} = sprintf('%.4d-%.2d-%.2d %.2d:%.2d:%.2d', @param{'nextrun_year','nextrun_month','nextrun_day','nextrun_hour','nextrun_minute'}, 0 ) if $param{nextrun_year};
		$variable{error} .= $Campaign->save( \%param );
		$variable{ExternalRedirect} = '/marketing/email_campaigns.html' if ! $variable{error};
    } elsif ( $param{btnFunction} eq 'Delete' ) {
        $variable{error} .= $Campaign->delete();
		$variable{ExternalRedirect} = '/marketing/email_campaigns.html' if ! $variable{error};
	} elsif ( $param{btnFunction} eq 'Run' ) {
		$variable{Results} = $Campaign->send();
	} elsif ( $param{btnFunction} eq 'Copy' ) {
		$Campaign = $Campaign->copy();
		$variable{error} .= $Campaign->save({name=>'Copy of '.$$Campaign{name}});
    } elsif ( $param{btnFunction} eq 'Test' ) {
        $variable{information} = $Campaign->test();
    } elsif ( $param{btnFunction} eq 'Download Recipients' ) {
        my @header = ( 'Company','Name','Email','Phone','Last Sent On','Number of Times Sent');
        my @data;
		foreach my $user_id ( $Campaign->recipients() ) {
			my $User = new openprint::User( $user_id );
			push @data, $User->Company()->name(), $User->name(), $User->email(), $User->phone();
			my ( $last_sent, $num_times ) = sql::execute( undef, undef, 'SELECT emailsenton, numemailsent FROM emailcampaign_sent WHERE campaign_id=? AND user_id=? ORDER BY emailsenton DESC LIMIT 1', $Campaign->id(), $User->id() );
			push @data, $last_sent, $num_times;
		} # end foreach

        misc::export_csv( $r, $log, \%variable, $Campaign->name().' Recipients.csv', \@header, \@data );
    } elsif ( $param{btnFunction} eq 'View Recipients' ) {
		$variable{PageContent} = join('<br/>', map { new openprint::User( $_ )->name() } $Campaign->recipients() );
	} # end if
	$variable{Campaign} = $Campaign;
} # end sub email_campaign

sub surveys {
	require openprint::Survey;
    $variable{Survey} = new openprint::Survey( $param{survey_id} );
    if ( $param{btnFunction} eq 'Save' ) {
        $variable{error} = $variable{Survey}->save( \%param );
    } elsif ( $param{btnFunction} eq 'Copy' ) {
        $variable{Survey} = $variable{Survey}->copy();
        $variable{error} = $variable{Survey}->save( );
    } elsif ( $param{btnFunction} eq 'Delete' ) {
        $variable{error} = $variable{Survey}->delete( );
    } # end if
	
} # end sub surveys 

sub survey_responses {
    if ( $param{btnFunction} eq 'Delete' ) {
		sql::execute( undef, undef, 'DELETE FROM Survey_Responses WHERE survey_id=? and user_id=?', @param{'survey_id','user_id'} );
    } # end if
} # end sub survey_responses

sub _email_template_body {
	my $Template = $variable{Template} = new openprint::EmailTemplate( $param{template_id}) ;
}
sub email_template {
	require openprint::EmailTemplate;

	my $Template = new openprint::EmailTemplate( $param{template_id}) ;
	if ( $param{btnFunction} eq 'Run' ) {
		$variable{Results} = $Template->send();
	} elsif ( $param{btnFunction} eq 'Copy' ) {
		$variable{error} .= $Template->save( { name => 'Copy of ' . $Template->name() } );
	} elsif ( $param{btnFunction} eq 'Save' ) {
		$Template->save( \%param );
	} # end if
	$variable{Template} = $Template;

	# These are for template preview
	$variable{User} = $openprint::User;
	$variable{Campaign} = new openprint::EmailCampaign();
	$variable{Email} = new openprint::Email();
} # end sub email_campaign

sub email_templates {
	require openprint::EmailTemplate;

	if ( $param{btnFunction} eq 'Copy' ) {
		my $Template = new openprint::EmailTemplate( $param{template_id}) ;
		$Template = $Template->copy();
		$variable{error} .= $Template->save( );
	} elsif ( $param{btnFunction} eq 'Save' ) {
		my $Template = new openprint::EmailTemplate( $param{template_id}) ;
		$variable{error} .= $Template->save( \%param );
	} elsif ( $param{btnFunction} eq 'Delete' ) {
		my $Template = new openprint::EmailTemplate( $param{template_id}) ;
		$variable{error} .= $Template->delete( );
	} # end if
} # end sub email_templates

sub banners {
} # end sub banners

sub subscriptions {
	my $User = $variable{User} = new openprint::User($param{user_id} ? $param{user_id} : $session{user_id});
	
	$User = $variable{User} = new openprint::User($session{user_id}) if $session{user_id} and ! $$User{id};
	# Either we are logged in and can edit, or the specified user id and that user's email address match.
	if ( $session{user_id} ) {
		if ( ! $User->can_edit() ) {
			$variable{error} .= 'You do not have access to edit this users subscriptions.';
			return;
		} # endif
	} else {
		if ( $$User{email} ne $param{email} ) {
			$variable{error} .= "User email ($$User{email}) and provided email address ($param{email}) do not match.<br/>";
			return;
		}
	} # end if

	if ( $param{action} eq 'Save' ) {
		if ( ! $openprint::session{user_id} ) {
			require Authen::Captcha;
			my $Captcha = new Authen::Captcha('data_folder' => '/tmp', 'output_folder' => $config{'SkinPath'}.'/images/captcha');
	# Remove spaces, because some people want to put spaces between the characters, etc.
			$param{'Captcha'} =~ s/\s//g;
			if ( 1 != $Captcha->check_code( @param{'Captcha','MD5SUM'} ) ) {
				$variable{error} .= 'Captcha validation code incorrect.  Please try again.';
				return;
			} # end if
		} # end if not logged in
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
} # end sub subscriptions

sub sales_log {
	ssi::setup_date_select( '/marketing/sales_log.html', 'called_on_start', -30 );
	ssi::setup_date_select( '/marketing/sales_log.html', 'called_on_end', '' );
	$session{'/marketing/sales_log.html?company_id'} = $session{company_id} if ! $session{'/marketing/sales_log.html?company_id'};
} # end sub sales_log

sub _sales_log {
	    ssi::save_params( '/marketing/sales_log.html', (
                ( map { 'called_on_start_' . $_ } ( 'year','month','day' ) ),
                ( map { 'called_on_end_' . $_ } ( 'year','month','day' ) ),
				'company_id', 'user_id', 'employee_id',
		) );

} # end sub _sales_log

sub _sales_log_line {
	 if ( $param{action} eq 'add' ) {

		if ( Date::Calc::check_date( @param{ map { 'called_on_'.$_ } ( 'year','month','day' ) } ) ) {
			my $called_on_datetime = DateTime->new( time_zone => $openprint::TZ,
					( map { $_ => int($param{'called_on_'.$_ }) } ( 'year', 'month', 'day', 'hour','minute' ) ),
					);

			my $parser = 'DateTime::Format::Pg';

			$param{called_on} = $parser->format_datetime( $called_on_datetime );
		} # end if

		my $Log = $variable{Log} = new openprint::Sales_Log();
		$variable{error} .= $Log->save({
			salesrep_id	=>	$session{user_id},
			company_id	=>	$param{company_id},
			user_id		=>	$param{user_id},	
			notes		=>	$param{notes},
			( $param{called_on} ? ( called_on	=>	$param{called_on} ) : () ),	
			});
	} # end params{action}
} # end sub _sales_log_line

sub get_clients {
		my ( $y, $m, $d ) = Date::Calc::Today();

		my $assigned_on_datetime = DateTime->new( time_zone => $openprint::TZ, year=>$y, month=>$m, day=>$d, hour=>0, minute=>0 );

		my $parser = 'DateTime::Format::Pg';
		my @Todays_Assignments = openprint::Log->find( user_id=>$session{user_id}, action => 'Get clients', 'date_time >' => $parser->format_datetime(  $assigned_on_datetime ) );
		my $todays_count = 0;
		foreach my $L ( @Todays_Assignments ) {
			my ( $count ) = $L->note() =~ /Get (\d+) clients/;
			$todays_count += $count;
		} # end foreach L	
		if ( $todays_count >= $config{ClientLotteryChunkSize} ) {
			$variable{todays_count} = $todays_count;
			$variable{error} .= 'You have already grabbed ' . $todays_count . ' new clients today.  Try again tomorrow.<br/>';
			return;
		} # end if

	if ( $param{action} eq 'get' ) {

		( $y, $m, $d ) = Date::Calc::Add_Delta_Days( ($y,$m,$d), -7 );
		my @Weeks_Assignments = openprint::Log->find( user_id=>$session{user_id}, action => 'Get clients', 'date_time >' => $parser->format_datetime(  $assigned_on_datetime ) );
		my $weekly_count = 0;
		foreach my $L ( @Weeks_Assignments ) {
			my ( $count ) = $L->note() =~ /Get (\d+) clients/;
			$weekly_count += $count;
		} # end foreach L	
		if ( $weekly_count >= $config{ClientLotteryMax} ) {
			$variable{error} .= 'You have already grabbed ' . $weekly_count . ' new clients this week.  Try again tomorrow.<br/>';
			return;
		} # end if
		my @Available_Companies = openprint::Company->find( salesrep_id=>undef, order=>'lower(name)' );	
		my @To_Be_Added;
		my $count = $config{ClientLotteryChunkSize};
		while ( $count > @To_Be_Added ) {
			my @C = splice( @Available_Companies, int(rand(@Available_Companies)), 1 );
			next if $C[0]->salesrep_id();
			push @To_Be_Added, @C;
		} # emd while

		foreach my $C ( @To_Be_Added ) {
			$variable{error} .= $C->save({ salesrep_id => $session{user_id} });
			$variable{information} .= $C->name() . ' is now your client.<br/>';
		} # end foreach C
		(new openprint::Log())->save({
			action	=> 'Get clients',
			note	=> 'Get ' . $config{ClientLotteryChunkSize} . ' clients',
		});
		$variable{ExternalRedirect} .= '/marketing/get_clients.html';
	} # end if
} # end sub get_clients

1;
__END__
