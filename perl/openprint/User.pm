package openprint::User;
@ISA = qw( openprint::Object );
use Text::Unaccent;
use MIME::QuotedPrint;

require openprint::Company;
require openprint::logs;
use openprint ();
use strict;

my $debug = 1;

my %fields = (
	'company_id'		=>	'companyindex',
	'salutation'		=>	'strsalutation',
	'title'				=>	'strtitle',
	'firstname'			=>	'strfirstname',
	'lastname'			=>	'strlastname',
	'email'				=>	'stremail',
	'phone'				=>	'strphone',
	'mobile'			=>	'mobile',
	'sms'				=>	'sms',
	'extension'			=>	'strext',
	'fax'				=>	'strfax',
	'mailinglist'		=>	'ysnmailinglist',
	'greeting'			=>	'strcustomgreeting',
	'created_on'		=>	'dtmdateentered',
	'updated_on'		=>	'dtmlastmodified',
	'type'				=>	'chrtype',
	'changepassword'	=>	'ysnchangepassword',
	'commission'		=>	'dblcommission',
	'administrator'		=>	'ysnadministrator',
	'password',			=>	'strpassword',
	'ftp_active'		=>	'ftp_active',
	'web_active'		=>	'ysnaccountactivation',
	'howdidyouhearaboutus'	=>	'howdidyouhearaboutus',
	'howdidyouhearaboutusother'	=>	'howdidyouhearaboutusother',
); # end %fields

my %transforms = (
	'commission'		=>	[ 's/[^\d\.\-]//g' ],
	'email'				=>	[ 'tr/[A-Z]/[a-z]/' ],
	'created_on'		=> [ 's/.*//g' ],
	'updated_on'		=> [ 's/.*//g' ],
);

my %defaults = (
	'web_active'	=>	'N',
	'ftp_active'	=>	'0',
	'created_on'	=>	'NOW()',
	'updated_on'	=>	'NOW()',
	'type'			=>	'C',
	'changepassword'	=>	'N',
	'administrator'		=>	'N',
	'commission'		=>	undef,
);

sub get {
	my $self = shift;

	return @$self{@_};
} # end sub get

