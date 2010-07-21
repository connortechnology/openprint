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
			BCC		=>	$params{'BCC'},
            SMTP    => $params{'SMTP'} ? $params{'SMTP'} : $config{'Mail Server'},
            FROM    => $$self{'from'},
            SUBJECT => $params{'SUBJECT'} ? $params{'SUBJECT'} : $$self{'subject'},
            );
	my @attachments = $params{'ATTACHMENTS'} ? @{$params{'ATTACHMENTS'}} : @{$$self{'ATTACHMENTS'}};

	my @recipients = $self->to();
$log->debug("Email: Recipients @recipients");
	if ( $params{'TO'} ) {
		if ( ref $params{'TO'} eq 'ARRAY' ) {
			@recipients = @{$params{'TO'}};
		} else {
			@recipients = ( $params{'TO'} );
		} # end if
	} # end if
$log->debug("Email: Recipients @recipients");
	foreach my $recipient ( @recipients ) {
		
		if ( ref $recipient eq 'openprint::User' ) {
$openprint::log->debug("checking vacation to " . $recipient->email() );
			if ( email::get_vacation( $recipient->email() ) ) {
				$results .= 'Not sending to ' . $recipient->email() . ' because they are on vacation.<br/>';
				next;
			} # end if
			$mail{'TO'} = sprintf('"%s" <%s>', $recipient->name(), $recipient->email() );
$openprint::log->debug("Sending to $mail{'To'}");
		} elsif ( $recipient =~ /^"(.*)" <(.*)>$/ ) {
			my ( $name, $email ) = ( $1, $2 );
			if ( email::get_vacation( $email ) ) {
				$results .= 'Not sending to ' . $email . ' because they are on vacation.<br/>';
				next;
			} # end if
			$mail{'TO'} = $recipient;
		} else {
			s/^\s+//, s/\s+$// for $recipient;
			next if ! $recipient;
			if ( email::get_vacation( $recipient ) ) {
				$results .= 'Not sending to ' . $recipient . ' because they are on vacation.<br/>';
				next;
			} # end if
			$mail{'TO'} = $recipient;
		} # end if
$openprint::log->debug("Sending to $mail{'To'}");
		misc::send_email_with_attachment( $log, \%mail, @attachments );
		$results .= 'Sent to: ' .  ssi::htmlize( $mail{'TO'} ) . '<br/>';

	} # end foreach recipient
	return $results;

} # end sub send

sub delete {
	
	#sql::execute( undef, $dbh, 'DELETE FROM mailbox WHERE username=?', $_[0]{'id'} );
} # end sub delete
