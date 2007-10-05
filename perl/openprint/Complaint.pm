package openprint::Complaint;
@ISA = qw( openprint::Object );
use strict;

sub find {
	my %params = @_;
	my $sql = q{SELECT id FROM Complaints WHERE 1>0};
	my @values;
	if ( $params{'company_id'} ) {
		$sql .= q{ AND company_id=?};
		push @values, $params{'company_id'};
	} # end if
	if ( $params{'created_on_start'} and $params{'created_on_end'} ) {
		$sql .= q{ AND (created_on BETWEEN ? AND ?)};
		push @values, "$params{'created_on_start'} 00:00:00", "$params{'created_on_end'} 23:59:59";
	} elsif ( $params{'created_on_start'} ) {
		$sql .= q{ AND created_on >= ?};
		push @values, "$params{'created_on_start'} 00:00:00";
	} elsif ( $params{'created_on_end'} ) {
		$sql .= q{ AND created_on <= ?};
		push @values, "$params{'created_on_end'} 23:59:59";
	} # end if

	$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );
	$sql .= " LIMIT $params{'limit'}" if ( $params{'limit'} );
	return map { new openprint::Complaint( $_ ); } sql::execute( $openprint::log, $openprint::dbh, $sql, @values );
} # end sub find

sub load {
	my $self = shift;

	@$self{'company_id','company_name','user_id', 'contact_name','created_on','ponum','docket','howreceived','description','comments'} = sql::execute( $openprint::log, $openprint::dbh, 
		q{SELECT company_id, company_name, user_id, contact_name, created_on, ponum, docket, howreceived, description, comments FROM Complaints WHERE id=?}, $$self{'id'} );
} # end sub load

sub save {
	my $self = shift;
	my %sql = (
		'company_id'	=>	$$self{'company_id'},
		'contact_name'	=>	$$self{'contact_name'},
		'ponum'			=>	$$self{'ponum'},
		'docket'		=>	$$self{'docket'},
		'howreceived'	=>	$$self{'howreceived'},
		'description'	=>	$$self{'description'},
		'comments'		=>	$$self{'comments'},
		);
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('Complaints_id_seq')} );
		sql::insert( $openprint::log, $openprint::dbh, 'Complaints', 'id', $$self{'id'}, %sql );
	} else {
		sql::update( $openprint::log, $openprint::dbh, 'Complaints', "id=$$self{'id'}", %sql );
	} # end if
} # end sub save

1;
__END__

