package openprint::PaperAllocation;
@ISA = qw(openprint::Object);
require openprint::Object;
use MIME::QuotedPrint;

use strict;
use openprint ();
use vars qw(%session %variable $dbh $log $table $serial %fields %transforms %defaults );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;


require sql;
require ssi;
require misc;
require configuration;
require openprint::Skid;
require openprint::User;
require openprint::Project;
require openprint::PaperPrice;
require openprint::logs;
require openprint::Manufacturer;

my $debug = 1;

$table = 'paper_allocations';
$serial = 'paper_allocation_id_seq';

%fields = (
	'id'			=>	'id',
	'paper_id'		=>	'paper_id',
	'skid_id'		=>	'skid_id',
	'operator_id'	=>	'operator_id',
	'created_on'	=>	'created_on',
	'project_id'	=>	'project_id',
	'units'			=>	'units',
	'quantity'		=>	'quantity',
);

%transforms = (
);

%defaults = (
	'created_on'	=> 'NOW()',
);
sub find_one {
	my %params = @_;
	$params{'limit'}=1;
	my @Results = find(%params);
	return $Results[0] if @Results;
} # end sub find_one
# Returns a paper object specified by the parameters
sub find {
	my %params = @_;
	@params{lc keys %params} = @params{keys %params};
	my @values;
	my $sql = 'SELECT * FROM Paper_Allocations WHERE 1>0';

	if ( exists $params{'id'} ) {
		if ( ref $params{'id'} eq 'ARRAY' ) {
			$sql .= ' AND id IN ('. join(',', map {'?'} @{$params{'id'}} ) . ')';
			push @values, @{$params{'id'}};
		} else {
			$sql .= ' AND id=?';
			push @values, $params{'id'};
		} # end if
	} # end if

	if ( exists $params{'skid_id'} ) {
		$sql .= ' AND skid_id=?';
		push @values, $params{'skid_id'};
	} # end if
	if ( exists $params{'paper_id'} ) {
		$sql .= ' AND paper_id=?';
		push @values, $params{'paper_id'};
	} # end if
	if ( exists $params{'project_id'} ) {
		$sql .= ' AND project_id=?';
		push @values, $params{'project_id'};
	} # end if
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on BETWEEN ? AND ? )';
		push @values, @params{'created_on_start','created_on_end'}
	} elsif ( $params{'created_on_start'} ) {
		$sql .= ' AND ( created_on >= ?)';
		push @values, $params{'created_on_start'};
	} elsif ( $params{'created_on_end'} ) {
		$sql .= ' AND ( created_on <= ?)';
		push @values, $params{'created_on_end'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " ORDER BY $params{'order_by'}" if $params{'order_by'};

	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading paper allocations SQL($sql)" . DBI->errstr );
	} elsif ( ! @$data ) {
		$log->debug('No paper allocations loaded (' . $sql . ") (@values)" );
	} elsif ( $debug ) {
		$log->debug("Debug loaded paper allocations ($sql) (@values) records:" . @$data );
	} # end if
	return map { new openprint::PaperAllocation( $_->{id}, $_ ) } @$data;
} # end sub find

sub delete {
    my $self = shift;
    my $ac = sql::start_transaction( );
	$self->Project()->add_to_log(@session{'company_id','user_id'}, 'Allocation deleted.' . ( @_ ? ' Reason: ' . $_[0] : '' ) );
    sql::execute( undef, undef, q{DELETE FROM Paper_Allocations WHERE id=?}, $$self{'id'} );
    sql::end_transaction( undef, $ac );
} # end sub delete

sub Paper {
	return new openprint::Paper( $_[0]{'paper_id'} );
} # end sub Paper
sub Skid {
	return new openprint::Skid( $_[0]{'skid_id'} );
} # end sub Skid
sub User {
	return new openprint::User( $_[0]{'operator_id'} );
} # end sub User
sub Project {
	return new openprint::Project( $_[0]{'project_id'} );
} # end sub Project
sub docket {
	return $_[0]->Project()->docket();
} # end sub docket

1;
__END__
