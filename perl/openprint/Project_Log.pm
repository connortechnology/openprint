use strict;
package openprint::Project_Log;
our @ISA = qw(openprint::Object);

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );

$debug = 1;
$table = 'project_log';
$serial= '';
%fields = (
	project_id		=>	'project_id',
	company_id		=>	'company_id',
	user_id			=>	'user_id',
	created_on		=>	'dtmtimestamp',
	description		=>	'description',
);
%find_fields = (
	salesrep_id		=>	'(SELECT salesrep_id FROM companies WHERE companies.id=(SELECT company_id FROM projects WHERE projects.id=project_id))',
);
%transforms = (
);
%defaults = (
	created_on	=>	q`'NOW()'`,
);

sub description_html {
	if ( ! $_[0]{description_html} ) {
		if ( $_[0]{description} =~ /^Reused from project (\d+)$/ ) {
			$_[0]{description_html} = 'Reused from project <a href="/employee/project/view.html?project_id='.$1.'">'.$1.'</a>';
		} elsif ( $_[0]{description} =~ /^Reused to project (\d+)$/ ) {
			$_[0]{description_html} = 'Reused to project <a href="/employee/project/view.html?project_id='.$1.'">'.$1.'</a>';
		} elsif ( $_[0]{description} =~ /^Add to Order (\d+)$/ ) {
			$_[0]{description_html} = 'Add to Order <a href="/employee/project/view.html?order_id='.$1.'">'.$1.'</a>';
		} elsif ( $_[0]{description} =~ /^Removed from order (\d+)$/ ) {
			$_[0]{description_html} = 'Removed from order <a href="/employee/project/view.html?order_id='.$1.'">'.$1.'</a>';
		} elsif ( $_[0]{description} =~ /^Add to quote (\d+) prices: ([\d\.]+)$/ ) {
			$_[0]{description_html} = 'Add to quote <a href="/main/quote/history_details.html?quote_id='.$1.'">'.$1."</a> prices: $2";
		} else {
			$_[0]{description_html} = $_[0]{description}
		} # end if
	} # end if
	return $_[0]{description_html};
} # end sub description_html

sub Project {
	return new openprint::Project( $_[0]{project_id} );
} # end sub Project
sub Company {
	return new openprint::Company( $_[0]{company_id} );
} # end sub Company
sub User {
	return new openprint::User( $_[0]{user_id} );
} # end sub USer;

1;
__END__
