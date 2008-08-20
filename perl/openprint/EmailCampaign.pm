package openprint::EmailCampaign;
@ISA=qw(openprint::Object);

use openprint::Object;
use Email::Valid;
use MIME::QuotedPrint;
use DBI;
use openprint ();

use strict;

require sql;
require configuration;
require openprint::logs;
require openprint::EmailTemplate;

my @Fields = (
	'id',
	'name',
	'query',
	'interval',
	'active',
	'timestosend',
	'timeofday',
	'email_subject',
	'email_from',
	'email_text',
	'attachments',
	'lastrun',
	'created_on',
	'updated_on',
	'template_id',
);

my %Defaults = (
	'lastrun'	=> 'NOW()',
	'interval'	=> undef,
	'timeofday'	=> undef,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
);

sub find {
	my %params = @_;
	my $sql = q{SELECT * FROM EmailCampaigns WHERE 1>0};
	my @values;
	if ( $params{'active'} ) {
		$sql .= ' AND active=?';
		push @values, $params{'active'};
	} # end if
	if ( $params{'misc'} ) {
		$sql .= " AND ($params{'misc'})";
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	$openprint::log->debug("Error EmailCampaign::find ($sql) " . DBI->errstr ) if ! $data;
	return map { new openprint::EmailCampaign( $_->{id}, $_ ); } @$data;
	
} # end sub find

sub delete {
	my $self = shift;
	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( @$self{'log','dbh'}, q{DELETE FROM EmailCampaign_Log WHERE campaign_id=?},$self->{'id'} );
	sql::execute( @$self{'log','dbh'}, q{DELETE FROM EmailCampaign_Sent WHERE campaign_id=?},$self->{'id'} );
	sql::execute( @$self{'log','dbh'}, q{DELETE FROM EmailCampaigns WHERE id=?}, $self->{'id'} );
	sql::end_transaction( $openprint::dbh, $ac );
	
	openprint::logs::insertLogRecord('7', "Campaign ID: " . $self->{'id'} . " Campaign Name: "  . $self->{'name'},);
} # end sub delete

sub copy {
	my $self = shift;
	my $new = new openprint::EmailCampaign();
	@$new{keys %$self} = @$self{keys %$self};	
	$new->name( 'Copy of ' . $$self{'name'} );
	delete $$new{id};
	return $new;
} # end sub copy

sub save {
	my ( $self, $hash ) = @_;

	foreach ( @Fields ) {
		$$self{$_} = $$hash{$_} if $hash and exists $$hash{$_};
		$$self{$_} = $Defaults{$_} if ! $$self{$_};
	} # end if

	if ( ! $$self{id} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('EmailCampaign_Id_seq')} );
		sql::insert( undef, undef, 'EmailCampaigns', map { $_, $self->{$_} } @Fields );
	} else {
		sql::update( undef, undef, 'EmailCampaigns', ['id=?',$$self{id}],
					map { $_, $self->{$_}; } @Fields
					);
	} # end if
	$self->load();
} # end sub save

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM emailCampaigns WHERE id=?}, {}, $$self{'id'} );
		if ( ! $data ) {
			$openprint::log->error( "Failure to load Email Campaign $$self{'id'}: Reason: " . $openprint::dbh->errstr );
			return;
		} # end if
	} # end if
	foreach my $key ( keys %{$data} ) {
		$$self{$key} = $$data{$key};
	} # end foreach
} # end sub load

sub get_user_detail {
	my ( $user_id, $replacements) = @_;

	# query the db and get the all the details we might possibly need
	# to fill into an email template
	#
	# U is the user table that contains the date for the UserID
	# C is the customer table that the UserID is linked to
	# R is the user table that contains the Sales Rep fir the company
	#   that the user belongs to
	my $user_detail_query = "SELECT U.strEmail, C.strName, ".
			"U.strSalutation, U.strFirstName, U.strLastName, ".
			"R.strEmail, R.strFirstName||' '|| R.strLastName, ".
			"R.strext ".
			"FROM users U ".
			"LEFT JOIN company C ON ".
			"U.companyindex = C.index ".
			"LEFT JOIN users R ON ".
			"C.lngsalesperson = R.index ".
			"WHERE U.index = ?";

	#$log->info("Getting users details with query: $user_detail_query\n");

	# Populate the hash with results of the query
	@$replacements{'EMAIL_ADDRESS',
					'COMPANY_NAME',
					'SALUTATION',
					'FIRSTNAME',
					'LASTNAME',
					'REPEMAIL',
					'REPNAME',
					'REPEXT'
					} = sql::execute( undef, undef, $user_detail_query, $user_id);

} # end sub get_user_detail

