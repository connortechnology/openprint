use strict;
require openprint::Comment;
package openprint::Article;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %defaults %transforms %config $log $dbh %session );
*session = \%openprint::session;
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

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
	'category_id'		=>	'category_id',
	'category'			=>	undef,
	'source'			=>	'source',
	'source_content'	=>	'source_content',
	'summary'			=>	'summary',
);

%transforms = (
);
%defaults = (
	'created_on'	=> q`'NOW()'`,
	'updated_on'	=> q`'NOW()'`,
	'published_on'	=> q`'NOW()'`,
	'deleted'		=> 0,
	'category_id'	=>	undef,
);

sub send_notifications {
	my ( $self ) = @_;

	my @Users = openprint::User->find('usergroup'=>'Quality Control Notifications');

	if ( @Users ) {
		my $From = new openprint::User( $session{'user_id'} );
		my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
		my $text = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/article_notification.html' );

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
sub Company {
	return new openprint::Company( $_[0]{'company_id'} );
} # end sub Company
sub Author {
	return new openprint::User( $_[0]{'created_by'} );
} # end sub Author

sub category {
	if ( @_ > 1 ) {
		my $Category = openprint::Article_Category->find_one('name_lc'=>lc$_[1]);
		if ( ! $Category ) {
			$Category = new openprint::Article_Category();
			$Category->save({'name'=>$_[1]})
		} # end if	
		$_[0]{'category_id'} = $Category->id();
		return $Category->name();
	} # end if
	return new openprint::Article_Category( $_[0]{'category_id'} )->name();
} # end sub category

sub Category {
	return new openprint::Article_Category( $_[0]{'category_id'} );
} # end sub Category

sub Comments {
	if ( $_[1] ) {
		$_[1]{'object_id'} = $_[0]{'id'};
		$_[1]{'object_type'} = 'openprint::Article';
		$_[1]{'order'} = 'created_on' if ! $_[1]{'order'};

		return openprint::Comment->find($_[1]);
	} # end if

	if ( ! defined $_[0]{'Comments'} ) {
		@{$_[0]{'Comments'}} = openprint::Comment->find({'object_type'=>'openprint::Article', 'object_id'=>$_[0]{'id'}, 'order'=>'created_on'});
	} # end if
	return @{$_[0]{'Comments'}};
} # end sub Comments

sub summary {
	if ( @_ > 1 ) {
		$_[0]{'summary'} = $_[1];
	} # end if
	return $_[0]{'summary'};
} # end sub summary

sub can_edit {
	return 1 if ! $_[0]{'id'};
	return 1 if $openprint::session{'user_type'} eq 'A';
	return 1 if ( $session{'user_id'} and ( $session{'user_id'} == $_[0]{'created_by'} ) );
	return 0;
} # end sub can_edit

sub html {
	my $Article = $_[0];
	my @Comments = $Article->Comments();
	my $html = sprintf(q`
			<div class="Article">
			<h1><a href="/article/view.html?article_id=%1$d">%2$s</a></h1>
			Posted on %6$s by %5$s<br/>
			<div class="source_content">%3$s</div>
			<div class="summary">%4$s</div>
			`, $Article->id(),
			ssi::htmlize($Article->title()),
			$Article->source_content(),
			$Article->summary() ? $Article->summary() : $Article->body(),
			ssi::htmlize( $Article->Author()->name() ),
			( $Article->published() ? Date::Format::time2str($openprint::config{'DateTimeFormat'}, Date::Parse::str2time( $Article->published_on() ) ) : '' ),

                );
	if ( $Article->source() ) {
		$html .= sprintf('<a class="source" href="%1$s" title="Original Article">%1$s</a>', $Article->source() );
	} # end if
	if ( $openprint::session{'user_id'} ) {
		$html .= sprintf(q`
			<div id="comments-%1$d" class="comments"><div onclick="new Ajax.Updater('comments-%1$d', '/article/_comments.html', { parameters: { article_id: %1$d } } );">This article has %2$s. Click to view/Add.</div></div>
			`, $Article->id(),
			( @Comments == 1 ? '1 comment' : @Comments . ' comments' )
		);
	} # end if
	$html .= '</div>';
	return $html;
} # end  sub html

sub summary_html {
} # end sub sumary
1;
__END__
