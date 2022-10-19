#!/bin/bash
# 
# Watch a directory for list of files to backup to AWS S3

# parse arguments
if [ $# -ne 3 ]; then
	cat <<USAGE
Usage:
	$0 dir bucket storage-class
USAGE
	exit 1
fi
DIR=$1
BUCKET=$2
STORAGE=$3

# setup working dir
cd ${DIR}

FILES="*"
for file in $FILES
do
	store=${STORAGE}
	if [[ ${file:0:5} = "daily" ]]; then
		store=STANDARD
	fi
	echo Backing up ${file} to ${BUCKET} using ${store}
	s3cmd put --storage-class=${store} --no-progress --stats "${file}" ${BUCKET}
	unlink ${file}
done
