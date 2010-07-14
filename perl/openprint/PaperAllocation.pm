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
require openprint::Email;

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
	'skid_ids'		=>	'skid_ids',
);

%transforms = (
);

%defaults = (
	'created_on'	=> 'NOW()',
);
# Returns a paper object specified by the parameters
sub find {
	my $self = shift;
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
		$sql .= ' AND ? = ANY(skid_ids)';
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
	$self->Paper()->allocated(undef,undef);
	$self->Paper()->available(undef);
	return;
} # end sub delete

sub Paper {
	return new openprint::Paper( $_[0]{'paper_id'} );
} # end sub Paper
sub Skid {
	$log->error("Use of deprectated PaperAllocation::SKid");
	return new openprint::Skid( $_[0]{'skid_id'} );
} # end sub Skid
sub Skids {
	if ( $_[0]{'skid_ids'} and @{$_[0]{'skid_ids'}} ) {
		return map { new openprint::Skid( $_); } @{$_[0]{'skid_ids'}};
	} # end if
	return ();
} # end sub Skids
sub User {
	return new openprint::User( $_[0]{'operator_id'} );
} # end sub User
sub Project {
	return new openprint::Project( $_[0]{'project_id'} );
} # end sub Project
sub docket {
	return $_[0]->Project()->docket();
} # end sub docket

sub old_Skids {
	my @old_skids;
    foreach my $Skid ( $_[0]->Skids() ) {
        if ( $Skid->last_seen_days() > 30 ) {
            push @old_skids, $Skid;
        } # end if
    } # end foreach Skid
	return @old_skids;
} # end sub old_Skids

sub send_notification {
	my ( $self ) = @_;
	my %info;
	$info{'Allocation'} = $self;
	my $Project = $info{'Project'} = $self->Project();
	my $Paper = $info{'Paper'} = $self->Paper();
	my @old_skids = @{$info{'OldSkids'}} = $self->old_Skids();

	my @recipients = openprint::User->find( 'usergroup'=>'InventoryManager' );

    my $offsite = 0;
	my $nolocation = 0;
    foreach my $sig_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
        my $Press;
        if ( $$sig_specs{'UsePress'} ) {
            $Press = openprint::Equipment->find_one('strid'=>$$sig_specs{'UsePress'});
        } else {
            $Press = openprint::Equipment->find_one('strid'=>$$sig_specs{'ddmPress'.$Project->ordered_quantity_index()});
        } # endif
		if ( $Press ) {
			foreach my $Skid ( $self->Skids() ) {
				if ( ! $Skid->location_id() ) {
					$nolocation = 1;
				} elsif ( $Skid->Location()->Root()->id() != $Press->Location()->Root()->id() ) {
					$offsite = 1;
				} # end if
			} # end foreach PA
		} # end if
    } # end foreach sig
	$info{'offsite'} = $offsite;
	$info{'nolocation'} = $nolocation;

	push @recipients, $Project->Company()->CSR() if $offsite or $nolocation or @old_skids;
	if ( $Paper->available() < 0 ) {
		my @PAs = openprint::PaperAllocation->find('paper_id'=>$Paper->id());
		@recipients = map { new openprint::User( $_ ) } sets::exclude( [ $session{'user_id'} ], [ sets::union( (map { $_->Project()->Company()->salesrep_id() } @PAs), (map{$_->id()}@recipients) ) ] );
	} # endif

	my $email_template = misc::load_file( $log, $openprint::config{'SkinPath'} . '/email_template.html' );

	$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/stock_allocation_notification.html\"-->";
	$_ = encode_qp( ssi::variable_substitution( \$email_template, \%info ) );
	my @body = ('', $_, 'text/html', 'quoted-printable');
	my $Email = new openprint::Email();
	$Email->send( 
#'TO'		=>	\@recipients, 
			'TO'		=>	'iconnor@point-one.com',
			SUBJECT 	=> 'Stock allocated for docket ' . $Project->docket(),
			'FROM'		=>	new openprint::User( $session{'user_id'} ),
			'ATTACHMENTS'	=>	\@body,
			);

} # end sub stock_allocation_notification

1;
__END__
