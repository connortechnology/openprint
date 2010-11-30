package openprint::User;
@ISA = qw( openprint::Object );
use Text::Unaccent;
use MIME::QuotedPrint;

require openprint::Company;
require openprint::logs;
require openprint::Usergroup;
use openprint ();
use strict;
use vars qw( $log $dbh %config %variable %param %fields %transforms %defaults $table $serial );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*param = \%openprint::param;
*variable = \%openprint::variable;
$table = 'Users';
$serial = 'users_id_seq';

my $debug = 0;

%fields = (
	'id'				=>	'id',
	'company_id'		=>	'company_id',
	'salutation'		=>	'salutation',
	'title'				=>	'title',
	'firstname'			=>	'firstname',
	'lastname'			=>	'lastname',
	'email'				=>	'email',
	'phone'				=>	'phone',
	'mobile'			=>	'mobile',
	'sms'				=>	'sms',
	'fax'				=>	'fax',
	'mailinglist'		=>	'ysnmailinglist',
	'greeting'			=>	'greeting',
	'created_on'		=>	'created_on',
	'updated_on'		=>	'updated_on',
	'type'				=>	'type',
	'change_password'	=>	'ysnchangepassword',
	'commission'		=>	'dblcommission',
	'wage'				=>	'wage',
	'administrator'		=>	'ysnadministrator',
	'password',			=>	'password',
	'ftp_active'		=>	'ftp_active',
	'web_active'		=>	'web_active',
	'howdidyouhearaboutus'	=>	'howdidyouhearaboutus',
	'howdidyouhearaboutusother'	=>	'howdidyouhearaboutusother',
	'quote_level'		=>	'quote_level',
	'email_quotes_to_myself'        =>      'email_quotes_to_myself',
	'purchasing_limit'	=>	'purchasing_limit',
	'purchasing_total_limit'	=>	'purchasing_total_limit',
	'notes'				=>	'notes',
	'deleted'			=>	'deleted',
); # end %fields

%transforms = (
	'commission'		=>	[ 's/[^\d\.\-]//g' ],
	'wage'				=>	[ 's/[^\d\.]//g' ],
	'email'				=>	[ 'tr/[A-Z]/[a-z]/', 's/^\s+//', 's/\s+$//' ],
	'password'			=>	[ 's/^\s+//', 's/\s+$//' ],
	'purchasing_limit'	=>	[ 's/[^\d\.\-]//g' ],
	'purchasing_total_limit'	=>	[ 's/[^\d\.\-]//g' ],
	'email'				=>	[ 'tr/[A-Z]/[a-z]/' ],
	'created_on'		=>	[ 's/.*//g' ],
	'updated_on'		=>	[ 's/.*//g' ],
);

%defaults = (
	'web_active'	=>	q`'N'`,
	'ftp_active'	=>	0,
	'created_on'	=>	q`'NOW()'`,
	'updated_on'	=>	q`'NOW()'`,
	'type'			=>	q`'C'`,
	'change_password'	=>	q`'N'`,
	'administrator'		=>	q`'N'`,
	'commission'		=>	undef,
	'quote_level'		=> undef,
	'purchasing_limit'	=>	undef,
	'purchasing_total_limit'	=>	undef,
	'wage'				=>	undef,
	'deleted'			=>	0,
);

sub set {
	my ( $self, $params ) = @_;
	my @set_fields = ();
	if ( exists $$params{password} and $$params{password} eq '' ) {
		delete $$params{password};
	} # end if

	foreach my $field ( keys %{$params} ) {
		if ( defined $fields{$field} ) {

			foreach my $transform ( @{$transforms{$field}} ) {
				eval '$params->{$field} =~ ' . $transform;
			} # end foreach

			if ( $params->{$field} eq '' and exists $defaults{$field} ) {
				$params->{$field} = $defaults{$field};
			} # end if

# if valid db field
			if ( ( ! defined $$self{$field} ) or ($$self{$field} ne $params->{$field}) ) {
# Only make changes to fields that have changed
				$$self{$field} = $$params{$field};
				push @set_fields, $fields{$field}, $$params{$field};	#mark for sql updating
			} # end if
		} else {
			$log->warn("User::Set::Invalid field requested: ($field)." );
		} # end if
	} # end foreach
	return @set_fields;
} # end sub set

