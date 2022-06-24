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
PLANET_DUMP_NG_THREADS=2
BACKUP_QUEUE=/opt/opengeofiction/backup-to-s3-queue
LOCKFILE=${BASE}/backup.lock

# ensure the backups directory exists and is writable 
if [ ! -w "$BASE/" ]; then
	echo "ERROR: $BASE does not exist or not writable"
  exit 2
fi

# delete old backups - older than 30 hours
echo "deleting old backups..."
find "${BASE}" -maxdepth 1 -mmin +$((60*30)) -ls -delete

# ensure the publish directory exists and is writable 
if [ ! -w "$PUBLISH/" ]; then
	echo "ERROR: $PUBLISH does not exist or not writable"
  exit 3
fi

# delete old published backups:
#  > monthly backups older than a year
#  > weekly backups older than a month
#  > daily backups older than a week
echo "deleting old published backups..."
find "${PUBLISH}" -maxdepth 1 -name '*_ogf-planet-monthly.osm.pbf' -mmin +$((60*24*365)) -ls -delete
find "${PUBLISH}" -maxdepth 1 -name '*_ogf-planet-weekly.osm.pbf' -mmin +$((60*24*30)) -ls -delete
find "${PUBLISH}" -maxdepth 1 -name '*_ogf-planet.osm.pbf' -mmin +$((60*24*7)) -ls -delete

# make sure there is enough free space
cd "${BASE}"
FREE=`df -k --output=avail . | tail -n1`
if [[ $FREE -lt $MINFREE ]]; then
	echo "ERROR: Insufficient free disk space"
	exit 4
fi;

# nice ourself
renice -n 10 $$

# ensure we're not already running
if ! mkdir ${LOCKFILE} 2>/dev/null; then
	echo "$0 is already running" >&2
	exit 1
else
	# release lock on clean exit, and if ...
	trap "rm -rf ${LOCKFILE}; exit" INT TERM EXIT
	echo "$0 got lock"
fi

# files & dirs used - work out if daily, weekly, monthly or yearly
backup_pg=${TIMESTAMP}.dmp
backup_tmp=${TIMESTAMP}_ogf-planet
backup_pbf=${TIMESTAMP}_ogf-planet.osm.pbf
lastthu=$(ncal -h | awk '/Th/ {print $NF}')
today=$(date +%-d)
timeframe=daily
if [[ $(date +%u) -eq 4 ]]; then
	backup_pbf=${TIMESTAMP}_ogf-planet-weekly.osm.pbf
	timeframe=weekly
	if [[ $lastthu -eq $today ]]; then
		backup_pbf=${TIMESTAMP}_ogf-planet-monthly.osm.pbf
		timeframe=monthly
		if [[ $(date +%-m) -eq 12 ]]; then
			backup_pbf=${TIMESTAMP}_ogf-planet-yearly.osm.pbf
			timeframe=yearly
		fi
	fi
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

if [ ${timeframe} != "daily" ]; then
	# queue for backup to S3 (note always weekly here)
	ln ${backup_pg} ${BACKUP_QUEUE}/weekly:pgsql:${backup_pg} 
fi

# create temp dir for the planet-dump-ng files
if ! mkdir ${backup_tmp}; then
	echo "ERROR: cannot create temp planet dir"
	exit 6
fi
cd ${backup_tmp}

# run planet-dump-ng
${PLANET_DUMP_NG} --pbf=../${backup_pbf} --dump-file=../${backup_pg} --max-concurrency=${PLANET_DUMP_NG_THREADS}
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

# queue for backup to S3
ln ${backup_pbf} ${BACKUP_QUEUE}/${timeframe}:planet:${backup_pbf}

exit 0



