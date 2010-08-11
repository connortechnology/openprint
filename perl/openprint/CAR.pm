package openprint::CAR;
@ISA = qw(openprint::Object);
require sql;
require openprint::CAR_Area;
require openprint::CAR_Reason;

use vars qw( $r %config $log $dbh %session );
*r = \$openprint::r;
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;


use strict;
use vars qw( $debug $table $serial %fields %defaults %transforms );


$debug = 1;
$table = 'cars';
$serial = 'cars_id_seq';
%fields = (
	'id'			=>	'id',
	'issued_to_id'	=> 'issued_to_id',
	'issued_on'		=> 'issued_on',
	'issued_by_id'	=> 'issued_by_id',
	'reply_by'		=> 'reply_by',
	'docket'		=> 'docket',
	'company_id'	=> 'company_id',
	'problem'		=> 'problem',
	'cause'			=> 'cause',
	'action'		=> 'action',	
	'effectiveness'	=> 'effectiveness',
	'area_id'		=> 'area_id',
	'reason_id'		=> 'reason_id',
	'presses'		=> 'presses',
	'part1_user_id'	=> 'part1_user_id',
	'part1_signed_on'	=> 'part1_signed_on',
	'part2_user_id'		=> 'part1_user_id',
	'part2_signed_on'	=> 'part2_signed_on',
	'part3_user_id'		=> 'part3_user_id',
	'part3_signed_on'	=> 'part3_signed_on',
	'part4_user_id'		=> 'part4_user_id',
	'part4_signed_on'	=> 'part4_signed_on',
	'reprint'			=> 'reprint',
	'reprint_approval'	=> 'reprint_approval',
	'artwork'			=> 'artwork',
	'reprint_on'		=> 'reprint_on',
	'reprint_charge'	=> 'reprint_charge',
	'approved_by_id'	=> 'approved_by_id',
	'created_on'		=> 'created_on',
	'approved_on'		=> 'approved_on',
	'updated_on'		=> 'updated_on',
	'printed_on'		=> 'printed_on',
	'identified_by'		=> 'identified_by',
	'deleted'			=> 'deleted',
);

%transforms = (
);
%defaults = (
	'issued_to_id'	=> undef,
	'issued_by_id'	=> undef,
	'docket'		=> undef,
	'company_id'	=> undef,
	'part1_user_id'	=> undef,
	'part2_user_id'	=> undef,
	'part3_user_id'	=> undef,
	'part4_user_id'	=> undef,
	'approved_by_id'	=> undef,
	'created_on'	=> q`'NOW()'`,
	'updated_on'	=> q`'NOW()'`,
	'approved_on'	=> undef,
	'printed_on'	=> undef,
	'deleted'		=> 0,
	'reprint'		=> undef,
	'area_id'		=> undef,
	'reason_id'		=> undef,
);

sub send_notifications {
	my ( $self ) = @_;

	my @Users = openprint::User->find('usergroup'=>'Quality Control Notifications');

	if ( @Users ) {
		my $From = new openprint::User( $session{'user_id'} );
		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );

		my %info = (
			'CAR'	=>	$self,
		);
		foreach my $User ( @Users ) {
			$info{'ReplacementText'} = '<!--#include virtual="/email_content/iso_car_notification.html"-->';
			my @body = ('', MIME::QuotedPrint::encode_qp( ssi::variable_substitution( \$email_template, \%info ) ), 'text/html', 'quoted-printable');
			my %mail = (
					SMTP    => $config{'Mail Server'},
					FROM    => sprintf( '"%s" <%s>', $From->name(), $From->email() ),
					TO      => sprintf( '"%s" <%s>', $User->name(), $User->email() ),
					SUBJECT => 'A new CAR has been generated requiring your attention.',
					);
			misc::send_email_with_attachment( $log, \%mail, @body );
		} # end foreach
	} # end if to

} # end sub send_notification

