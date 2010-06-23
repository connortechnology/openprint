package openprint::Email;
@ISA = qw( openprint::Object );

use strict;

use openprint ();
require openprint::User;
require email;

use vars qw( $table $serial %fields %transforms %defaults $log $dbh %session %config );
*log = \$openprint::log;
*session = \%openprint::session;
*config = \%openprint::config;

$table = 'mailbox';

%fields = (
	'id'		=>	'username',
	'password'	=>	'password',
	'name'		=>	'name',
	'maildir'	=>	'maildir',
	'quota'		=>	'quota',
	'domain'	=>	'domain',
	'created_on'	=>	'created',
	'updated_on'	=>	'modified',
	'active'		=>	'active',
);

sub send {
	my ( $self, %params ) = @_;

	my $results;
	if ( $params{'FROM'} ) {
		if ( ref $params{'FROM'} eq 'openprint::User' ) {
			$$self{'from'} = sprintf('"%s" <%s>', $params{'FROM'}->get('name','email') );
		} else {
			$$self{'from'} = $params{'FROM'};
		} # end if
	} # end if

    my %mail = (
            SMTP    => $params{'SMTP'} ? $params{'SMTP'} : $config{'Mail Server'},
            FROM    => $$self{'from'},
            SUBJECT => $params{'SUBJECT'} ? $params{'SUBJECT'} : $$self{'subject'},
            );
	my @attachments = $params{'ATTACHMENTS'} ? @{$params{'ATTACHMENTS'}} : @{$$self{'ATTACHMENTS'}};

	my @recipients = $self->to();
	if ( $params{'TO'} ) {
		if ( ref $params{'TO'} eq 'ARRAY' ) {
			@recipients = @{$params{'TO'}};
		} else {
			@recipients = ( $params{'TO'} );
		} # end if
	} # end if
$log->debug("Email: Recipients @recipients");
	foreach my $recipient ( @recipients ) {
		s/^\s+//, s/\s+$// for $recipient;
		next if ! $recipient;
		
		if ( ref $recipient eq 'openprint::User' ) {
			if ( email::get_vacation( $recipient->email() ) ) {
				$results .= 'Not sending to ' . $recipient->email() . ' because they are on vacation.<br/>';
				next;
			} # end if
			$mail{'TO'} = sprintf('"%s" <%s>', $recipient->name(), $recipient->email() );
		} elsif ( $recipient =~ /^"(.*)" <(.*)>$/ ) {
			my ( $name, $email ) = ( $1, $2 );
			if ( email::get_vacation( $email ) ) {
				$results .= 'Not sending to ' . $email . ' because they are on vacation.<br/>';
				next;
			} # end if
			$mail{'TO'} = $recipient;
		} else {
			if ( email::get_vacation( $recipient ) ) {
				$results .= 'Not sending to ' . $recipient . ' because they are on vacation.<br/>';
				next;
			} # end if
			$mail{'TO'} = $recipient;
		} # end if
		misc::send_email_with_attachment( $log, \%mail, @attachments );
		$results .= 'Sent to: ' .  ssi::htmlize( $mail{'TO'} ) . '<br/>';

	} # end foreach recipient
	return $results;

} # end sub send

sub delete {
	
	#sql::execute( undef, $dbh, 'DELETE FROM mailbox WHERE username=?', $_[0]{'id'} );
} # end sub delete
