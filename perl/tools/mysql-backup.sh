#!/bin/bash

DB_BACKUP_DIR="/var/backups/mysql/"
DB_BACKUP="$DB_BACKUP_DIR`date +%Y-%m-%d`"
HN=`hostname | awk -F. '{print $1}'`

# Create the backup directory
mkdir -p $DB_BACKUP

# Remove backups older than 10 days
find $DB_BACKUP_DIR -maxdepth 1 -type d -mtime +10 -exec rm -rf {} \;

# Backup each database on the system
for db in $(mysql --defaults-file=/etc/mysql/debian.cnf -e 'show databases' -s --skip-column-names|grep -viE '(staging|performance_schema|information_schema)');
do mysqldump --defaults-file=/etc/mysql/debian.cnf --events --opt --single-transaction $db | gzip > "$DB_BACKUP/mysqldump-$HN-$db-$(date +%Y-%m-%d).gz";
done