# if we have previously loaded info for this customer, and it hasn't changed, that field will not be saved.
# If we have not previously loaded the info, we will just save it whether it has actually changed or not.
# We do this for efficiency's sake.	
sub save {
	my ( $self, $params ) = @_;

	if ( $params and $$params{type} and $$self{type} and ( $$params{'type'} ne $$self{'type'} ) and ( $$params{'type'} ne 'C' ) ) {
# Notify someone
		my %info;
		$info{'User'} = $self;
		@info{'UserFirstName','UserLastName','UserType'} = @$params{'firstname','lastname','type'};

		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/usertype_system_notification.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );

		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		$email_template = ssi::variable_substitution( \$email_template, \%info );

		my %mail = (
				SMTP    => $openprint::config{'Mail Server'},
				FROM    => $openprint::config{'LoginEmail'},
				TO      => $openprint::config{'LoginEmail'},
				SUBJECT => join(' ', @$params{'firstname','lastname'})."'s User Type has changed!"
				);
		misc::send_email_with_attachment( $log, \%mail, ( '', MIME::QuotedPrint::encode_qp($email_template), 'text/html', 'quoted-printable' ) );
	} # end if

	if ( $params and (defined $$params{'web_active'} and defined $$self{'web_active'} ) and ( $$self{'web_active'} ne $$params{'web_active'} ) ) {
		my %info;
		$info{'User'} = $self;
		$_ = $$params{'web_active'} eq 'Y' ? 'user_account_activated.html' : 'user_account_deactivated.html';
		$info{'ReplacementText'} = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . "/email_content/$_" );
		$info{'ReplacementText'} = ssi::variable_substitution( \$info{'ReplacementText'}, \%info );
		my $email_template = misc::load_file( $log, $config{'SkinPath'}.'/email_template.html' );
		$email_template = ssi::variable_substitution( \$email_template, \%info );

		my %mail = (
				SMTP    => $openprint::config{'Mail Server'},
				FROM    => $openprint::config{'AdministratorEmail'},
				TO      => sprintf( '"%s %s" <%s>', @$params{'firstame','lastname','email'} ),
				SUBJECT => 'User account status has changed!',
				);
		misc::send_email_with_attachment( $log, \%mail, ( '', MIME::QuotedPrint::encode_qp($email_template), 'text/html', 'quoted-printable' ) );
    } # end if

	my $error = $self->SUPER::save( $params );
	return $error if $error;

	if ( exists $$params{'assistant_ids'} ) {
		$self->assistant_ids( $$params{'assistant_ids'} );
	} # end if
	if ( exists $$params{'csr_ids'} ) {
		$self->csr_ids( $$params{'csr_ids'} );
	} # end if
	return;
} # end sub save

