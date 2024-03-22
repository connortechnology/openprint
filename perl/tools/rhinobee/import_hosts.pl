#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use utf8;
use strict;
use warnings;
use Encode;

require sql;
require misc;
require logger;
require openprint::Object;
require openprint::Host;
require openprint::Location;
require Text::CSV;

use openprint ();
use vars qw( $log );
*log = \$openprint::log;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$openprint::config{db_name} = 'rhinobee';
my $dbh = $openprint::dbh = sql::open_sql( $log, (database=>'rhinobee', driver=>'Pg',login=>'rhinobee', password=>'rhinobee', host=>'localhost') );

my $file = @ARGV ? $ARGV[0] : 'test.csv';

my $csv = Text::CSV->new({ sep_char => ';', binary => 1,
    quote_char=>'"',
    escape_char=>'\\',
    #quote_char=>undef,
    #allow_loose_quotes => 1,
    #quote_space => 0,
    #keep_meta_info => 11
  });

my $output_csv = Text::CSV->new({ sep_char => ';', binary => 1,
    quote_char=>undef,
    allow_loose_quotes => 1,
    quote_space => 0,
    #keep_meta_info => 11
  });

open(my $output_fh, '>', 'hostid+'.$file) or die "Unable to open file host_id+$file $!";

open my $fh, $file or die "Unable to open file $file $!";
my @fields = qw(rbid mrtg_add_status mrtg_template mrtg_gateway mrtg_relay
relay relay_rb_id 
snmp_community
nagios_host_template nagios_name_1 nagios_alias ip_address nagios_notes nagios_parent nagios_statusmap_image
nagios_service_template nagios_name_2 nagios_service_description nagios_check_command);
my %new_fields = map { $_ => $_ } @fields;

my @header = ( 'host_id', @fields);
my @data;

my $line_num = 0;
while (my $line = <>) {
  chomp($line);
  #print $line."\n";

  my @parts = split(';', $line);
  for (my $i=0; $i<@parts; $i++) {
    if (index($parts[$i], '"')>=0) {
      $parts[$i] =~ s/"/\\\"/g;
      $parts[$i] = '"'.$parts[$i].'"';
    }
  }
  my $fixed_line = join(';', @parts);
  #print $fixed_line."\n";
  $line_num += 1;
  if ($csv->parse($fixed_line)) {
    my %row;
    my @row = $csv->fields();
    #print "@row\n";
    if ($row[0] eq 'host_rbid') {
      print $output_fh 'host_id;'.$line."\n";
      confirm("Have new fields: $line");
      %new_fields = ();
      @new_fields{@fields} = @row;
      next;
    }
    @row{@fields} = @row;

    #print "Line $line_num\n";
    #print join("\n", (map { $_.'=>'.$row{$_} } @fields), '');

    if ($row{ip_address} eq 'pbx.bigbiz.com') {
      $row{ip_address} = '64.62.128.247';
    }
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
      if (@hi > 1) {
        if (confirm("Couldn't find one to match. Add new?")) {
          my $host = new openprint::Host();
          $host->save({name=>$row{nagios_name_1}, hostname=>$row{nagios_name_1}});
          my $hi = new openprint::Host_Interface();
          $hi->save({ip=>$row{ip_address}, host_id=>$host->id()});
          @hi = ($hi);
        } else {
          die "CHOSE NO\n";
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
      } else {
        die "CHose NO!";
      }
    } else { # exactly 1 hi
      my $host = $hi[0]->Host();

      my $info_rb_id = $host->info('rbid');
      $info_rb_id = $host->info($new_fields{rbid}) if (! $info_rb_id) and ($new_fields{rbid} ne 'rbid');
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
        my $info = $host->Info($field); # loa
        $info = $host->Info($new_fields{$field}) if !$info and $new_fields{$field} ne $field;
        #print "$field $new_fields{$field} $row{$new_fields{$field}}\n";
        if (!$info) {
          $info = new openprint::Host_Info();
          $info->save({host_id=>$host->id(), name=>$field, value=>$row{$field}});
        } elsif ($info->value() ne $row{$field}) {
          if (confirm("Update $field from\n$$info{value} to\n$row{$field}", 'Y')) {
            $info->save({value=>$row{$field}});
          }
        } elsif ($info->name() ne $field) {
          $info->save({name=>$field});
        }
      }
    }
    push @data, @row;
    #push @data, (($host?$host->id():''), @row);

    #$csv->keep_meta_info(11);
    #my $status = $output_csv->combine(@row);
    #my $output_line = $csv->string() . "\n";
    #if ($line ne $output_line) {
    #confirm("\n$line\n!=\n$output_line, continue?", 'Y');
    #}
    #print $output_fh $line."\n";
    print $output_fh ($host?$host->id():'').';'.$line."\n";
  } else {
    confirm("Failed to parse $line");
  }
} # end while

close($fh);
close($output_fh);
#misc::csv_to_file('hostid+'.$file, \@header, \@data, {sep_char => ';', binary=>1, quote_char=>undef, quote_space => 0});
$dbh->disconnect();

sub confirm {
  my $prompt = shift || 'confirm?';
  my $default = shift || 'Y';

  my $yesno = 0;
  print('Confirm: '.$prompt . ($default eq 'Y'?'Y':'y').'/'.($default eq 'N' ? 'N' : 'n'). '/q: ');
  my $char = <STDIN>;
  print $char;
  chomp($char);
  exit(0) if $char eq 'q';
  $char = $default if !$char;
  $yesno = ( $char =~ /[yY]/ );
  return $yesno;
}

1;
__END__
