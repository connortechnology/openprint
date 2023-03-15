use strict;
package openprint::License;
our @ISA = qw(openprint::Object);

require openprint::License_Host;
require openprint::Software;
require File::Slurp;
require JSON;
use Crypt::OpenSSL::Random;
use Crypt::OpenSSL::RSA;
use MIME::Base64;

use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults );
$debug = 1;
$table = 'licenses';
$serial='licenses_id_seq';
%fields = (
		id						=>	'id',
    company_id    =>  'company_id',
    site_id       =>  'site_id',
		serialkey			=>	'serialkey',
		max_uses			=>	'max_uses',
		purchased_on	=>	'purchased_on',
		expires_on		=>	'expires_on',
		software_id		=>	'software_id',
		software			=>	undef,
		comment       =>	'comment',
		created_on		=>	'created_on',
		updated_on		=>	'updated_on',
    features_json      =>  'features_json', # json encoded
    features => undef,
		);
%find_fields = (
		host_id	=>	'id IN (SELECT license_id FROM license_hosts where host_id=?)',
);
%transforms = (
		serialkey	=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
		comment		=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
		);
%defaults = (
		created_on		=>	q`'NOW'`,
		updated_on		=>	q`'NOW'`,
		serialkey			=>	undef,
		max_uses			=>	1,
		purchased_on	=>	undef,
		expires_on		=>	undef,
		software_id		=>	undef,
);
sub software {
	if ( @_ > 1 ) {
		my $Software = openprint::Software->find_one('name lc'=> lc openprint::Software->transform('name',$_[1]) );
		if ( ! $Software ) {
			$Software = new openprint::Software();
			$Software->save({name=>$_[1]});
		} # end if
		$_[0]{software_id} = $Software->id();
		$_[0]{software} = $Software->name();
	}
	if ( ! $_[0]{software} ) {
		$_[0]{software} = new openprint::Software( $_[0]{software_id} )->name();
	} # end if
	return $_[0]{software};
} # end sub software

sub Hosts {
	return map { $_->Host() } openprint::License_Host->find(license_id=>$_[0]{id});
} # end sub Hosts

sub delete {
  return $_[0]->destroy();
}

sub destroy {
  my $self = shift;
  my $result = '';
  foreach ( openprint::License_Host->find(license_id=>$$self{id})) {
    $result .= $_->destroy();
  }
  $result = $self->SUPER::destroy();
  return $result;
}

sub features {
  my $self = shift;
  if (@_) {
    $$self{features} = shift;
    $$self{features_json} = JSON::encode_json($$self{features});
  } elsif (!$$self{features}) {
    $$self{features} = $$self{features_json} ? JSON::decode_json($$self{features_json}) : {};
  }
  return $$self{features};
}

sub generate_key {
  my $self = shift;
  #my $private_key = $config{'Licensing Private Key'};
  #my $private_key = misc::load_file($openprint::log, '/var/www/crm/etc/ssl/cloudmule.key');
  my $private_key = misc::load_file($openprint::log, '/tmp/key');
  $openprint::log->debug("Private key $private_key");
  if (!$private_key) {
    $openprint::log->error("No private key, can't continue");
    return;
  }
  #my $rsa = Crypt::OpenSSL::RSA->generate_key(2048);
  #$openprint::log->debug($rsa->get_private_key_string());
  #File::Slurp::write_file('/tmp/key', { atomic => 1, err_mode=>'carp' }, $rsa->get_private_key_string()) or warn "Couldn't save key file";
  #File::Slurp::write_file('/tmp/key.pub', { atomic => 1, err_mode=>'carp' }, $rsa->get_public_key_string()) or warn "Couldn't save key file";

  my $rsa = Crypt::OpenSSL::RSA->new_private_key($private_key);
  $rsa->use_pkcs1_padding();
  $$self{serialkey} = encode_base64($rsa->private_encrypt($self->id().','.$self->features_json()));
  $openprint::log->debug($$self{serialkey});
}

1;
__END__
