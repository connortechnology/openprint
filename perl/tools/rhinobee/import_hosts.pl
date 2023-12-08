#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use utf8;
use strict;
use Encode;

require sql;
require logger;
require openprint::Object;
require openprint::Host;
require openprint::Location;
require Text::CSV;
require Geo::Coordinates::Transform;

use openprint ();
use vars qw( $log );
*log = \$openprint::log;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$openprint::config{db_name} = 'rhinobee';
my $dbh = $openprint::dbh = sql::open_sql( $log, (database=>'rhinobee', driver=>'Pg',login=>'rhinobee', password=>'rhinobee', host=>'localhost') );

my $file ='test.csv';
my $csv = Text::CSV->new({ sep_char => ';' });

open my $fh, $file or die "Unable to open file $file $!";
my $line_num = 0;
while (my $line = <$fh>) {
  $line_num += 1;
  #chomp $line;
  #$line =~ s/[^\x{0000}-\x{007F}]+/ /g;
  #$line = Encode::encode_utf8($line);
  if ($csv->parse($line)) {
    #rb_id;mrtg_add_status;mrtg_template;mrtg_gateway;mrtg_relay;relay;relay_rb_id;nagios_host_template;nagios_name_1;nagios_alias;ip_address;nagios_name_1;nagios_parent;nagios_statusmap_image;nagios_service_template;nagios_name_2;nagios_service_description;nagios_check_command
    my @fields = qw(rbid mrtg_add_status mrtg_template mrtg_gateway mrtg_relay
      relay relay_rb_id 
      nagios_host_template nagios_name_1 nagios_alias ip_address nagios_notes nagios_parent nagios_statusmap_image
      nagios_service_template nagios_name_2 nagios_service_description nagios_check_command);
    my %row;
    @row{@fields} = $csv->fields();
    print "Line $line_num\n";
    print join("\n", (map { $_.'=>'.$row{$_} } @fields), '');

    my @hi = openprint::Host_Interface->find(ip=>$row{ip_address});
    if (@hi > 1) {
      print "Error, more than 1 host found for $row{ip_address}\n";
      #foreach (@hi) {print $_->to_string()."\n";};
      foreach my $hi (@hi) {
        my $nagios_name_1 = $hi->Host()->info('nagios_name_1');
        if ( $nagios_name_1 eq $row{nagios_name_1}) {
          print "Choosing based on nagios_name_1 $nagios_name_1 == $row{nagios_name_1}\n";
          @hi = ($hi);
          last;
        } else {
          print "Didn't choose based on nagios_name_1 because $nagios_name_1 == $row{nagios_name_1}\n";
        }
      }
      if (@hi > 1 ) {
        if (confirm("Couldn't find one to match. Add new?")) {
          my $host = new openprint::Host();
          $host->save({name=>$row{nagios_name_1}, hostname=>$row{nagios_name_1}});
          my $hi = new openprint::Host_Interface();
          $hi->save({ip=>$row{ip_address}, host_id=>$host->id()});
          @hi = ($hi);
        } else {
          next;
        }
      }
    } elsif (!@hi) {
      print "Nothing found for $row{ip_address}\n";
      if (confirm("Add host for $row{nagios_name_1} [Y|n]", 'Y')) {
        my $host = new openprint::Host();
        $host->save({name=>$row{nagios_name_1}, hostname=>$row{nagios_name_1}});
        my $hi = new openprint::Host_Interface();
        $hi->save({ip=>$row{ip_address}, host_id=>$host->id()});
        push @hi, $hi;
      }
    } else {
      my $host = $hi[0]->Host();

      my $info_rb_id = $host->info('rbid');
      if ($info_rb_id ne $row{rbid}) {
        print "Host with same ip but different rb_id $info_rb_id != $row{rbid} found, add new?\n";
        if (confirm("Add host for $row{nagios_name_1} [Y|n]", 'Y')) {
          $host = new openprint::Host();
          $host->save({name=>$row{nagios_name_1}, hostname=>$row{nagios_name_1}});
          my $hi = new openprint::Host_Interface();
          $hi->save({ip=>$row{ip_address}, host_id=>$host->id()});
          @hi = ( $hi );
        }
      } else {
        my $nagios_name_1 = $host->info('nagios_name_1');
        if ($nagios_name_1 ne $row{nagios_name_1}) {
          print "Host with same ip but different nagios_name_1 $nagios_name_1 != $row{nagios_name_1} found, add new?\n";
          if (confirm("Add host for $row{nagios_name_1} [Y|n]", 'Y')) {
            $host = new openprint::Host();
            $host->save({name=>$row{nagios_name_1}, hostname=>$row{nagios_name_1}});
            my $hi = new openprint::Host_Interface();
            $hi->save({ip=>$row{ip_address}, host_id=>$host->id()});
            @hi = ( $hi );
          }
        }
      }
    }
    my $host = $hi[0]->Host();

    if ($host) {
      $host->Info('', undef);
      foreach my $field (@fields) {
        my $info = $host->Info($field);
        if (!$info) {
          $info = new openprint::Host_Info();
          $info->save({host_id=>$host->id(), name=>$field, value=>$row{$field}});
        } elsif ($info->value() ne $row{$field}) {
          if (confirm("Update $field from $$info{value} to $row{$field}", 'Y')) {
            $info->save({value=>$row{$field}});
          }
        }
      }
    }

  } else {
    print "Failed parsing $line\n";
  }
}
$dbh->disconnect();

sub confirm {
my $prompt = shift || 'confirm?';
my $default = shift || 'Y';

my $yesno = 0;
print($prompt . ($default eq 'Y'?'Y':'y').'/'.($default eq 'N' ? 'N' : 'n'). '/q: ');
my $char = <>;
chomp($char);
exit(0) if $char eq 'q';
$char = $default if !$char;
$yesno = ( $char =~ /[yY]/ );
return $yesno;
}

1;
__END__
