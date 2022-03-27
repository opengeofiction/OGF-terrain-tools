#!/bin/bash
# 
# This is derived, closely, from https://github.com/openstreetmap/chef/blob/master/cookbooks/tile/templates/default/replicate.erb
# 
# Before running updates, the replication needs to be set up with the sequence
# pyosmium-get-changes -I can be used to do this
#
# tileReplicate.sh ogf-carto https://ogfdata.rent-a-planet.com/replication/minute ogfcartogis /opt/geofictician/map-styles/ogf-carto/openstreetmap-carto.style /opt/geofictician/map-styles/ogf-carto/openstreetmap-carto.lua /var/www/html/test.rent-a-planet.com/public_html/ogf-carto-replication-in/state.txt

BASE=/opt/opengeofiction/render

# parse arguments
if [ $# -ne 6 ]; then
	cat <<USAGE
Usage:
	$0 style-name server db style-script transform-script copy-sequence-to
USAGE
	exit 1
fi
STYLE=$1
SERVER=$2
DB=$3
STYLE_SCRIPT=$4
TRANSFORM_SCRIPT=$5
COPY_SEQUENCE_TO=$6

# setup working dir
DIR=${BASE}/${STYLE}
LOG=${BASE}/${STYLE}/log
mkdir -p ${LOG}
cd ${DIR}

# make sure expire-queue dir is 777 so non-root user can unlink files in it
mkdir expire-queue
chmod a+rwx expire-queue

# Define exit handler
function onexit {
	[ -f sequence-prev.txt ] && mv sequence-prev.txt sequence.txt
}

# Send output to the log
exec >> ${LOG}/replicate.log 2>&1

# Change to the replication state directory
cd $DIR

# Install exit handler
trap onexit EXIT

# Loop indefinitely
while true
do
	echo "Loop: "$(date)
	
	# Work out the name of the next file
	file="changes-$(cat sequence.txt).osc.gz"
	efile="expiry-$(cat sequence.txt).list"
	rm -f ${file} 2> /dev/null
	rm -f ${efile} 2> /dev/null

	# Save sequence file so we can rollback if an error occurs
	cp sequence.txt sequence-prev.txt

	# Fetch the next set of changes
	pyosmium-get-changes --server=${SERVER} --sequence-file=sequence.txt --outfile=${file}

	# Save exit status
	status=$?

	# Check for errors
	if [ $status -eq 0 ]
	then
		# Enable exit on error
		set -e

		# Log the new data
		echo "Fetched new data from $(cat sequence-prev.txt) to $(cat sequence.txt) into ${file}"

		# Apply the changes to the database
		# (removed --flat-nodes and added --expire-tiles, --expire-output)
		osm2pgsql --database ${DB} --slim --append --number-processes=1 \
		          --expire-tiles=5-19 --expire-output=${efile} \
		          --multi-geometry \
		          --hstore \
		          --style=${STYLE_SCRIPT} \
		          --tag-transform-script=${TRANSFORM_SCRIPT} \
		          ${file}

		# No need to rollback now
		rm sequence-prev.txt

		# Get buffer count
		buffers=$(osmium fileinfo --extended --get=data.buffers.count ${file})

		# If this diff has content mark it as the latest diff
		if [ $buffers -gt 0 ]
		then
			ln -f ${file} changes-latest.osc.gz
			
			echo $(date) > ${COPY_SEQUENCE_TO}
			cat sequence.txt >> ${COPY_SEQUENCE_TO}
		fi
		
		# Queue these changes for expiry processing - note this is *not* the osc.gz as done with OSM,
		# we are still using the expiry list from osm2pgsql
		ln ${efile} expire-queue/${efile}

		# Delete old downloads & expiry lists
		find . -name 'changes-*.gz' -mmin +300 -exec rm -f {} \;
		find . -name 'expiry-*.list' -mmin +300 -exec rm -f {} \;

		# Disable exit on error
		set +e
	elif [ $status -eq 3 ]
	then
		# Log the lack of data
		echo "No new data available. Sleeping..."

		# Remove file, it will just be an empty changeset
		rm ${file}

		# Sleep for a short while
		sleep 30
	else
		# Log our failure to fetch changes
		echo "Failed to fetch changes - waiting a few minutes before retry"

		# Remove any output that was produced
		rm -f ${file}
		rm -f ${efile}

		# Wait five minutes and have another go
		sleep 300
	fi
done