sub destroy {
	my $self = shift;

	my $ac = sql::start_transaction( $dbh );
	sql::execute( $log, $dbh, 'DELETE FROM Users_in_Marketing_Categories WHERE User_Id=?', $$self{'id'} );

	foreach my $Quote ( openprint::Quote->find('user_id'=>$$self{'id'}) ) {
		$Quote->delete();
	} # end foreach
	foreach my $Order ( openprint::Order->find('user_id'=>$$self{'id'}) ) {
		$Order->delete();
	} # end foreach
	sql::update( undef, undef, 'order_log', ['user_id=?',$$self{'id'}], 'user_id', undef );
	foreach my $Project ( openprint::Project->find('user_id'=>$$self{'id'}) ) {
		$Project->delete();
	} # end foreach
	sql::execute( $log, $dbh, 'DELETE FROM users_in_usergroups WHERE user_id=?', $$self{'id'} );
	sql::execute( $log, $dbh, 'DELETE FROM Project_Log WHERE user_id=?', $$self{'id'} );
	sql::update( undef, undef, 'barcode_log', ['operator_id=?', $$self{'id'} ], 'operator_id', undef );
	sql::update( undef, undef, 'barcode_log', ['user_id=?',$$self{'id'}], 'user_id', undef );

	sql::execute( $log, $dbh, 'DELETE FROM creditapplications WHERE user_id=?', $$self{'id'} );
	sql::execute( $log, $dbh, 'DELETE FROM helpdesk WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Assistants WHERE csr_id=? OR assistant_id=?', @$self{'id','id'} );
	sql::execute( undef, undef, 'DELETE FROM EmailCampaign_sent WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM survey_responses WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM uploads WHERE user_id=?', $$self{'id'} );

	sql::execute( $log, $dbh, 'DELETE FROM Users WHERE id=?', $$self{'id'} );

	sql::end_transaction( $dbh, $ac );

	openprint::logs::insertLogRecord('14', "User ID: " . $$self{'id'},);
} # end sub delete

sub next {
	my $self = shift;
	my %params = @_;

	my $sql = 'SELECT MIN(FirstName) FROM Users WHERE FirstName > ?';
	my @values = ( $$self{firstname} );
	if ( $params{'company_id'} ) {
		$sql .= ' AND company_id=?';
		push @values, $params{'company_id'};
	} # end if
	if ( $params{'type'} ) {
		$sql .= ' AND type=?';
		push @values, $params{'type'};
	} # end if

	$sql = qq{SELECT id FROM Users WHERE FirstName = ($sql)};
	( $_ ) = sql::execute( $log, $dbh, $sql, @values );
	return $_;
}
sub Next {
	my $self = shift;
	return new openprint::User( $self->next( @_ ) );
} # end sub Nex

sub prev {
	my $self = shift;
	my %params = @_;

	my $sql = 'SELECT MAX(FirstName) FROM Users WHERE FirstName < ?';
	my @values = ( $$self{firstname} );
	if ( $params{'company_id'} ) {
		$sql .= ' AND company_id=?';
		push @values, $params{'company_id'};
	} # end if
	if ( $params{'type'} ) {
		$sql .= ' AND type=?';
		push @values, $params{'type'};
	} # end if

	$sql = qq{SELECT id FROM Users WHERE FirstName = ($sql)};
	( $_ ) = sql::execute( $log, $dbh, $sql, @values );
	return $_;
}
sub Prev {
	my $self = shift;
	return new openprint::User( $self->prev(@_) );
} # end sub Nex

sub Company {
	my $self = shift;
	return new openprint::Company( $$self{'company_id'} );
} # end sub Company

sub name {
	my $self = shift;
	if ( $$self{'firstname'} and $$self{'lastname'} ) {
		return join(' ', @$self{'firstname','lastname'} ) 
	} elsif ( $$self{'firstname'} ) {
		return $$self{'firstname'};
	} elsif ( $$self{'lastname'} ) {
		return $$self{'lastname'};
	} # end if
} # end sub name

