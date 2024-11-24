#!/bin/bash
# 

rm coastline-new-overpass.*
rm coastline-old-overpass.*

echo get new
time wget --quiet -O coastline-new-overpass.osm "https://overpass.opengeofiction.net/api/interpreter?data=[timeout:600];(way["natural"="coastline"];);(._;>;);out;"
echo get old
time wget --quiet -O coastline-old-overpass.osm "https://overpass.ogf.rent-a-planet.com/api/interpreter?data=[timeout:600];(way["natural"="coastline"];);(._;>;);out;"

echo filter new
/opt/opengeofiction/osmcoastline/bin/osmcoastline_filter -o coastline-new-overpass.osm.pbf coastline-new-overpass.osm
echo filter old
/opt/opengeofiction/osmcoastline/bin/osmcoastline_filter -o coastline-old-overpass.osm.pbf coastline-old-overpass.osm

osmium diff -c -s coastline-old-overpass.osm.pbf coastline-new-overpass.osm.pbf

