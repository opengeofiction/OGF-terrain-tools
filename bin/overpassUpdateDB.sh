#!/bin/bash

BASEDIR=/opt/opengeofiction/overpass
DBDIR=$BASEDIR/db
REPLICATION_URL=https://data.opengeofiction.net/replication/minute

OVERPASS_INSTALL=/opt/overpass
UPDATE_FROM_DIR=$OVERPASS_INSTALL/bin/update_from_dir

PYOSMIUM="pyosmium-get-changes --server $REPLICATION_URL --diff-type osc.gz -f $DBDIR/replicate-id"
PYOSMIUM="$PYOSMIUM --no-deduplicate"

#META=--meta
META=--keep-attic
#META=

status=3 # make it sleep on issues

if [ -f $DBDIR/replicate-id ]; then
  # first apply any pending updates
  if [ -f $BASEDIR/diffs/latest.osc ]; then
    DATA_VERSION=`osmium fileinfo -e -g data.timestamp.last $BASEDIR/diffs/latest.osc`
    if [ "x$DATA_VERSION" != "x" ]; then
      echo "Downloaded up to timestamp $DATA_VERSION"
      while ! $UPDATE_FROM_DIR --osc-dir=$BASEDIR/diffs --version=$DATA_VERSION $META --flush-size=0; do
        echo "Error while updating. Retry in 1 min."
        sleep 60
      done
    fi
    rm $BASEDIR/diffs/latest.osc
  fi

  $PYOSMIUM -v -s 1000 -o $BASEDIR/diffs/latest.osc
  status=$?
fi

if [ $status -eq 0 ]; then
  echo "Downloaded next batch."
elif [ $status -eq 3 ]; then
  rm $BASEDIR/diffs/latest.osc
  echo "No new data, sleeping for a minute."
  sleep 60
else
  echo "Fatal error, stopping updates."
  exit $status
fi