sub send_assignee_notification {
	my ($self) = @_;

	my $From = new openprint::User( $session{'user_id'} );
	my $To = new openprint::User( $$self{'issued_to_id'} );
	if ( $To->id() == $session{'user_id'} ) {
		$log->debug("Not Sending CAR Notifications becuase I am ME to " . $To->email());
	} else {
		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		my %info = (
				'CAR'	=>	$self,
				'To'    =>  $To,
				'From'  =>  $From,
				'ReplacementText' => '<!--#include virtual="/email_content/iso_car_assignee_notification.html"-->',
				);
		$_ = MIME::QuotedPrint::encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');
		my %mail = (
				SMTP    => $config{'Mail Server'},
				FROM    => sprintf( '"%s" <%s>', $From->name(), $From->email() ),
				TO      => sprintf( '"%s" <%s>', $To->name(), $To->email() ),
				SUBJECT => 'NEW CAR',
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
	} # end if
} # end sub send_assignee_notification

sub send_reprint_request_notification {
	my ($self) = @_;
	my $From = new openprint::User( $session{'user_id'} );
	foreach my $To ( openprint::User->find('usergroups'=>['Reprint Approvals']) ) {
		if ( $To->id() == $session{'user_id'} ) {
			next;
		} # end if
		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		my %info = (
				'CAR'   =>  $self,
				'To'    =>  $To,
				'From'  =>  $From,
				'ReplacementText' => "<!--#include virtual=\"/email_content/iso_car_reprint_request.html\"-->",
				);
		$_ = MIME::QuotedPrint::encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');
		my %mail = (
				SMTP    => $config{'Mail Server'},
                        FROM    => sprintf( '"%s" <%s>', $From->name(), $From->email() ),
						TO      => sprintf( '"%s" <%s>', $To->name(), $To->email() ),
						SUBJECT => 'CAR Reprint Request',
				);
		$log->debug("Sending Reprint Notifications to " . $To->email());
		misc::send_email_with_attachment( $log, \%mail, @body );
	} # end foreach Reprint Approver
} # end sub send_reprint_request_notification
sub send_reprint_approval_notification {
	my ($self) = @_;

	my $From = new openprint::User( $session{'user_id'} );
	my $To = new openprint::User( $$self{'issued_by_id'} );
	if ( $To->id() == $session{'user_id'} ) {
		$log->debug("Not Sending Reprint Approval because I am ME to " . $To->email());
	} else {
		$log->debug("Sending Reprint Approval because I am ME to " . $To->email());
		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		my %info = (
				'CAR'   =>  $self,
				'To'    =>  $To,
				'From'  =>  $From,
				'ReplacementText' => "<!--#include virtual=\"/email_content/iso_car_reprint_approval.html\"-->",
				);
		$_ = MIME::QuotedPrint::encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');
		my %mail = (
				SMTP    => $config{'Mail Server'},
				FROM    => sprintf( '"%s" <%s>', $From->name(), $From->email() ),
				TO      => sprintf( '"%s" <%s>', $To->name(), $To->email() ),
				SUBJECT => 'Reprint ' . ($$self{'reprint_approval'} eq 'Yes' ? 'approved' : 'not approved' ) . ' for CAR ' . $$self{id},
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
	} # end if

} # end sub send_reprint_approval_notification

sub send_changed_notification {
    my ($self) = @_;

    my $From = new openprint::User( $session{'user_id'} );
	foreach my $To ( new openprint::User( $$self{'issued_by_id'} ), openprint::User->find('usergroups'=>['Quality Control Notifications']) ) {
		if ( $To->id() == $session{'user_id'} ) {
			$log->debug("Not Sending PART2 because I am ME to " . $To->email());
			next;
		} # end if
		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		my %info = (
				'CAR'   =>  $self,
				'To'    =>  $To,
				'From'  =>  $From,
				'ReplacementText' => "<!--#include virtual=\"/email_content/iso_car_changed_notification.html\"-->",
				);
		$_ = MIME::QuotedPrint::encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
		my @body = ('', $_, 'text/html', 'quoted-printable');
		my %mail = (
				SMTP    => $config{'Mail Server'},
				FROM    => sprintf( '"%s" <%s>', $From->name(), $From->email() ),
				TO      => sprintf( '"%s" <%s>', $To->name(), $To->email() ),
				SUBJECT => 'CAR ' . $$self{id} . ' has been changed.',
				);
		misc::send_email_with_attachment( $log, \%mail, @body );
	} # end foreach To

} # end sub send_part2

sub Area {
	return new openprint::CAR_Area( $_[0]{area_id} );
} # end sub Area
sub Reason {
	return new openprint::CAR_Reason( $_[0]{reason_id} );
} # end sub Reason
sub issued_to {
	return new openprint::User( $_[0]{issued_to_id} );
} # end sub issued_to

1;
__END__
