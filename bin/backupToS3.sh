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
	echo Backing up ${file} to ${BUCKET}
	s3cmd put --storage-class=${STORAGE} --no-progress --stats "${file}" ${BUCKET}
	unlink ${file}
done
