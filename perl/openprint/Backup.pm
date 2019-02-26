use strict;
use warnings;
require openprint::Object;


package openprint::Backup;
our @ISA = qw( openprint::Object );

use constant DEST_PATH => '/var/backups';
use vars qw( $debug $table $serial %fields %find_fields %transforms %defaults %types );
$debug = 0;
$table = 'backups';
$serial = 'backups_id_seq';
%fields = (
	id  			  =>	'id',
	name      	=>	'name',
  path        =>  'path',
  username    =>  'username',
	enabled   	=>	'enabled',
	description	=>	'description',
	created_on	=>	'created_on',
	updated_on	=>	'updated_on',
	deleted		  =>	'deleted',
	host_id		  =>	'host_id',
	type			  =>	'type',
	lastran_on	=>	'lastran_on',
	owner_id		=>	'owner_id',
  keep        =>  'keep',
);
%find_fields = (
	#type	=>	'type_id = (SELECT id FROM Backup_types WHERE backup_types.name = ?)',
);
%transforms = (
	id			=>	[ 's/\D//g' ],
	keep		=>	[ 's/\D//g' ],
	name  	=>	[ 's/\s//g' ],
  path    =>   [ 's/\/+$//' ], # remove trailing /
	username  	=>	[ 's/\W//g' ],
	description	=>	[ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
	enabled     	=>	1,
	name        	=>	undef,
	created_on    =>	q`'NOW()'`,
	updated_on  	=>	q`'NOW()'`,
	lastran_on		=>	undef,
	deleted     	=>	0,
	type_id     	=>	undef,
	owner_id			=>	undef,
  keep          =>  undef,
);

%types = (
  daily => 'Daily',
  hourly =>  'Hourly',
  weekly =>  'Weekly',
  monthly => 'Monthly',
);

sub destroy {
	my $error;
	#require openprint::Log;
	#foreach my $Log ( openprint::Log->find('object_id'=>$_[0]{id}), object_type ) {
		#$error .= $Log->destroy();
		#return $error if $error;
	#} # end foreach Log

	$error .= $_[0]->SUPER::destroy();
	return $error;
} # end sub destroy

sub link_to {
	return sprintf('<a href="/employee/it/backup.html?backup_id=%d">%s</a>', 
    ($_[0]->id() ? $_[0]->id() : 0),
    ( (@_ > 1 and $_[1]) ? $_[1] : $_[0]->name() ),
  );
}

sub Owner {
  return new openprint::Company( $_[0]{owner_id} );
}
sub Host {
  return new openprint::Host( $_[0]{host_id} );
}

sub dest_path {
  if ( ! $_[0]{dest_path} ) {
    my $path = $_[0]{path};
    $path =~ s/\//_/g;
    $_[0]{dest_path} = join('/',
        DEST_PATH,
        ( $_[0]->owner_id() ? $_[0]->Owner()->name() : () ),
        $_[0]{name},
        ( defined $path ? $path : '' ),
        ( $_[0]->type() ? $_[0]->type() : () ),
        );
  }
  return $_[0]{dest_path};
}

sub run {
  if ( ! $_[0]->Host()->online() ) {
    return 'Host is not online.';
  }
  my $results = '';
  require IPC::Run3;
  my $type = $_[0]->type();
  my $dest = $_[0]->dest_path();

  my $keep = $_[0]{keep};
  if ( ! $keep ) {
    if ( $type eq 'daily' ) {
      $keep = 7;
    } elsif ( $type eq 'hourly' ) {
      $keep = 12;
    } elsif ( $type eq 'weekly' ) {
      $keep = 4;
    } elsif ( $type eq 'monthly' ) {
      $keep = 12;
    } else {
      $keep = 5;
    }
  }

  foreach my $ip ( ( map { $$_{ip} ? $$_{ip} : () } $_[0]->Host()->Interfaces() ), $_[0]->Host()->hostname() ) {
    my $stdout;
    my $stderr;
    my $log;

    my $command = qq`/var/www/testing/perl/tools/make_snapshot.sh -T -t $type -n $keep "$_[0]{username}\@$ip:$_[0]{path}" "$dest"`;

    $openprint::log->debug("Command: $command");
    IPC::Run3::run3( $command, undef, \$stdout, \$stderr );
    if ( $? ) {
    #my $log = File::Slurp::read_file("$dest.$type.0.log",err_mode => 'carp' );
    $results .= join( "\n", map { $_ ? $_ : () } ( $stdout , $stderr, $log ) );
      $openprint::log->error("ERror running backup. Reason: ($?) stdout($stdout) stderr($stderr)");
  (new openprint::Log())->save({
      Object  =>  $_[0],
      action  =>  'Failed Backup',
      note    =>  $results,
    });
      next;
    } # end if
    $openprint::log->error("Ran backup. Reason: ($?) stdout($stdout) stderr($stderr)");
    #my $log = File::Slurp::read_file("$dest.$type.0.log",err_mode => 'carp' );
    $results .= join( "\n", map { $_ ? $_ : () } ( $stdout , $stderr, $log ) );
    $_[0]->save({lastran_on=>'NOW()'});
    (new openprint::Log())->save({
        Object  =>  $_[0],
        action  =>  'Successful Backup',
        note    =>  $results,
    });

    # Stop after the first successful backup, as we are iterating through ips
    return $results;
  } # end foreach ip or hostname
  (new openprint::Log())->save({
      Object  =>  $_[0],
      action  =>  'Failed Backup',
      note    =>  $results,
    });
  return $results;
} # end sub run

sub size {
  my $self = shift;
  my $path = $self->dest_path();
  my @output = `/usr/bin/du -s "$path"`;
  if ( ! @output ) {
    $openprint::log->error("Failed getting size of $$self{dest_path}: @output");
    return undef;
  }
  $openprint::log->debug("Size of $$self{dest_path}: @output");
  my ( $size ) = $output[0] =~ /^(\d+)/;
  return $size;
}

1;
__END__
