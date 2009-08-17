package openprint::Article;
@ISA = qw(openprint::Object);

use strict;
use vars qw( $table $serial %fields %defaults %transforms %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
use MIME::QuotedPrint;
use MIME::Base64;

my $debug = 1;

require sql;

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
	'user_id'			=>	'user_id',
	'company_id'		=>	'company_id',
	'permalink'			=>	'permalink',
	#'created_by'		=>	'guid',
	#'text_filter_id'	=>	'text_filter_id',
	#'whiteboard'		=>	'whiteboard',
	'deleted'			=> 'deleted',
	#'type'				=>	'type',
	'name'				=>	'name',
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
	'deleted'		=> 0,
);

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM '.$table.' WHERE 1>0';
	my @values;
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'};
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND created_on >= ?';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND created_on <= ?';
		push @values, $params{'created_on_end'};
	} # end if
	if ( $params{'updated_on_start'} and $params{'updated_on_end'} ) {
		$sql .= ' AND ( updated_on BETWEEN ? AND ? )';
		push @values, @params{'updated_on_start','updated_on_end'};
	} elsif ( $params{'updated_on_start'} ) {
		$sql .= ' AND updated_on >= ?';
		push @values, $params{'updated_on_start'};
	} elsif ( $params{'updated_on_end'} ) {
		$sql .= ' AND updated_on <= ?';
		push @values, $params{'updated_on_end'};
	} # end if
	if ( $params{'published_on_start'} and $params{'published_on_end'} ) {
		$sql .= " AND ( $fields{published_on} BETWEEN ? AND ? )";
		push @values, @params{'published_on_start','published_on_end'};
	} elsif ( $params{'published_on_start'} ) {
		$sql .= " AND $fields{published_on} >= ?";
		push @values, $params{'published_on_start'};
	} elsif ( $params{'published_on_end'} ) {
		$sql .= " AND $fields{published_on} <= ?";
		push @values, $params{'published_on_end'};
	} # end if

	if ( $params{'deleted'} ) {
		$sql .= ' AND deleted=?';
		push @values, $params{'deleted'};
	} else {
		$sql .= ' AND deleted=?';
		push @values, 0;
	} # end if

	if ( $params{'order'} ) {
		$sql .= " ORDER BY $params{'order'}";
	} # end if
	if ( $params{'limit'} ) {
		$sql .= " LIMIT $params{'limit'}";
	} # end if

	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->warn("Error loading Articles: ($sql) (@values)" . $openprint::dbh->errstr );
		return;
	} elsif ($debug ) {
		$openprint::log->debug("openprint::Article::find($sql) (@values)");
	} # end if
	return map { new openprint::Article( $_->{id}, $_ ); } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM '.$table.' WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub send_notifications {
	my ( $self ) = @_;

	my @Users = openprint::User::find('usergroup'=>'Quality Control Notifications');

	if ( @Users ) {
		my $From = new openprint::User( $session{'user_id'} );
		my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
		my $text = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/iso_par_notification.html' );

		my %info = (
			'Article'	=>	$self,
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
					SUBJECT => 'A new Article has been generated.',
					);
			misc::send_email_with_attachment( $log, \%mail, ('', encode_qp($body), 'text/html', 'quoted-printable'));
		} # end foreach
	} # end if to

} # end sub send_notification
1;

__END__
~       
