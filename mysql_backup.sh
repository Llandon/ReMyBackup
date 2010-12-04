#!/bin/bash

##
## Keep it small & simple MySQL backup skript
##
## 2008-2010 Andreas Schwarz
##

DBAdmin=${1}
DBHost=${2}
DBAdminPass=${3}
BackupPath=${4}

IGNORE="mysql|information_schema|performance_schema"
ALLOPT="--events --comments -R"
SEPOPT="--events --comments -R"

# check if all arguments where set
if [ -z "${DBAdmin}" ] || [ -z "${DBHOST}" ] || [ -z "${DBAdminPass}" ] || [ -z "$BackupPath" ]; then
	builtin echo "no all arguments where set $0 [DB-Admin] [DB-Host] [DB-Admin-Ppassword] [Backup path]"
	exit 1
fi

# check if all dependencies are met 
if ! [ -x "/usr/bin/logger" ] || ! [ -x "/usr/bin/mysql" ] || ! [ -x "/usr/bin/mysqldump" ]; then
	builtin echo "Missing dependency"
	exit 1
fi

# check if BackupPath is a writeable directory
if [ ! -d $BackupPath ] || [ ! -w $BackupPath ]; then /usr/bin/logger "$0 - invalid or not writeable backup path"; exit 1; fi

/usr/bin/logger "$0 - database backup begins on $HOSTNAME by $USER($UID)";

# all databases backup ########################################################

/usr/bin/logger "$0 - backup all databases on $HOSTNAME"
if [[ $? == 0 ]]; then
	/usr/bin/logger "$0 - backup from databases finished"
else
	/usr/bin/logger "$0 - backup from databases failed"
fi

mysqldump -uroot -hlocalhost '$DBAdminPass' $ALLOPT --all-databases > $BackupPath/databases_$(date +%A).sql

# one file per database backup ################################################

# list of databases without ingored ones
DBS="$(/usr/bin/mysql -u$DBAdmin -h$DBHost -p$DBAdminPass -Bse 'show databases' | /bin/grep -Ev $IGNORE)"

for DB in $DBS; do
	/usr/bin/logger "$0 - backup from database $DB start"
	/usr/bin/mysqldump -u$DBAdmin -h$DBHost -p$DBAdminPass $SEPOPT -R $DB > $BackupPath/database_${DB}_$(date +%A).sql
	if [[ $? == 0 ]]; then
		/usr/bin/logger "$0 - backup from database $DB finished"
	else
		/usr/bin/logger "$0 - backup from database $DB failed"
	fi
done

/usr/bin/logger "$0 - database backup finished";

exit 0;

