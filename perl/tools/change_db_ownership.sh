#!/bin/bash

DB=
NEW_OWNER=
for tbl in `psql -qAt -c "select tablename from pg_tables where schemaname = 'public';" $DB` ; do  psql -c "alter table \"$tbl\" owner to $NEW_OWNER" $DB ; done
for tbl in `psql -qAt -c "select sequence_name from information_schema.sequences where sequence_schema = 'public';" $DB` ; do  psql -c "alter sequence \"$tbl\" owner to $NEW_OWNER" $DB ; done
for tbl in `psql -qAt -c "select table_name from information_schema.views where table_schema = 'public';" $DB` ; do  psql -c "alter view \"$tbl\" owner to $NEW_OWNER" $DB ; done
