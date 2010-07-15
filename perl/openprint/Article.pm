package openprint::Article;
@ISA = qw(openprint::Object);

use strict;
require sql;
use vars qw( $debug $table $serial %fields %defaults %transforms %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
use MIME::QuotedPrint;
use MIME::Base64;

$debug = 1;


$table = 'articles';
$serial = 'articles_id_seq';

%fields = (
	'id'				=>	'id',
	#'extended'			=>	'extended',
	#'excerpt'			=>	'exerpt',
	#'keywords'			=>	'keywords',
	'created_by'		=>	'created_by',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	#'user_id'			=>	'user_id',
	'company_id'		=>	'company_id',
	#'permalink'			=>	'permalink',
	#'created_by'		=>	'guid',
	#'text_filter_id'	=>	'text_filter_id',
	#'whiteboard'		=>	'whiteboard',
	'deleted'			=> 'deleted',
	#'type'				=>	'type',
	#'name'				=>	'name',
	#'allow_pings'		=>	'allow_pings',
	#'allow_comments'	=>	'allow_comments',
	'published_on'		=>	'published_on',
	'published'			=>	'published',
	'title'				=>	'title',
	#'author'			=>	'author',
	'body'				=>	'body',
	#'state'				=>	'state',
);

%transforms = (
);
%defaults = (
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'published_on'	=> 'NOW()',
	'deleted'		=> 0,
);

sub send_notifications {
	my ( $self ) = @_;

	my @Users = openprint::User->find('usergroup'=>'Quality Control Notifications');

	if ( @Users ) {
		my $From = new openprint::User( $session{'user_id'} );
		my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
		my $text = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/iso_par_notification.html' );

		my %info = (
			'Article'	=>	$self,
		);
		$info{'ReplacementText'} = ssi::variable_substitution( \$text, \%info );

		my $body = ssi::variable_substitution( \$email_template, \%info );
		foreach my $User ( @Users ) {
			my %mail = (
					SMTP    => $config{'Mail Server'},
					FROM    => sprintf( '"%s" <%s>', $From->name(), $From->email() ),
					TO      => sprintf( '"%s" <%s>', $User->name(), $User->email() ),
					SUBJECT => 'A new Article has been generated.',
					);
			misc::send_email_with_attachment( $log, \%mail, ('', encode_qp($body), 'text/html', 'quoted-printable'));
		} # end foreach
	} # end if to

} # end sub send_notification

1;
__END__
