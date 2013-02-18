use strict;

package openprint::Email;
our @ISA = qw( openprint::Object );

use openprint ();
require email;
require misc;
require ssi;
require MIME::QuotedPrint;
require Encode;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;

%fields = (
	from	=>	'from',
	subject	=>	'subject',
	ATTACHMENTS	=>	'ATTACHMENTS',
);

sub html_body {
	my ( $self, $html ) = @_;
	#$$self{boundary} = "====" . time() . "====" if ! $$self{boundary};
	$$self{'content-type'} = 'text/html; charset="utf-8"';
	#$$self{BODY} .= "$$self{boundary}\nContent-Type: text/html;\n";
	#$$self{BODY} .= "Content-Transfer-Encoding: quoted-printable\n";
	$$self{body} = Encode::encode('utf-8', $html );
if ( $debug ) {
$openprint::log->debug("Setting HTML body to $$self{body}");
}
} # end sub html_body

sub send {
	my ( $self, %params ) = @_;
	if ( $debug ) {
		$openprint::log->debug("Sending an email");
		foreach my $k ( keys %params ) {
			$openprint::log->debug("Params: $k => $params{$k}");
		} # end 
	} # end if

	my $results;
	if ( $params{'FROM'} ) {
		$$self{from} = $params{FROM};
	} # end if

    my %mail = (
			'content-type'	=>	$$self{'content-type'},
			BOUNDARY =>	$$self{boundary},
			CC		=>	$params{'CC'},
			BCC		=>	$params{'BCC'},
            SMTP    => $params{'SMTP'} ? $params{'SMTP'} : $openprint::config{'Mail Server'},
			( $params{'Return-receipt-to'} ? ( 'Return-receipt-to' => $params{'Return-receipt-to'} ) : () ),
			( $params{'Disposition-Notification-To'} ? ( 'Disposition-Notification-To' => $params{'Disposition-Notification-To'} ) : () ),
            FROM    => ( ref $$self{from} eq 'openprint::User' ? sprintf('"%s" <%s>', $$self{from}->get('name','email') ) : $$self{from} ),
            SUBJECT => ( $params{'SUBJECT'} ? $params{'SUBJECT'} : $$self{'subject'} ),
			BODY	=>	( $params{'BODY'} ? $params{'BODY'} : $$self{'body'} ),
			);
#$log->debug("SMTP: $mail{SMTP}, from: $mail{'from'} subject: $mail{SUBJECT}");
	my @attachments = $params{'ATTACHMENTS'} ? @{$params{'ATTACHMENTS'}} : ();
	@attachments = ( $$self{'ATTACHMENTS'} ? @{$$self{'ATTACHMENTS'}} : () ) if ! @attachments;

#$openprint::log->debug("Email: Attachments @attachments");
	my @recipients = $self->to();
#$openprint::log->debug("Email: Recipients @recipients");
	if ( $params{'TO'} ) {
		if ( ref $params{'TO'} eq 'ARRAY' ) {
			@recipients = @{$params{'TO'}};
		} else {
			@recipients = ( $params{'TO'} );
		} # end if
	} # end if
#$openprint::log->debug("Email: Recipients @recipients");
	foreach my $recipient ( @recipients ) {
		next if ! $recipient;
		
		if ( ref $recipient eq 'openprint::User' ) {
			if ( $params{'TO_EXCLUDE'} and filter_exclude( $recipient, $params{'TO_EXCLUDE'} ) ) {
				$results .= 'Not sending to ' . $recipient . ' because they have been excluded.<br/>';
				next;
			} # end if
			
			my @to;
			foreach my $email ( split (',',	$recipient->email() ) ) {
				s/^\s+//, s/\s+$// for $email;
#$openprint::log->debug("Email: checking vacation for $email");
				if ( email::get_vacation( $email ) ) {
					$results .= 'Not sending to ' . $email . ' because they are on vacation.<br/>';
#$openprint::log->debug("Email: got vacation for $email");
					next;
				} # end if
				push @to, sprintf('"%s" <%s>', $recipient->name(), $email );
			} # end foreach email
			next if ! @to;
			$mail{'TO'} = join(',', @to );
		} else {
			s/^\s+//, s/\s+$// for $recipient;
			if ( $recipient =~ /^"(.*)" <(.*)>$/ ) {
				my ( $name, $email ) = ( $1, $2 );

				if ( $params{'TO_EXCLUDE'} and filter_exclude( $email, $params{'TO_EXCLUDE'} ) ) {
					$results .= 'Not sending to ' . $email . ' because they have been excluded.<br/>';
					next;
				} # end if

				if ( email::get_vacation( $email ) ) {
					$results .= 'Not sending to ' . $email . ' because they are on vacation.<br/>';
					next;
				} # end if
				$mail{'TO'} = $recipient;
			} else {
				if ( $params{'TO_EXCLUDE'} and filter_exclude( $recipient, $params{'TO_EXCLUDE'} ) ) {
					$results .= 'Not sending to ' . $recipient . ' because they have been excluded.<br/>';
					next;
				} # end if
				if ( email::get_vacation( $recipient ) ) {
					$results .= 'Not sending to ' . $recipient . ' because they are on vacation.<br/>';
					next;
				} # end if
				$mail{'TO'} = $recipient;
			} # end if
		} # end if
		if ( $openprint::config{'EmailTo'} ) {
			$mail{'TO'} = $openprint::config{EmailTo};
		} # end if
		misc::send_email_with_attachment( $openprint::log, \%mail, @attachments );
		$results .= 'Sent to: ' .  ssi::htmlize( $mail{'TO'} ) . '<br/>';

	} # end foreach recipient
	return $results;

} # end sub send

sub filter_exclude {
	my ( $email, $exclude ) = @_;
	$email = $email->email() if ref $email eq 'openprint::User';

	if ( ref $exclude eq 'ARRAY' ) {
		if ( ref $$exclude[0] eq 'openprint::User' ) {
			return 1 if sets::isin( $email, [ map { $_->email() } @{$exclude} ] );
		} else {
			return 1 if sets::isin( $email, $exclude );
		} # end if
	} elsif ( ref $exclude eq 'openprint::User' ) {
		return 1 if $email eq $exclude->email();
	} # end if
	return 0;
}

sub delete {
	
	#sql::execute( undef, $dbh, 'DELETE FROM mailbox WHERE username=?', $_[0]{'id'} );
} # end sub delete

sub to {
	return ();
} # end sub to
1;
__END__
