#!/bin/bash

##
## Keep it small & simple MySQL backup skript
##
## 2008 Andreas Schwarz
##

DBAdminPass=${1}
BackupPath=${2}

# check if pass was set
if [ -z "${DBAdminPass}" ]; then
	builtin echo "no password"
	exit 1
fi

# check if path was set
if [ -z "${BackupPath}" ]; then
	builtin echo "no backup path"
	exit 1
fi

# check if path is a directory
if ! [ -d "${BackupPath}" ]; then
	builtin echo "backup path isn't a directory"
	exit 1
fi

# check if logger is executable
if ! [ -x "/usr/bin/logger" ]; then
        builtin echo "Missing logger"
        exit 1
fi

/usr/bin/logger "$0: start mysql backup on $HOSTNAME by $USER($UID)"

mysqldump -uroot -hlocalhost '$DBAdminPass' --events --comments -R --all-databases > $BackupPath/databases_$(date +%A).sql

/usr/bin/logger "$0: end mysql backup on $HOSTNAME by $USER($UID)"

