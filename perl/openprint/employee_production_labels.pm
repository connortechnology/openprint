use strict;
package openprint::employee_production_labels;
use Date::Calc qw(Add_Delta_Days Date_to_Days check_date );

use openprint ();
use vars qw{ $log $dbh %config %variable %param };
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*variable = \%openprint::variable;
*param = \%openprint::param;

require openprint::Label;
require openprint::LabelType;
require openprint::Email;

sub index {
} # end sub index

sub _label {
	my $Label = new openprint::Label( $param{id} );
	if ( $param{id} and ! $$Label{id} ) {
		$variable{error} .= "Invalid label specified.  Label $param{id} does not exist.";
		return;
	} # end if
	if ( $param{action} eq 'update' ) {
		$param{value} =~ s/<br\/>/\n/ig;
		$Label->set_data($param{field}=>$param{value});
		$variable{error} .= $Label->save();
		$variable{PageContent} = join('',$Label->get_data($param{field}));
	} elsif ( $param{action} eq 'get' ) {
		$variable{PageContent} = join('',$Label->get_data($param{field}));
	} elsif ( $param{action} eq 'getnohtml' ) {
		$variable{PageContent} = join('',$Label->get_data($param{field}));
		$variable{PageContent} =~ s/<br\/>/\n/ig;
	} # end if
} # end sub _label

sub label {
	my $Label = $variable{Label} = new openprint::Label( $param{id} );
	if ( $param{function} eq 'Send' ) {
		my $email_template = ssi::slurp_content( '/email_template.html' );
		my @attachments;
		my %info;
		$info{ReplacementText} = $param{body};
		$info{Label} = $Label;

		$_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%info ) ) );
		push @attachments, ('', $_, 'text/html', 'quoted-printable');

		my $content = ssi::slurp_content( '/email_content/label.html' );
		push @attachments, $Label->Type()->name(). ' for docket ' . $Label->docket().'.html', 
			 MIME::QuotedPrint::encode_qp( Encode::encode('utf-8',
						 ssi::variable_substitution( \$content, \%info ) ) ), 'text/html', 'quoted-printable';

		my $Project = $Label->Project();
		my $CSR;
		if ( $Project and $Project->Company()->salesrep_id() ) {
			$CSR = new openprint::User( $Project->Company()->salesrep_id() );
		} # end if


		my $Email = new openprint::Email();
		$variable{information} .= $Email->send(
#TO  =>  'iconnor@point-one.com',
				TO  =>  [ split(',', $param{to}) ],
				( $CSR ? ( CC => sprintf('"%s" <%s>', $CSR->name(), $CSR->email() ) ) : () ),
				FROM    =>  $param{from},
				SUBJECT =>  $param{subject},
				ATTACHMENTS =>  \@attachments,
				);
		(new openprint::Log())->save({
				action=>'Send PackingSlip', 
				Object=>$Label,
				note=> 'Emailed from ' . $param{from} . ' to the following recipients:<br/>' . $variable{information} });

		$variable{ExternalRedirect} = '/employee/production/labels/label.html?id='.$Label->id();
	} # end if
} # end sub label

sub _send_email {
	$variable{Label} = new openprint::Label( $param{id} );
} # end _send_email

1;
__END__