sub find {
	my $self = shift;
	my %param = @_;
	my $sql = q{SELECT * FROM Users WHERE 1>0};
	my @values;

	if ( $param{'id'} ) {
		if ( ref $param{'id'} eq 'ARRAY' ) {
			if ( @{$param{'id'}} ) {
				$sql .= q{ AND id IN (}.join(',', map {'?'} @{$param{'id'}} ).')';
				push @values, @{$param{'id'}};
			} else {
				$sql .= q{ AND id IS NULL };
			} # end if
		} else {
			$sql .= q{ AND id=?};
			push @values, $param{'id'};
		} # end if
	} # end if
	if ( $param{'name'} ) {
		my ( $first, $last ) = $param{'name'} =~ /(\S+)\s*(\S*)/;
		if ( $first and $last ) {
			$sql .= ' AND firstname=? AND lastname=?';
			push @values, $first, $last;
		} elsif ( $first ) {
			$sql .= ' AND firstname=?';
			push @values, $first;
		} # end if
	} # end if

	if ( $param{'type'} ) {
		if ( ref $param{'type'} eq 'ARRAY' ) {
			if ( @{$param{'type'}} ) {
				$sql .= q{ AND type IN ('} . join("','", @{$param{'type'}}) . q{')};
			} # end if
		} else {
			$sql .= q{ AND type = ?};
			push @values, $param{'type'};
		} # end if
	} # end if
	if ( $param{'company_id'} ) {
		$sql .= q{ AND company_id=?};
		push @values, $param{'company_id'};
	} # end if
	if ( $param{'usergroup_id'} ) {
		$sql .= q{ AND id IN (SELECT user_id FROM users_in_usergroups WHERE usergroup_id=?)};
		push @values, $param{'usergroup_id'};
	} # end if
	if ( $param{'usergroup'} ) {
		if ( ref $param{'usergroup'} eq 'ARRAY' ) {
		$sql .= q{ AND id IN (SELECT user_id FROM users_in_usergroups WHERE usergroup_id IN (SELECT id FROM usergroups WHERE name IN ('} . join("','", @{$param{'usergroup'}}) . q{')))};
		} else {
		$sql .= q{ AND id IN (SELECT user_id FROM users_in_usergroups WHERE usergroup_id=(SELECT id FROM usergroups WHERE name=?))};
		push @values, $param{'usergroup'};
		} 
	} # end if
	if ( $param{'usergroups'} ) {
		$sql .= q{ AND id IN (SELECT user_id FROM users_in_usergroups WHERE usergroup_id IN (SELECT id FROM usergroups WHERE name IN ('} . join("','", @{$param{'usergroups'}}) . q{')))};
	} # end if
	if ( $param{'email'} ) {
		$sql .= ' AND email=?';
		push @values, lc $param{'email'};
	} # end if
	if ( $param{'password'} ) {
		$sql .= ' AND password=?';
		push @values, $param{'password'};
	} # end if
	if ( exists $param{'email_like'} ) {
		$sql .= ' AND email LIKE ?';
		push @values, lc $param{'email_like'};
	} # end if
	if ( exists $param{'purchasing_limit_>='} ) {
		$sql .= ' AND purchasing_limit >= ?';
		push @values, $param{'purchasing_limit_>='};
	} # end if
	if ( exists $param{'web_active'} ) {
		if ( ! sets::isin( $param{'web_active'}, ['Y','N'] ) ) {
		$param{'web_active'} = 'N' if $param{'web_active'} == 0;
		$param{'web_active'} = 'Y' if $param{'web_active'} == 1;
		} # end if
		$sql .= ' AND web_active=?';
		push @values, $param{'web_active'};
	} # end if
	if ( exists $param{'deleted'} ) {
		if ( ref $param{'deleted'} eq 'ARRAY' ) {
			$sql .= ' AND (deleted IS NULL OR deleted IN (' . join(',', map {'?'} @{$param{'deleted'}}) . '))';
			push @values, @{$param{'deleted'}};
		} else {
			$sql .= ' AND deleted=?';
			push @values, $param{'deleted'};
		} # end if
	} else {
		$sql .= ' AND (deleted=? OR deleted IS NULL)';
		push @values, 0;
	} # end if
	if ( $param{'order'} ) {
		$sql .= " ORDER BY $param{'order'}";
	} # end if
	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->error( "Error loading Users: ($sql) (@values)" . $dbh->errstr() );
		return;
	} elsif ( $debug ) {
		$log->debug( "loading Users: ($sql) (@values) " . $data );
	} # end if
	return map { new openprint::User( $_->{id}, $_ ) } @$data;
} # end sub find

