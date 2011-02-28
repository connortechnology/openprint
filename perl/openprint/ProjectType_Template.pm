use strict;
package openprint::ProjectType_Template;
our @ISA = qw(openprint::Object);
require openprint::Object;

use openprint ();
use vars qw($debug $log $dbh %config %session $table $serial %fields %transforms %defaults );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require ssi;
require misc;

my $debug = 0;

$table = 'ProjectTemplate';
$serial = 'projecttemplate_id_seq';

%fields = (
	'id'				=>	'id',
	'projecttype_id'	=>	'projecttype_id',
	'type'				=>	'type',
	'description'		=>	'description',
	'finished_width'	=>	'dblfinishedwidth',
	'finished_height'	=>	'dblfinishedheight',
	'flat_width'		=>	'dblflatwidth',
	'flat_height'		=>	'dblflatheight',
);

%transforms = (
	'id'			=>	[ 's/\D//g' ],
);

%defaults = (
);

my %find_cache;
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my $hash_key = join(';',map { $_, ref $params{$_} eq 'HASH' ? join(';',%{$params{$_}}) :$params{$_} } sort keys %params );
	return @{$find_cache{$hash_key}} if $find_cache{$hash_key};

#$openprint::log->debug("Hash key: $hash_key");
	my @values;
	my $sql = 'SELECT * FROM ' . $table . ' WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if
	if ( exists $params{'projecttype_id'} ) {
		if ( ref $params{'projecttype_id'} eq 'ARRAY' ) {
			$sql .= ' AND projecttype_id IN ('. join(',', map {'?'} @{$params{'projecttype_id'}} ) . ')';
			push @values, @{$params{'projecttype_id'}};
		} else {
			$sql .= ' AND projecttype_id=?';
			push @values, $params{'projecttype_id'};
		} # end if
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading ProjectType_Templatees SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No ProjectType_Templates loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded ProjectType_Templates ($sql) (@values) records:" . @$data );
	} # end if
	@{$find_cache{$hash_key}} = map { new openprint::ProjectType_Template( $_->{id}, $_ ) } @$data;
	return @{$find_cache{$hash_key}};
} # end sub find

sub delete {
    sql::execute( undef, undef, 'DELETE FROM '.$table.' WHERE id=?', $_[0]{'id'} );
} # end sub delete

1;
#__END__
