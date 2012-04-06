use strict;
require openprint::Comment;
require openprint::Article_Asset;
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
	'user_type'			=>	'user_type',
);

%transforms = (
	'user_type'	=>	[ 's/\s//g' ],
);
%defaults = (
	'created_on'	=> q`'NOW()'`,
	'updated_on'	=> q`'NOW()'`,
	'published_on'	=> q`'NOW()'`,
	'deleted'		=> 0,
	'category_id'	=>	undef,
	'user_type'		=>	undef,
	'created_by'	=>	undef,
);

sub name {
	return $_[0]->title();
} # end sub name

sub send_notifications {
	my ( $self ) = @_;

	my @Users = openprint::User->find('type'=>['E','A'],'usergroup any'=>'Quality Control Notifications');

	if ( @Users ) {
		my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
		my $text = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/article_notification.html' );

		my %info = ( 'Article'	=>	$self );
		$info{'ReplacementText'} = ssi::variable_substitution( \$text, \%info );

		my $body = ssi::variable_substitution( \$email_template, \%info );
		new openprint::Email()->send(
				FROM    => new openprint::User( $session{'user_id'} ),
				TO      => \@Users,
				SUBJECT => 'A new Article has been generated.',
				ATTACHMENTS	=>	[ '', MIME::QuotedPrint::encode_qp($body), 'text/html', 'quoted-printable'],
				);
	} # end if to

} # end sub send_notification
sub Company {
	return new openprint::Company( $_[0]{'company_id'} );
} # end sub Company
sub Author {
	if ( ! $_[0]{'Author'} ) {
		$_[0]{'Author'} = new openprint::User( $_[0]{'created_by'} );
	} # end if
	if ( ! $_[0]{'Author'}->id() ) {
		$_[0]{'Author'}->company_id( $_[0]{'company_id'} );
	} # end if
	return $_[0]{'Author'};
		
} # end sub Author

sub category {
	if ( @_ > 1 ) {
		if ( $_[1] ) {
			my $Category = openprint::Article_Category->find_one('name_lc'=>lc$_[1]);
			if ( ! $Category ) {
				$Category = new openprint::Article_Category();
				$Category->save({'name'=>$_[1]})
			} # end if	
			$_[0]{'category_id'} = $Category->id();
			return $Category->name();
		} else {
			$_[0]{'category_id'} = undef;
		} # end if
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

sub can_view {
	return 1 if ! $_[0]{'id'};
	return 1 if $session{'user_type'} eq 'A';
	return 1 if ( $session{'user_id'} == $_[0]{'created_by'} );
	if ( $_[0]{'published'} ) {
#$openprint::log->debug("Is published");
		if ( ! $_[0]{'user_type'} ) {
#$openprint::log->debug("no usertype");
			# Anyone can see it
			return 1;
		} else {
#$openprint::log->debug("usertype is ($_[0]{user_type})");
			# Don't have to test for admin, cuz we did it above
			return 1 if $_[0]{'user_type'} eq 'C' and sets::isin( $session{'user_type'}, ['E','C'] );
			return 1 if $_[0]{'user_type'} eq 'E' and sets::isin( $session{'user_type'}, ['E'] );
		} # end if
	#} else {
#$openprint::log->debug("not published");
	} # end if
	return 0;
} # end sub can_view
sub can_edit {
	return 0 if ! $session{'user_id'};
	return 1 if ! $_[0]{'id'};
	return 1 if $session{'user_type'} eq 'A';
	return 1 if ( $session{'user_id'} == $_[0]{'created_by'} );
	return 0;
} # end sub can_edit

sub html {
	my $Article = $_[0];
	my @Comments = $Article->Comments();
	my @Assets = $Article->Assets();
	my $html = sprintf(q`
			<div class="Article">
			<h1><a href="/article/view.html?article_id=%1$d">%2$s</a></h1>
			Posted on %7$s by <a href="/account/view.html?user_id=%5$d">%6$s</a><br/>
			<div class="source_content">%3$s</div>
			<div class="summary">%4$s</div>
			<div class="Assets">%8$s</div>
			`, $Article->id(),
			ssi::htmlize($Article->title()),
			$Article->source_content(),
			($Article->summary() ? $Article->summary() : $Article->body() ),
			$Article->created_by(),
			ssi::htmlize( $Article->Author()->name() ),
			( $Article->published() ? Date::Format::time2str($openprint::config{'DateTimeFormat'}, Date::Parse::str2time( $Article->published_on() ) ) : '' ),
			join('',map { $_->thumbnail_html() } ( @Assets ? $Assets[0] : () ) ),

                );
	if ( $Article->source() ) {
		$html .= sprintf('<a class="source" href="%1$s" target="_blank" title="Original Article">%1$s</a>', $Article->source() );
	} # end if
	if ( $Article->summary() and $Article->summary() ne $Article->body() ) {
		$html .= sprintf('<a class="readmore" href="/article/view.html?article_id=%1$d">Read more...</a><br/>', $Article->id() );
	} # end if
	$html .= sprintf(q`<div class="comments">This article has %s.</div>`, ( @Comments == 1 ? '1 comment' : @Comments . ' comments' ) );
	$html .= '</div>';
	return $html;
} # end  sub html

sub summary_html {
} # end sub summary_html

sub view_url {
	return '/article/view.html?article_id='.$_[0]{'id'};	
} # end sub view_url

sub Assets {
	return openprint::Article_Asset->find( 'article_id' => $_[0]{'id'} );
} # end sub Assets

sub published_on_string {
	if ( ! $_[0]{'published_on_string'} ) {
		$_[0]{'published_on_string'} = misc::smart_time( Date::Parse::str2time( $_[0]{'published_on'} ) );
	} # end if
	return $_[0]{'published_on_string'};
} # end sub published_on_string

sub handle_upload {
	my $error;
	my $Asset = openprint::Asset::upload( $_[1] );
	if ( ref $Asset ne 'openprint::Asset' ) {
		return $Asset;
	} # end if
	my $Article_Asset = new openprint::Article_Asset();
	return $Article_Asset->save({'asset_id'=>$Asset->id(), 'article_id'=>$_[0]->id()});
} # end sub handle_upload
1;
__END__
