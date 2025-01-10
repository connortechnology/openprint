#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

This script set ownership for all table, sequence and views for a given database

Credit: Based on http://stackoverflow.com/a/2686185/305019 by Alex Soto
        Also merged changes from @sharoonthomas

OPTIONS:
   -h      Show this message
   -d      Database name
   -o      Owner
EOF
}

DB_NAME=
NEW_OWNER=
DB_SCHEMA='public'

while getopts "hd:o:s:" OPTION 
do
    case $OPTION in
        h)
            usage
            exit 1
            ;;
        s)
            DB_SCHEMA=$OPTARG
            ;;
        d)
            DB_NAME=$OPTARG
            ;;
        o)
            NEW_OWNER=$OPTARG
            ;;
    esac
done

if [[ -z $DB_NAME ]] || [[ -z $NEW_OWNER ]]
then
     usage
     exit 1
fi

for tbl in `psql -qAt -c "select tablename from pg_tables where schemaname = '${DB_SCHEMA}';" ${DB_NAME}` \
           `psql -qAt -c "select sequence_name from information_schema.sequences where sequence_schema = '${DB_SCHEMA}';" ${DB_NAME}` \
           `psql -qAt -c "select table_name from information_schema.views where table_schema = '${DB_SCHEMA}';" ${DB_NAME}` ;
do
    echo "alter table \"${DB_SCHEMA}\".\"$tbl\" owner to ${NEW_OWNER} ${DB_NAME}";
    psql -c "alter table \"${DB_SCHEMA}\".\"$tbl\" owner to ${NEW_OWNER}" ${DB_NAME};
done
psql -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${DB_SCHEMA} TO ${NEW_OWNER}" ${DB_NAME};
psql -c "GRANT ALL ON ALL TABLES IN SCHEMA {DB_SCHEMA} TO ${NEW_OWNER}" ${DB_NAME};
psql -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA {DB_SCHEMA} TO ${NEW_OWNER}" ${DB_NAME};
psql -c "GRANT USAGE ON SCHEMA {DB_SCHEMA} TO ${NEW_OWNER}" ${DB_NAME};
