use strict;

package openprint::Email;
our @ISA = qw( openprint::Object );

require Mail::Sendmail;
use openprint ();
require email;
require ssi;

use vars qw( $dbh $table $serial %fields %transforms %defaults $log %session %config $debug );
*log = \$openprint::log;
*session = \%openprint::session;
*config = \%openprint::config;

$debug = 0;
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
	if ( $debug ) {
		$openprint::log->debug("Sending an email");
		foreach my $k ( keys %params ) {
			$openprint::log->debug("Params: $k => $params{$k}");
		} # end 
	}

	my $results;
	if ( $params{FROM} ) {
#$log->debug(" getting from $params{'FROM'} ng an email");
		if ( ref $params{FROM} eq 'openprint::User' ) {
			$$self{'from'} = sprintf('"%s %s" <%s>', $params{FROM}->get('firstname','lastname','email') );
		} else {
			$$self{'from'} = $params{'FROM'};
		} # end if
	} # end if

	my %mail = (
			CC	=>	$params{'CC'},
			BCC	=>	$params{'BCC'},
			( $params{'Return-receipt-to'} ? ( 'Return-receipt-to' => $params{'Return-receipt-to'} ) : () ),
			( $params{'Disposition-Notification-To'} ? ( 'Disposition-Notification-To' => $params{'Disposition-Notification-To'} ) : () ),
			SMTP	=> ( $params{'SMTP'} ? $params{'SMTP'} : $config{'Mail Server'} ),
			FROM	=> $$self{'from'},
			SUBJECT => ( $params{'SUBJECT'} ? $params{'SUBJECT'} : $$self{'subject'} ),
			BODY	=>	( $params{'BODY'} ? $params{'BODY'} : $$self{'body'} ),
			);
#$log->debug("SMTP: $mail{SMTP}, from: $mail{'from'} subject: $mail{SUBJECT}");
	my @attachments = $params{'ATTACHMENTS'} ? @{$params{'ATTACHMENTS'}} : ();
	@attachments = ( $$self{'ATTACHMENTS'} ? @{$$self{'ATTACHMENTS'}} : () ) if ! @attachments;

    if ( @attachments ) {
        my $message = $mail{BODY};
        $mail{BOUNDARY} = "====" . time() . "====" if ! $mail{BOUNDARY};
        $mail{'content-type'} = "multipart/mixed;\r\n  boundary=\"$mail{BOUNDARY}\"\r\n";

# start with the current body
        $mail{'BODY'} .= "This is a multi-part message in MIME format.\n\n";
        if ( $message ) {
            $mail{BODY} .= "--$mail{BOUNDARY}\n";
            $mail{BODY} .= ($mail{'content-type'} ? $mail{'content-type'} : 'Content-Type: text/plain; charset="utf-8"')."\n";
            $mail{BODY} .= "Content-Transfer-Encoding: 8-bit\n";
            $mail{BODY} .= "\n$message\n";
        } else {
            my ( $name, $text, $type, $encoding ) = splice @attachments,0,4;
            $mail{BODY} .= "--$mail{BOUNDARY}\nContent-Type: $type;\n";
            $mail{BODY} .= "Content-Transfer-Encoding: $encoding\n";
            $mail{BODY} .= "\n$text\n";
        } # end if

        while ( @attachments ) {
            my ( $name, $text, $type, $encoding ) = splice ( @attachments,0,4 );
            $mail{BODY} .= "--$mail{BOUNDARY}\nContent-Type: $type;\n";
            $mail{BODY} .= "\tname=\"$name\"\n" if $name;
            $mail{BODY} .= "Content-Transfer-Encoding: $encoding\n";
            $mail{BODY} .= "Content-Disposition: attachment;\n";
            $mail{BODY} .= "\tfilename=\"$name\"\n" if $name;
            $mail{BODY} .= "\n$text\n";
        } # end while

# Signal end of attachments
        $mail{BODY} .= "--$mail{BOUNDARY}--\n\n";
    } # end if

#$log->debug("Email: Attachments @attachments");
	my @recipients = $self->to();
#$log->debug("Email: Recipients @recipients");
	if ( $params{'TO'} ) {
		if ( ref $params{'TO'} eq 'ARRAY' ) {
			@recipients = @{$params{'TO'}};
		} else {
			@recipients = ( $params{'TO'} );
		} # end if
	} # end if
#$log->debug("Email: Recipients @recipients");
	foreach my $recipient ( @recipients ) {
		next if ! $recipient;
		
		if ( ref $recipient eq 'openprint::User' ) {
			my @to;
			foreach my $email ( split (',',	$recipient->email() ) ) {
				s/^\s+//, s/\s+$// for $email;
#$log->debug("Email: checking vacation for $email");
				if ( email::get_vacation( $email ) ) {
					$results .= 'Not sending to ' . $email . ' because they are on vacation.<br/>';
#$log->debug("Email: got vacation for $email");
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
		} # end if
#$log->debug("Email: Tos mail{'TO'}");
if ( $debug ) {
$log->debug("Sending an email");
foreach my $k ( keys %mail ) {
$log->debug("Mail hash: $k => $mail{$k}");
} # end 
}
		Mail::Sendmail::sendmail(%mail) || $openprint::log->error( "Error: $Mail::Sendmail::error\n" );
		$results .= 'Sent to: ' . ssi::htmlize( $mail{'TO'} ) . '<br/>';

	} # end foreach recipient
	return $results;

} # end sub send

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM mailbox WHERE 1>0';
	my @values;

	if ( $params{'active'} ) {
		$sql .= ' AND active = ?';
		push @values, $params{'active'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$log->debug("openprint::Email::find($sql)" . $openprint::dbh->errstr);
	} else {
		return map { new openprint::Email( $_->{username}, $_ ); } @$data;
	} # end if
} # end sub find

sub delete {
	
	#sql::execute( undef, $dbh, 'DELETE FROM mailbox WHERE username=?', $_[0]{'id'} );
} # end sub delete

sub to {
	return ();
} # end sub to
1;
__END__
