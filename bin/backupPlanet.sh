#!/bin/bash
# 
# create a database backup in osm.pbf format, using pg_dump and planet-dump-ng

# parse arguments
if [ $# -ne 3 ]; then
	cat <<USAGE
Usage:
	$0 dir db copyto
USAGE
	exit 1
fi
BASE=$1          # /opt/opengeofiction/backup
DB=$2            # ogfdevapi
PUBLISH=$3       # /var/www/html/ogfdata.rent-a-planet.com/public_html/backups
MINFREE=12582912 # 12GB
TIMESTAMP=`date "+%Y%m%d_%H%M%S%Z"`
PLANET_DUMP_NG=/opt/opengeofiction/planet-dump-ng/bin/planet-dump-ng

# ensure the backups directory exists and is writable 
if [ ! -w "$BASE/" ]; then
	echo "ERROR: $BASE does not exist or not writable"
  exit 2
fi

# ensure the publish directory exists and is writable 
if [ ! -w "$PUBLISH/" ]; then
	echo "ERROR: $PUBLISH does not exist or not writable"
  exit 3
fi

# make sure there is enough free space
cd "${BASE}"
FREE=`df -k --output=avail . | tail -n1`
if [[ $FREE -lt $MINFREE ]]; then
	echo "ERROR: Insufficient free disk space"
	exit 4
fi;

# nice ourself
renice -n 10 $$

# files & dirs used
backup_pg=${TIMESTAMP}.dmp
backup_tmp=${TIMESTAMP}_ogf-planet
backup_pbf=${TIMESTAMP}_ogf-planet.osm.pbf
lastthu=$(ncal -h | awk '/Th/ {print $NF}')
today=$(date +%d)
if [[ $lastthu -eq $today ]]; then
	backup_pbf=${TIMESTAMP}_ogf-planet-monthly.osm.pbf
fi
latest_pbf=ogf-planet.osm.pbf

# create the postgres backup dump file
echo "Backing up to ${backup_pg}"
pg_dump --format=custom --file=${backup_pg} ${DB}
status=$?
if [ $status -ne 0 ]; then
	echo "ERROR: backup failed"
	exit 5
fi

# create temp dir for the planet-dump-ng files
if ! mkdir ${backup_tmp}; then
	echo "ERROR: cannot create temp planet dir"
	exit 6
fi
cd ${backup_tmp}

# run planet-dump-ng
${PLANET_DUMP_NG} --pbf=../${backup_pbf} --dump-file=../${backup_pg} --max-concurrency=4
status=$?
if [ $status -ne 0 ]; then
	echo "ERROR: planet-dump-ng failed"
	exit 7
fi
cd ..
rm -r ${backup_tmp}

# copy to the publish dir
if [ -f "${PUBLISH}/${latest_pbf}" ]; then
	rm -f "${PUBLISH}/${latest_pbf}"
fi
echo "copying ${backup_pbf} to ${PUBLISH}/${backup_pbf}"
cp ${backup_pbf} "${PUBLISH}/${backup_pbf}"
echo "creating ${latest_pbf} link"
ln "${PUBLISH}/${backup_pbf}" "${PUBLISH}/${latest_pbf}"

# delete old backups
echo "deleting old backups..."
find "${BASE}" -mtime +15 -ls -delete

exit 0



