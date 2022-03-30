#!/bin/bash
# 
# Watch a directory for list of tiles to expire, call render_expire on them

BASE=/opt/opengeofiction/render

# parse arguments
if [ $# -ne 3 ]; then
	cat <<USAGE
Usage:
	$0 style-name zoom-min zoom-max
USAGE
	exit 1
fi
STYLE=$1
ZOOM_MIN=$2
ZOOM_MAX=$3

# setup working dir
DIR=${BASE}/${STYLE}/expire-queue
cd ${DIR}

FILES="*.list"
for efile in $FILES
do
	wc -l ${efile}
	cat ${efile} | render_expired --map=${STYLE} --min-zoom=${ZOOM_MIN} --max-zoom=${ZOOM_MAX} --touch-from=${ZOOM_MIN}
	unlink ${efile}
done
