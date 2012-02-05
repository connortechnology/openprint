use strict;
require openprint::Asset;
require openprint::Article;

package openprint::Article_Asset;
our @ISA = qw(openprint::Object);
use vars qw( $debug %fields %transforms %defaults $table @identified_by );
$debug = 1;
$table = 'article_assets';
@identified_by = ( 'article_id','asset_id' );
%fields = (
	'article_id'	=>	'article_id',
	'asset_id'	=>	'asset_id',
);

sub Asset {
	return new openprint::Asset( $_[0]{'asset_id'} );
} # end sub Asset
sub Content {
	return new openprint::Article( $_[0]{'article_id'} );
} # end sub Content

sub url {
	return $_[0]->Asset()->url();
} # end sub url
sub thumbnail_url {
	return $_[0]->Asset()->thumbnail_url();
} # end sub url

sub thumbnail_html {
	my $Asset = $_[0]->Asset();
	return sprintf('<a class="thumbnail" href="/article/view.html?article_id=%d"><img src="%s" alt="%s"/></a>', $_[0]{'article_id'},$Asset->thumbnail_url(), $Asset->caption() );
} # end sub thumbnail_html
1;
__END__
