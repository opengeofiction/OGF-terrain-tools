#!/bin/bash
# 
# Watch a directory for list of tiles to expire, call render_expire on them

BASE=/opt/opengeofiction/render

# parse arguments
if [ $# -ne 1 ]; then
	cat <<USAGE
Usage:
	$0 style-name
USAGE
	exit 1
fi
STYLE=$1

# setup working dir
DIR=${BASE}/${STYLE}/expire-queue
cd ${DIR}

FILES="*.list"
for efile in $FILES
do
	wc -l ${efile}
	cat ${efile} | render_expired --map=${STYLE} --min-zoom=5 --max-zoom=19 --touch-from=5
	unlink ${efile}
done
