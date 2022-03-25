#!/bin/bash
# load one diff to render v0.4

WORKINGDIR="/opt/geofictician/planet-data/ogieff/ogf-carto/replication-in"

sudo -u luciano mv -f "$WORKINGDIR/expiry.list" "$WORKINGDIR/expiry.list.last"
sudo -u luciano osmosis --read-replication-interval \
  workingDirectory="$WORKINGDIR" \
  --simplify-change --write-xml-change - | \
sudo -u luciano osm2pgsql \
  --database "ogfcartogis" \
  --append --slim --multi-geometry --hstore --input-reader="xml" \
  --expire-tiles=5-19 --expire-output="$WORKINGDIR/expiry.list" \
  --tag-transform-script "/opt/geofictician/map-styles/ogf-carto/openstreetmap-carto.lua" \
  --style "/opt/geofictician/map-styles/ogf-carto/openstreetmap-carto.style" - 2>&1
sudo -u luciano cat "$WORKINGDIR/expiry.list" | sudo -u luciano render_expired --map="ogf-carto" --min-zoom=5 --max-zoom=19 --touch-from=5  2>&1
sudo -u www-data cp -f "$WORKINGDIR/state.txt" "/var/www/html/test.rent-a-planet.com/public_html/ogf-carto-replication-in/"
