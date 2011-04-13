package openprint::employee_production_labels;
use strict;

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
	my $Label = new openprint::Label( $param{'id'} );
	if ( $param{'action'} eq 'update' ) {
		$param{'value'} =~ s/<br\/>/\n/ig;
		$Label->set_data($param{'field'}=>$param{'value'});
		$Label->save();
		$variable{'PageContent'} = join('',$Label->get_data($param{'field'}));
	} elsif ( $param{'action'} eq 'get' ) {
		$variable{'PageContent'} = join('',$Label->get_data($param{'field'}));
	} elsif ( $param{'action'} eq 'getnohtml' ) {
		$variable{'PageContent'} = join('',$Label->get_data($param{'field'}));
		$variable{'PageContent'} =~ s/<br\/>/\n/ig;
	} # end if
} # end sub _label

sub label {
	my $Label = $variable{'Label'} = new openprint::Label( $param{'id'} );
	if ( $param{'action'} eq 'Send' ) {
		my $email_template = misc::load_file( $log, $config{'SkinPath'} . '/email_template.html' );
		my @attachments;
		my %info;
		$info{'ReplacementText'} = $param{'body'};
		$info{'Label'} = $Label;

        $_ = MIME::QuotedPrint::encode_qp( Encode::encode('utf-8', ssi::variable_substitution( \$email_template, \%info ) ) );
        push @attachments, ('', $_, 'text/html', 'quoted-printable');

		my $content = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'}.'/email_content/label.html' );
		push @attachments, $Label->Type()->name(). ' for docket ' . $Label->docket().'.html', MIME::QuotedPrint::encode_qp( Encode::encode('utf-8',ssi::variable_substitution( \$content, \%info ) ) ), 'text/html', 'quoted-printable';

		my $Email = new openprint::Email();
        $variable{'information'} .= $Email->send(
                TO  =>  'iconnor@point-one.com',
                #TO  =>  [ split(',', $param{'to'}) ],
                FROM    =>  $param{'from'},
                SUBJECT =>  $param{'subject'},
                ATTACHMENTS =>  \@attachments,
                );

	} # end if
} # end sub label

sub _send_email {
	$variable{'Label'} = new openprint::Label( $param{'id'} );
} # end _send_email

1;
__END__
