#!/usr/bin/perl

my $DB=$ARGV[0];
my $NEW_OWNER=$ARGV[1];
my @funcs = `psql -qAt -c"SELECT ns.nspname || '.' || proname || '(' || oidvectortypes(proargtypes) || ')' FROM pg_proc INNER JOIN pg_namespace ns ON (pg_proc.pronamespace = ns.oid) WHERE ns.nspname='public' order by proname;" $DB`;
foreach my $func (@funcs) {
  print "ALTER FUNCTION $func OWNER TO $NEW_OWNER $DB\n";
  `psql -c "ALTER FUNCTION $func OWNER TO $NEW_OWNER" $DB`;
}
my @tbl = `psql -qAt -c "select tablename from pg_tables where schemaname = 'public';" $DB` ;
foreach my $tbl (@tbl) {
  chomp $tbl;
print qq`psql -c "alter table \"$tbl\" owner to $NEW_OWNER" $DB\n`;
`psql -c "alter table \"$tbl\" owner to $NEW_OWNER" $DB`;
}
my @seq = `psql -qAt -c "select sequence_name from information_schema.sequences where sequence_schema = 'public';" $DB` ;
foreach my $seq (@seq) {
  chomp $seq;
  print qq`psql -c "alter sequence \"$seq\" owner to $NEW_OWNER" $DB\n`;
  `psql -c "alter sequence \"$seq\" owner to $NEW_OWNER" $DB`;
}
my @tbl = `psql -qAt -c "select table_name from information_schema.views where table_schema = 'public';" $DB`;
foreach my $tbl (@tbl) {
  chomp $tbl;
  print qq`psql -c "alter view \"$tbl\" owner to $NEW_OWNER" $DB\n`;
 `psql -c "alter view \"$tbl\" owner to $NEW_OWNER" $DB`;
 }