sub load {
	my ( $self, $data ) = @_;

	my @fields = keys %fields;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Users WHERE Index=?', {}, $$self{'id'} );
		if ( ! $data ) {
			$openprint::log->error( "Error loading User( $$self{'id'} ): " . $openprint::dbh->errstr() );
		} # end if
	} # end if
	@$self{@fields} = @$data{@fields{@fields}};
} # end sub load

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
			$openprint::log->warn("User::Set::Invalid field requested: ($field)." );
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

		$info{'ReplacementText'} = misc::load_file( $openprint::log, $ENV{'DOCUMENT_ROOT'} . '/email_content/usertype_system_notification.html' );
		$info{'ReplacementText'} = ssi::variable_substitution( undef, $openprint::log, $openprint::dbh, \$info{'ReplacementText'}, \%info );

		my $email_template = misc::load_file( $openprint::log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
		$email_template = ssi::variable_substitution( undef, $openprint::log, $openprint::dbh, \$email_template, \%info );

		my %mail = (
				SMTP    => $openprint::config{'Mail Server'},
				FROM    => $openprint::config{'LoginEmail'},
				TO      => $openprint::config{'LoginEmail'},
				SUBJECT => join(' ', @$params{'firstname','lastname'})."'s User Type has changed!"
				);
		misc::send_email_with_attachment( $openprint::log, \%mail, ( '', MIME::QuotedPrint::encode_qp($email_template), 'text/html', 'quoted-printable' ) );
	} # end if

	if ( $params and (defined $$params{'web_active'}) and ( $$self{web_active} ne $$params{'web_active'} ) ) {
		my %info;
		$info{'User'} = $self;
		$_ = $$params{'web_active'} eq 'Y' ? 'user_account_activated.html' : 'user_account_deactivated.html';
		$info{'ReplacementText'} = misc::load_file( $openprint::log, $ENV{'DOCUMENT_ROOT'} . "/email_content/$_" );
		$info{'ReplacementText'} = ssi::variable_substitution( undef, $openprint::log, $openprint::dbh, \$info{'ReplacementText'}, \%info );
		my $email_template = misc::load_file( $openprint::log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
		#$email_template = ssi::variable_substitution( undef, $openprint::log, $openprint::dbh, \$email_template, \%info );

		my %mail = (
				SMTP    => $openprint::config{'Mail Server'},
				FROM    => $openprint::config{'AdministratorEmail'},
				TO      => sprintf( '"%s %s" <%s>', @$params{'firstame','lastname','email'} ),
				SUBJECT => 'User account status has changed!',
				);
		misc::send_email_with_attachment( $openprint::log, \%mail, ( '', MIME::QuotedPrint::encode_qp($email_template), 'text/html', 'quoted-printable' ) );
    } # end if

	$self->set( $params ) if $params;

    my %sql;
	foreach my $k ( keys %fields ) {
		foreach my $transform ( @{$transforms{$k}} ) {
			eval '$$self{$k} =~ ' . $transform;
		} # end foreach

		if ( $$self{$k} eq '' and exists $defaults{$k} ) {
			$$self{$k} = $defaults{$k};
		} # end if
		$sql{$fields{$k}} = $$self{$k};
	} # end foreach

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $self->{id} ) {
		@$self{id} = sql::execute( $openprint::log, $openprint::dbh, q{SELECT nextval('Users_Index_seq')} );
		$sql{index} = $$self{id};
		if ( my $error = sql::insert( $openprint::log, $openprint::dbh, 'Users', \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} elsif ( $$params{'force_insert'} ) {
		if ( my $error = sql::insert( $openprint::log, $openprint::dbh, 'Users', \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} else {
		if ( my $error = sql::update( $openprint::log, $openprint::dbh, 'Users', ['Index=?',$$self{id}], \%sql ) ) {
			sql::end_transaction( $openprint::dbh, $ac );
			return $error;
		} # end if
	} # end if

	if ( exists $$params{'assistant_ids'} ) {
		$self->assistant_ids( ref $$params{'assistant_ids'} eq 'ARRAY' ? @{$$params{'assistant_ids'}} : $$params{'assistant_ids'} );
	} # end if
	if ( exists $$params{'csr_ids'} ) {
		$self->csr_ids( ref $$params{'csr_ids'} eq 'ARRAY' ? @{$$params{'csr_ids'}} : $$params{'csr_ids'} );
	} # end if
	sql::end_transaction( $openprint::dbh, $ac );
	return;
} # end sub save

sub delete {
	my $self = shift;
	sql::update( undef, undef, 'Users', ['index=?', $$self{'id'}], 'deleted', 1 );
}
sub destroy {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( $openprint::log, $openprint::dbh, 'DELETE FROM Users_in_Marketing_Categories WHERE User_Id=?', $$self{'id'} );

	foreach my $Quote ( openprint::Quote::find('user_id'=>$$self{'id'}) ) {
		$Quote->delete();
	} # end foreach
	foreach my $Order ( openprint::Order::find('user_id'=>$$self{'id'}) ) {
		$Order->delete();
	} # end foreach
	sql::update( undef, undef, 'order_log', ['user_id=?',$$self{'id'}], 'user_id', undef );
	foreach my $Project ( openprint::Project::find('user_id'=>$$self{'id'}) ) {
		$Project->delete();
	} # end foreach
	sql::execute( $openprint::log, $openprint::dbh, 'DELETE FROM users_in_usergroups WHERE user_id=?', $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, 'DELETE FROM Project_Log WHERE user_id=?', $$self{'id'} );
	sql::update( undef, undef, 'barcode_log', ['operator_id=?', $$self{'id'} ], 'operator_id', undef );
	sql::update( undef, undef, 'barcode_log', ['user_id=?',$$self{'id'}], 'user_id', undef );

	sql::execute( $openprint::log, $openprint::dbh, 'DELETE FROM creditapplications WHERE user_id=?', $$self{'id'} );
	sql::execute( $openprint::log, $openprint::dbh, 'DELETE FROM helpdesk WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Assistants WHERE csr_id=? OR assistant_id=?', @$self{'id','id'} );
	sql::execute( undef, undef, 'DELETE FROM EmailCampaign_sent WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM survey_responses WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM uploads WHERE user_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM paper_purchase_orders WHERE userindex=?', $$self{'id'} );


	sql::execute( $openprint::log, $openprint::dbh, 'DELETE FROM Users WHERE Index=?', $$self{'id'} );

	sql::end_transaction( $openprint::dbh, $ac );

	openprint::logs::insertLogRecord('14', "User ID: " . $$self{'id'},);
} # end sub delete

sub next {
	my $self = shift;
	my %params = @_;

	my $sql = 'SELECT MIN(strFirstName) FROM Users WHERE strFirstName > ?';
	my @values = ( $$self{firstname} );
	if ( $params{'company_id'} ) {
		$sql .= ' AND companyindex=?';
		push @values, $params{'company_id'};
	} # end if
	if ( $params{'type'} ) {
		$sql .= ' AND chrtype=?';
		push @values, $params{'type'};
	} # end if

	$sql = qq{SELECT Index FROM Users WHERE strFirstName = ($sql)};
	( $_ ) = sql::execute( $openprint::log, $openprint::dbh, $sql, @values );
	return $_;
}
sub Next {
	my $self = shift;
	return new openprint::User( $self->next( @_ ) );
} # end sub Nex

sub prev {
	my $self = shift;
	my %params = @_;

	my $sql = 'SELECT MAX(strFirstName) FROM Users WHERE strFirstName < ?';
	my @values = ( $$self{firstname} );
	if ( $params{'company_id'} ) {
		$sql .= ' AND companyindex=?';
		push @values, $params{'company_id'};
	} # end if
	if ( $params{'type'} ) {
		$sql .= ' AND chrtype=?';
		push @values, $params{'type'};
	} # end if

	$sql = qq{SELECT Index FROM Users WHERE strFirstName = ($sql)};
	( $_ ) = sql::execute( $openprint::log, $openprint::dbh, $sql, @values );
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

sub email {
	my $self = shift;
	return $$self{'email'};
} # end sub email

sub id {
	my $self = shift;
	return $$self{'id'};
} # end sub id

sub find {
	my %param = @_;
	my $sql = q{SELECT * FROM Users WHERE 1>0};
	my @values;

	if ( $param{'id'} ) {
		if ( ref $param{'id'} eq 'ARRAY' ) {
			$sql .= q{ AND index IN (}.join(',', map {'?'} @{$param{'id'}} ).')';
			push @values, @{$param{'id'}};
		} else {
			$sql .= q{ AND index=?};
			push @values, $param{'id'};
		} # end if
	} # end if

	if ( $param{'type'} ) {
		if ( ref $param{'type'} eq 'ARRAY' ) {
			$sql .= q{ AND chrType IN ('} . join("','", @{$param{'type'}}) . q{')};
		} else {
			$sql .= q{ AND chrType = ?};
			push @values, $param{'type'};
		} # end if
	} # end if
	if ( $param{'company_id'} ) {
		$sql .= q{ AND companyindex=?};
		push @values, $param{'company_id'};
	} # end if
	if ( $param{'usergroup'} ) {
		$sql .= q{ AND Index IN (SELECT user_id FROM users_in_usergroups WHERE usergroup_id=(SELECT id FROM usergroups WHERE name=?))};
		push @values, $param{'usergroup'};
	} # end if
	if ( $param{'usergroups'} ) {
		$sql .= q{ AND Index IN (SELECT user_id FROM users_in_usergroups WHERE usergroup_id IN (SELECT id FROM usergroups WHERE name IN ('} . join("','", @{$param{'usergroups'}}) . q{')))};
	} # end if
	if ( $param{'email'} ) {
		$sql .= ' AND strEmail=?';
		push @values, lc $param{'email'};
	} # end if
	if ( exists $param{'web_active'} ) {
		if ( ! sets::isin( $param{'web_active'}, ['Y','N'] ) ) {
		$param{'web_active'} = 'N' if $param{'web_active'} == 0;
		$param{'web_active'} = 'Y' if $param{'web_active'} == 1;
		} # end if
		$sql .= ' AND ysnaccountactivation=?';
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
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->error( "Error loading Users: ($sql) (@values)" );
		return;
	} elsif ( $debug ) {
		$openprint::log->debug( "loading Users: ($sql) (@values) " . $data );
	} # end if
	return map { new openprint::User( $_->{index}, $_ ) } @$data;
} # end sub find

sub assistant_ids {
	my $self = shift;
	if ( @_ ) {
		my $ac = sql::start_transaction( $openprint::dbh );
		sql::execute( undef, undef, 'DELETE FROM Assistants WHERE csr_id=?', $$self{id} );
		foreach ( @_ ) {
			sql::insert( undef, undef, 'Assistants', ['csr_id', $$self{id}, 'assistant_id', $_] ) if $_;
		} # end foreach
		sql::end_transaction( $openprint::dbh, $ac );
		return @_;
	} # end if
	return sql::execute( undef, undef, 'SELECT assistant_id FROM Assistants WHERE csr_id=?', $$self{id} );
} # end sub
sub csr_ids {
	my $self = shift;
	if ( @_ ) {
		my $ac = sql::start_transaction( $openprint::dbh );
		sql::execute( undef, undef, 'DELETE FROM Assistants WHERE assistant_id=?', $$self{id} );
		foreach ( @_ ) {
			sql::insert( undef, undef, 'Assistants', ['assistant_id', $$self{id}, 'csr_id', $_] ) if $_;
		} # end foreach
		sql::end_transaction( $openprint::dbh, $ac );
		return @_;
	} # end if
	return sql::execute( undef, undef, 'SELECT csr_id FROM Assistants WHERE assistant_id=?', $$self{id} );
} # end sub

1;

__END__

