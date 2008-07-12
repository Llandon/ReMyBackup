#!/bin/bash

##
## Keep it small & simple MySQL backup skript
##
## 2008 Andreas Schwarz
##

DBAdminPass=${1}
BackupPath=${2}

if [ -z "${BackupPath}" ]; then
	builtin echo "no backup path"
	exit 1
fi
if ! [ -d "${BackupPath}" ]; then
	builtin echo "backup path isn't a directory"
	exit 1
fi

mysqldump -uroot -hlocalhost '$DBAdminPass' --events --comments -R --all-databases > $BackupPath/databases_$(date +%A).sql

