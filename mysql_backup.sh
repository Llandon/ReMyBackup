#!/bin/bash

##
## Keep it small & simple MySQL backup skript
##
## 2008 Andreas Schwarz
##

DBAdmin=${1}
DBHost=${2}
DBAdminPass=${3}
BackupPath=${4}

IGNORE="mysql|information_schema"

# check if all dependencies are met 
if ! [ -x "/usr/bin/logger" ] || ! [ -x "/usr/bin/mysql" ] || ! [ -x "/usr/bin/mysqldump" ]; then
	builtin echo "Missing dependency"
	exit 1
fi

# check if BackupPath is a writeable directory
if [ ! -d $BackupPath ] || [ ! -w $BackupPath ]; then /usr/bin/logger "$0 - invalid or not writeable backup path"; exit 1; fi

# list of databases without ingored ones
DBS="$(/usr/bin/mysql -u$DBAdmin -h$DBHost -p$DBAdminPass -Bse 'show databases' | /bin/grep -Ev $IGNORE)"

/usr/bin/logger "$0 - database backup begins on $HOSTNAME by $USER($UID)";

for DB in $DBS; do
	/usr/bin/logger "$0 - backup from database $DB start"
	/usr/bin/mysqldump -u$DBAdmin -h$DBHost -p$DBAdminPass --events --comments -R $DB > $BackupPath/database_${DB}_$(date +%A).sql
	/usr/bin/logger "$0 - backup from database $DB finished"
done

/usr/bin/logger "$0 - database backup finished";

exit 0;

