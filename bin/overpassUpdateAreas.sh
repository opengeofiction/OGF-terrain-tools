#!/bin/bash

BASEDIR=/opt/opengeofiction/overpass
DBDIR=$BASEDIR/db
RULES=$DBDIR/rules

OVERPASS_INSTALL=/opt/overpass
OVERPASS_RULES=$OVERPASS_INSTALL/rules
OSM3S_QUERY=$OVERPASS_INSTALL/bin/osm3s_query

echo "`date '+%F %T'`: update started"

if [[ -a $DBDIR/area_version ]]; then
  sed "s/{{area_version}}/$(cat $DBDIR/area_version)/g" $RULES/areas_delta.osm3s | $OSM3S_QUERY --progress --rules
else
  cat $RULES/areas.osm3s | $OSM3S_QUERY --progress --rules
fi

echo "`date '+%F %T'`: update finished"