sub send_admin_email {
	my ($log, $dbh, $replacements) = @_;

	# Load the email template
	#my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
	my $email_template = <<__ADMIN_EMAIL__;
Dear Sales Rep.
You need to delete this account because they have not responded to many
automatic emails.

Account User Name: <?FIRSTNAME?> <?LASTNAME?>
Email address: <?EMAIL_ADDRESS?>
Company: <?COMPANY_NAME?>
Users Rep: <?REPNAME?>

__ADMIN_EMAIL__

	# Do the appropriate variable substitutions
	#$email_template = il($email_template);
	$email_template = encode_qp( ssi::variable_substitution( undef, $log, $dbh, \$email_template, $replacements ) );

	# Formulate the body of the message
	my @body = ('', $email_template, 'text/html', 'quoted-printable');

	# Setup the mail message
	my %mail = (
			SMTP => $openprint::config{'Mail Server'},
			FROM => sprintf("\"%s\" <%s>", @$replacements{'REPNAME','REPEMAIL'} ),
			TO => sprintf("\"%s\" <%s>", @$replacements{'REPNAME','REPEMAIL'} ),
			SUBJECT => 'Automatically Generated Account Deletion Email',
		);

	# Send the email
	misc::send_email_with_attachment($log, \%mail, @body, ());
	%mail = (
			SMTP => $openprint::config{'Mail Server'},
			FROM => sprintf("\"%s\" <%s>", @$replacements{'REPNAME','REPEMAIL'} ),
			TO => sprintf("\"%s\" <%s>", 'Keith Luder', 'keith@point-one.com' ),
			SUBJECT => 'Automatically Generated Account Deletion Email',
		);
	misc::send_email_with_attachment($log, \%mail, @body, ());
	%mail = (
			SMTP => $openprint::config{'Mail Server'},
			FROM => sprintf("\"%s\" <%s>", @$replacements{'REPNAME','REPEMAIL'} ),
			TO => 'iconnor@point-one.com',
			SUBJECT => 'Automatically Generated Account Deletion Email',
		);
	misc::send_email_with_attachment($log, \%mail, @body, ());
} # end sub send_admin_email

