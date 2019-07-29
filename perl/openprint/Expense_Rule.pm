package openprint::Expense_Rule;
our @ISA = qw(openprint::Object);

require JSON;

use vars qw( $debug $table $serial %fields %transforms %defaults );
$debug = 0;
$table = 'expense_rules';
$serial = 'expense_rules_id_seq';
%fields = (
  id          =>  'id',
  name        =>  'name',
  rules_json  =>  'rules_json',
  action_json =>  'action_json',
);
%transforms = (
  name => [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);
%defaults = (
);

sub action { 
  my $self = shift;

  $$self{action} = JSON::decode_json($$self{action_json});
  return $$self{action};
}

sub rules {
  my $self = shift;

  my $rules = JSON::decode_json($$self{rules_json});
  if ( ref $rules ne 'ARRAY' ) {
    $rules = [ $rules ];
  }
  $$self{rules} = $rules;
  return @{$$self{rules}};
}

sub match {
  my ( $self, $line ) = @_;
  foreach my $rule ( $self->rules() ) {
    foreach my $key ( keys %{$rule} ) {
    $openprint::log->debug("rule: $key $$rule{$key}");
      my @matches;
      if ( $$rule{$key} =~ /^\/(.*)\/$/ ) {
        @matches = $$line{$key} =~ /$1/;
        $openprint::log->debug("testing $key $$line{$key} =~ $$rule{$key} @matches $?");
        if ( @matches ) {
          #$openprint::log->debug("Have matches ".%+);
          foreach my $p ( keys %+ ) {
            $$self{matches}{$p} = $+{$p};
            $openprint::log->debug("Have matches $p => " . $$self{matches}{$p});
          }
          return scalar @matches;
        }
      } else {
        $openprint::log->error("Unknown test $key $$rule{$key}");
      } # end if rule type
    } # end foreach key
  } # end foreach rule
  return 0;
} # end sub match

sub apply {
  my ( $self, $Expense ) = @_;

  my %action = %{$self->action()};

  foreach my $key ( keys %action ) {

    if ( $action{$key} =~ /\$/ ) {
      $Expense->$key(eval $action{$key});
      $openprint::log->error("Failure to eval $action{$key} $@") if $@;
    } else {
      $Expense->$key($action{$key});
    }
    $openprint::log->debug("Applied actoin $key $action{$key} = $$Expense{$key}");
  } # end foreach key
} # end sub apply

1;
__END__
