#!/bin/bash -e

BASEDIR=/opt/opengeofiction/overpass
DBDIR=$BASEDIR/db
RULES=$DBDIR/rules
COMPRESSION=lz4
REPLICATION_URL=https://data.opengeofiction.net/replication/minute

OVERPASS_INSTALL=/opt/overpass
OVERPASS_RULES=$OVERPASS_INSTALL/rules
UPDATE_DATABASE=$OVERPASS_INSTALL/bin/update_database
UPDATE_FROM_DIR=$OVERPASS_INSTALL/bin/update_from_dir
OSM3S_QUERY=$OVERPASS_INSTALL/bin/osm3s_query


FNAME=$1
if [[ "x$FNAME" == "x" ]]; then
  echo "Usage: overpass-import-db.sh <OSM file>"
  exit 1
fi

case "$FNAME" in
  *.gz) UNPACKER='gunzip -c' ;;
  *.bz2) UNPACKER='bunzip2 -c' ;;
  *) UNPACKER='osmium cat -o - -f xml' ;;
esac

#META=--meta
META=--keep-attic
#META=

sudo systemctl stop overpass-area-processor || true
sudo systemctl stop overpass-update || true
sudo systemctl stop overpass-area-dispatcher || true
sudo systemctl stop overpass-dispatcher || true

sleep 2

# Remove old database
rm -rf $DBDIR
mkdir $DBDIR

$UNPACKER $FNAME | $UPDATE_DATABASE --db-dir=$DBDIR --compression-method=$COMPRESSION --map-compression-method=$COMPRESSION $META

ln -s $OVERPASS_RULES $RULES

echo "Import finished. Catching up with new changes."

sudo systemctl start overpass-dispatcher
sudo systemctl start overpass-area-dispatcher

PYOSMIUM="pyosmium-get-changes --server $REPLICATION_URL --diff-type osc.gz -f $DBDIR/replicate-id"
PYOSMIUM="$PYOSMIUM --no-deduplicate"

# Get the replication id
$PYOSMIUM -v -O $FNAME --ignore-osmosis-headers

rm -f $BASEDIR/diffs/*

while $PYOSMIUM -v -s 1000 -o $BASEDIR/diffs/latest.osc; do
  if [ ! -f $DBDIR/replicate-id ]; then
    echo "Replication ID not written."
    exit 1
  fi
  DATA_VERSION=`osmium fileinfo -e -g data.timestamp.last $BASEDIR/diffs/latest.osc`
  echo "Downloaded up to timestamp $DATA_VERSION"
  while ! $UPDATE_FROM_DIR --osc-dir=$BASEDIR/diffs --version=$DATA_VERSION $META --flush-size=0; do
    echo "Error while updating. Retry in 1 min."
    sleep 60
  done
  rm $BASEDIR/diffs/latest.osc
  echo "Finished up to $DATA_VERSION."
done

echo "DB up-to-date. Processing areas."

$OSM3S_QUERY --progress --rules <$RULES/areas.osm3s

echo "All updates done."
