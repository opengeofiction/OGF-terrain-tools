#!/bin/bash
# 

rm coastline-new-overpass.*
rm coastline-old-overpass.*

wget --quiet -O coastline-new-overpass.osm "https://overpass.ogf.rent-a-planet.com/api/interpreter?data=[timeout:600];(way["natural"="coastline"];);(._;>;);out;" & wget --quiet -O coastline-old-overpass.osm "https://ogfoverpass.rent-a-planet.com/api/interpreter?data=[timeout:600];(way["natural"="coastline"];);(._;>;);out;" && fg

/opt/opengeofiction/osmcoastline/bin/osmcoastline_filter -o coastline-new-overpass.osm.pbf coastline-new-overpass.osm
/opt/opengeofiction/osmcoastline/bin/osmcoastline_filter -o coastline-old-overpass.osm.pbf coastline-old-overpass.osm

osmium diff -c -s coastline-old-overpass.osm.pbf coastline-new-overpass.osm.pbf

