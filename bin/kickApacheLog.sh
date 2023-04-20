#! /usr/bin/bash

DIR=/var/www/html/opengeofiction.net/log
LOG=$DIR/access.log

ls -lh $DIR

if [[ -f $LOG ]] && [[ ! -s $LOG ]]; then
	date
	echo Apache access.log is zero bytes 
	sleep 30
	ls -lh $DIR
fi

