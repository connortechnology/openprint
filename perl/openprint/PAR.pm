package openprint::PAR;
@ISA = qw(openprint::Object);

use vars qw( %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require openprint::PAR_Area;
require openprint::PAR_Reason;

my $debug = 1;

use strict;
use vars qw( %fields %defaults %transforms );

require sql;

%fields = (
	'issued_to_id'	=> 'issued_to_id',
	'issued_on'		=> 'issued_on',
	'issued_by_id'	=> 'issued_by_id',
	'reply_by'		=> 'reply_by',
	'problem'		=> 'problem',
	'cause'			=> 'cause',
	'action'		=> 'action',	
	'effectiveness'	=> 'effectiveness',
	'area'			=> 'area',
	'area_id'		=> 'area_id',
	'reason'		=> 'reason',
	'reason_id'		=> 'reason_id',
	'part1_user_id'	=> 'part1_user_id',
	'part1_signed_on'	=> 'part1_signed_on',
	'part2_user_id'		=> 'part1_user_id',
	'part2_signed_on'	=> 'part2_signed_on',
	'part3_user_id'		=> 'part3_user_id',
	'part3_signed_on'	=> 'part3_signed_on',
	'part4_user_id'		=> 'part4_user_id',
	'part4_signed_on'	=> 'part4_signed_on',
	'created_on'		=> 'created_on',
	'updated_on'		=> 'updated_on',
	'deleted'			=> 'deleted',
);

%transforms = (
);
%defaults = (
	'issued_to_id'	=> undef,
	'issued_by_id'	=> undef,
	'part1_user_id'	=> undef,
	'part2_user_id'	=> undef,
	'part3_user_id'	=> undef,
	'part4_user_id'	=> undef,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'deleted'		=> 0,
	'area_id'		=>	undef,
);

sub send_notifications {
	my ( $self ) = @_;

	my @Users = openprint::User->find('usergroup'=>'Quality Control Notifications');

	if ( @Users ) {
		my $From = new openprint::User( $session{'user_id'} );
		my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
		my $text = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/iso_par_notification.html' );

		my %info = (
			'PAR'	=>	$self,
		);
		$info{'ReplacementText'} = ssi::variable_substitution( undef, $log, $dbh, \$text, \%info );
$openprint::log->debug( $info{'ReplacementText'} );

		my $body = ssi::variable_substitution( undef, $log, $dbh, \$email_template, \%info );
$openprint::log->debug( $body );
		foreach my $User ( @Users ) {
			my %mail = (
					SMTP    => $config{'Mail Server'},
					FROM    => sprintf( '"%s" <%s>', $From->name(), $From->email() ),
					TO      => sprintf( '"%s" <%s>', $User->name(), $User->email() ),
					SUBJECT => 'A new PAR has been generated.',
					);
			misc::send_email_with_attachment( $log, \%mail, ('', encode_qp($body), 'text/html', 'quoted-printable'));
		} # end foreach
	} # end if to

} # end sub send_notification
sub Area {
	return new openprint::PAR_Area( $_[0]{area_id} );
} # end sub Area
sub Reason {
	return new openprint::PAR_Reason( $_[0]{reason_id} );
} # end sub Reason
1;

__END__
~       