sub send_email {
	my ($self, $replacements) = @_;

	# Load the email template
	my $email_template = '';
	if ( $$self{'template_id'} ) {
		my $EmailTemplate = $self->Template();
		$email_template = $EmailTemplate->body();
	} else {
		$email_template = misc::load_file( $self->{log}, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
	} # end if

	# Do the appropriate variable substitutions
	# - The first substitution replaces the 'ReplacementText' field
	# - The seconds substitution replaces the any tags that were
	#   inserted by the first replacement
	# NB. Only encode_qp ONCE
	#$email_template = ssi::variable_substitution( undef, $openprint::log, $openprint::dbh, \$email_template, $replacements );
	$email_template = encode_qp( ssi::variable_substitution( undef, $openprint::log, $openprint::dbh, \$email_template, $replacements ) );

	# Formulate the body of the message
	my @body = ('', $email_template, 'text/html', 'quoted-printable');
	my @attachments = eval $self->{attachments};
	$openprint::log->warn( "Eval error Reason: " . $@ ) if $@;

	# Setup the mail message
	my %mail = (
			SMTP => $openprint::config{'Mail Server'},
			FROM => $self->{'email_from'} ? $self->{'email_from'} : sprintf('"%s" <%s>', @$replacements{'REPNAME','REPEMAIL'} ),
			TO => sprintf('"%s %s" <%s>', @$replacements{'User'}->get('firstname','lastname','email') ),
			SUBJECT => $$self{'email_subject'}
		);

	# Send the email
	misc::send_email_with_attachment($self->{log}, \%mail, @body, @attachments );
	sql::insert( $openprint::log, $openprint::dbh, 'EmailCampaign_Log', 
			'campaign_id',	$self->{'id'},
			'Log',				"Sending Email To $mail{TO}",
			'time',				'NOW()',
			);
} # end sub send_email

sub send {
	my ( $self ) = @_;

	my $query;
	my $results = '';

	my %replacements;
	my $body = $self->{'email_text'};

	# Find the email and company name for all accounts that match
	# this campaign
	my @mail_user_ids = sql::execute($openprint::log, $openprint::dbh, $self->{'query'});
	$results .= "There are ". scalar @mail_user_ids." users that fit the campaign<br/>\n";
	$self->{'lastrun'} = 'NOW()';
	$self->save();

	#$self->{log}->info("There are ". scalar @mail_user_ids." users that fit the campaign<br/>\n");

	# At this point, we have a list of users that fit the criteria for the
	# campaign. We will remove any entries from the emailcampaignsent
	# table for users who are not in this list (since they have done
	# something since the last email was sent to nullify their candidacy
	# for the campaign... which is good).
	if (@mail_user_ids) {
		$query = q{DELETE FROM EmailCampaign_Sent WHERE campaign_id=? AND user_id NOT IN (}.join(',', @mail_user_ids) . ')';
	} else {
		$query = q{DELETE FROM EmailCampaign_Sent WHERE campaign_id=?}; 
	} # end if
	sql::execute( undef, undef, $query, $$self{'id'} );

	# for each userid, prepare an email to send if the following
	# conditions are met
	#
	#	1) This is the first time an email is being sent for this
	#		campaign to this user
	#
	#	OR
	#
	# 	2.1) The interval specififed in emailcampaign.dtminterval
	# 	 	 has elapsed since the last email was sent
	# 	 	 (emailcampaignsent.dtmemailsenton)
	#
	# 	AND
	#
	# 	2.2) The number of emails sent to this user fot this campaign
	# 		 has not exceeded the specified number for the campaign
	# 		 (emailcampaign.lngnumtimestosend < 
	# 		 	emailcapaignsent.lngnumtiemssent)
	#
	# If 2.1 and 2.2 are not met, send an email to an administrator
	# flagging the account for removal.
	#
	# If an email is sent, update the row in emailcampaigsent for this
	# campaign/user, or add one as necessary
	#
	foreach my $user_index ( @mail_user_ids ) {
		# de we need to send this email?

		my ( $interval_expired, $num_email_sent, $marked_for_deletion );
		get_user_detail( $user_index, \%replacements );
		$replacements{'User'} = new openprint::User( $user_index );

		$replacements{ReplacementText} = ssi::variable_substitution( undef, $openprint::log, $openprint::dbh, \$body, \%replacements );
		if ( ! $replacements{ReplacementText} ) {
			$results .= 'No body.  Not sending.<br/>';
			next;
		} # end if

		# First check if a sent row exists
		$query = q{SELECT (NOW() - EmailSentOn) > ?, NumEmailSent, MarkedForDeletion FROM EmailCampaign_Sent WHERE campaign_id=? AND user_id=?};
		if ( $$self{'interval'} and ( $interval_expired, $num_email_sent, $marked_for_deletion ) =  sql::execute( undef, undef, $query, @$self{'interval','id'}, $user_index ) ) {

			# Check if the duration has elapsed	
			if ($interval_expired == 1) {
				$self->{log}->debug('interval expired');

				# if the account has already been marked for deletion, then
				# there is nothing to do
				if ($marked_for_deletion eq 'N') {
					$self->{log}->debug('not marked for deletion');
					# Check if we have sent this too many times
					if ( ($self->{'timestosend'} ne '') and $num_email_sent >= $self->{'timestosend'}) {
						# Email the admin
						$replacements{ReplacementText} = $self->{'emailtext'};
						#send_admin_email($openprint::log, $openprint::dbh, \%replacements);
						sql::update( undef, undef, 'EmailCampaign_Sent', ['campaign_id=? AND user_id=?', $$self{id}, $user_index],
								'MarkedForDeletion',	'Y',
								);
						$results .= sprintf('<span class="error">NOT Sending Email to: %s %s at %s because this email address has been sent to %d times already.</span><br/>', $replacements{'User'}->get('firstname','lastname','email'), $num_email_sent );
					} else {
						# Send the email to the user
						if ( ! Email::Valid->address( $replacements{'User'}->email() ) ) {
							$results .= sprintf('<span class="error">NOT Sending Email to: %s %s at %s because the email address appears to be invalid.</span><br/>', $replacements{'User'}->get('firstname','lastname','email') );
						} else {
							$results .= sprintf('Sending Email to: %s %s at %s<br/>',$replacements{'User'}->get('firstname','lastname','email') );
							$self->send_email( \%replacements );
							sql::update( undef, undef, 'EmailCampaign_Sent', ['campaign_id=? AND user_id=?', $self->{'id'}, $user_index],
									'NumEmailSent',	$num_email_sent+1,
									'EmailSentOn',	'NOW()',
									);
						} # end if email is valid
					} # if $num_email_sent > num_times to send
				} else {
					$results .= sprintf('<span class="error">NOT Sending Email to: %s %s at %s because this account is marked for deletion.</span><br/>', $replacements{'User'}->get('firstname','lastname','email') );
				} # if marked for deletion
			} # if interval expired
		} else {
			# No record of sent email, we need to send the first one
			if ( ! Email::Valid->address( $replacements{'EMAIL_ADDRESS'} ) ) {
				$results .= sprintf('<span class="error">NOT Sending Email to: %s %s at %s because the email address appears to be invalid.</span><br/>',$replacements{'User'}->get('firstname','lastname','email') );
			} else {
				$self->send_email( \%replacements);
				$results .= sprintf('Sending Email to: %s %s at %s<br/>', $replacements{'User'}->get('firstname','lastname','email') );
				sql::insert( $openprint::log, $openprint::dbh, 'EmailCampaign_Sent', 
						'NumEmailSent', '1',
						'campaign_id', $self->{'id'},
						'user_id', $user_index,
						'EmailSentOn', 'NOW()',
						);
			} # end if
		} # if row exists

	} # for all mail user ids
	return $results;
} # end sub send

sub recipients {
	my ( $self ) = @_;
	return sql::execute( undef, undef, $$self{'query'});
} # end sub recipients

sub trial {
	my ( $self ) = @_;

	my $results = '';

	# Find the email and company name for all accounts that match
	# this campaign
	my @mail_user_ids = sql::execute($openprint::log, $openprint::dbh, $self->{'query'});

	$results .= "There are ".@mail_user_ids." users that fit the campaign<br/>";
	my %replacements;
	my $body = $self->{'email_text'};
	foreach my $user_index ( @mail_user_ids ) {
# de we need to send this email?
		$replacements{'User'} = new openprint::User( $user_index );
		$replacements{ReplacementText} = ssi::variable_substitution( undef, $openprint::log, $openprint::dbh, \$body, \%replacements );
		if ( ! $replacements{ReplacementText} ) {
			$results .= 'No body.  Not sending<br/>';
			next;
		} # end if

		my ( $interval_expired, $num_email_sent, $marked_for_deletion );

# First check if a sent row exists
		$_ = 'SELECT (NOW() - EmailSentOn) > ?, NumEmailSent, MarkedForDeletion FROM EmailCampaign_Sent WHERE campaign_id=? AND user_id=?';
		if ( ( $interval_expired, $num_email_sent, $marked_for_deletion ) = sql::execute( undef, undef, $_, @$self{'interval','id'}, $user_index ) ) {

# Check if the duration has elapsed	
			if ($interval_expired == 1) {

# if the account has already been marked for deletion, then
# there is nothing to do
				if ($marked_for_deletion eq 'Y') {
# Check if we have sent this too many times
					if ($num_email_sent < $self->{'timestosend'}) {
						get_user_detail( $user_index, \%replacements);
						$results .= sprintf('Sending Email to: %s %s at %s<br/>', $replacements{'User'}->get('firstname','lastname','email') );
					} # if $num_email_sent > num_times to send
				} # if marked for deletion
			} # if interval expired
		} else {
# No record of sent email, we need to send the first one
			get_user_detail( $user_index, \%replacements);
			$results .= sprintf('Sending Email to: %s %s at %s<br/>', $replacements{'User'}->get('firstname','lastname','email') );
		} # if row exists

	} # for all mail user ids
	return $results;
} # end sub trial

sub Template {
	return new openprint::EmailTemplate( $_[0]->template_id() );
} # end sub Template

1;

__END__