sub assistant_ids {
	my $self = shift;
	if ( @_ ) {
		my $ac = sql::start_transaction( $dbh );
		sql::execute( undef, undef, 'DELETE FROM Assistants WHERE csr_id=?', $$self{id} );
		foreach ( ( @_ == 1 and ref $_[0] eq 'ARRAY' ) ? @{$_[0]} : @_ ) {
			sql::insert( undef, undef, 'Assistants', ['csr_id', $$self{id}, 'assistant_id', $_] ) if $_;
		} # end foreach
		sql::end_transaction( $dbh, $ac );
		return @_;
	} # end if
	return sql::execute( undef, undef, 'SELECT assistant_id FROM Assistants WHERE csr_id=?', $$self{id} );
} # end sub
sub csr_ids {
	my $self = shift;
	if ( @_ ) {
		my $ac = sql::start_transaction( $dbh );
		sql::execute( undef, undef, 'DELETE FROM Assistants WHERE assistant_id=?', $$self{id} );
		foreach ( ( @_ == 1 and ref $_[0] eq 'ARRAY' ) ? @{$_[0]} : @_ ) {
			sql::insert( undef, undef, 'Assistants', ['assistant_id', $$self{id}, 'csr_id', $_] ) if $_;
		} # end foreach
		sql::end_transaction( $dbh, $ac );
		return @_;
	} # end if
	return sql::execute( undef, undef, 'SELECT csr_id FROM Assistants WHERE assistant_id=?', $$self{id} );
} # end sub

sub Groups {
	my ( $self ) = @_;

    return openprint::Usergroup->find('user_id_in'=>$$self{id} );
} # end sub Groups
sub notifications {
	my ( $self, $notifications_hash ) = @_;
	
	if ( $notifications_hash ) {
		my %types = sql::execute( undef, undef, 'SELECT id, name FROM User_Notification_types' );
		my $ac = sql::start_transaction( $dbh );
		sql::execute( undef, undef, 'DELETE FROM User_Notifications WHERE user_id=?', $$self{'id'} );
		foreach my $k ( keys %types ) {
			sql::insert( undef, undef, 'User_Notifications', { 'user_id'=>$$self{'id'},'type_id'=>$k, 'value'=>$$notifications_hash{$types{$k}} } ) if $$notifications_hash{$types{$k}};
		} # end foreach k
		sql::end_transaction( $dbh, $ac );
		$$self{'notifications'} = $notifications_hash;
	} elsif ( ! exists $$self{'notifications'} ) {
		%{$$self{'notifications'}} = sql::execute( undef, undef, 'SELECT (SELECT name FROM User_Notification_Types WHERE id=type_id),value FROM User_Notifications WHERE user_id=?', $$self{'id'} );
	} # end if
	
	return $$self{'notifications'};
} # end sub notifications

sub notification {
	my ( $self, $name ) = @_;

	$self->notifications() if ( ! exists $$self{'notifications'} );
	return $$self{'notifications'}{$name} if $$self{'notifications'} and $$self{'notifications'}{$name};
	return '';
} # end sub notification

sub purchasing_total {
	require openprint::PurchaseOrder;
	my $total = 0;
	foreach my $PO ( openprint::PurchaseOrder->find('authorized'=>'N') ) {
		$total += $PO->total();
	} # end foreach $PO
} # end sub purchasing_total

sub po_limit {
	my ( $self, $type_id, $new_value ) = @_;

	if ( ! exists $$self{'po_limits'} ) {
		%{$$self{'po_limits'}} = sql::execute( undef, undef, 'SELECT type_id, po_limit FROM User_PurchaseOrder_limits WHERE user_id=?', $$self{'id'} );
	} # end if

	if ( defined $new_value ) {
		if ( exists $$self{'po_limits'}{$type_id} ) {
			sql::update( undef, undef, 'user_purchaseorder_limits', ['user_id=? AND type_id=?', $$self{'id'},$type_id], 'po_limit', 1*$new_value );
		} else {
			sql::insert( undef, undef, 'user_purchaseorder_limits', ['user_id',$$self{'id'},'type_id', $type_id, 'po_limit', 1*$new_value ] );
		} # end if
		$$self{'po_limits'}{$type_id} = 1*$new_value;
	} # end if

	return $$self{'po_limits'}{$type_id};
} # end sub po_limit

1;

__END__

