#!/bin/bash
# load diff to render continuously v0.2

BASE=/opt/opengeofiction/render
SCRIPT=/opt/opengeofiction/OGF-terrain-tools/bin/diffToRender.sh
MINLOOP=30

# check argument
if [ $# -ne 1 ]; then
	cat <<USAGE
Usage:
	$0 style
USAGE
	exit 1
fi
STYLE=$1

echo "Started: "$(date)

# ensure we're not already running
LOCKFILE=${BASE}/var/${STYLE}.lock
if ! mkdir ${LOCKFILE} 2>/dev/null; then
	echo "$0 is already running" >&2
	exit 1
else
	# release lock on clean exit, and if ...
	trap "rm -rf ${LOCKFILE}; exit" INT TERM EXIT
	echo "$0 got lock"
fi

# setup working dir
DIR=${BASE}/$STYLE
mkdir -p ${DIR}
LOG=${DIR}/log
mkdir -p ${LOG}

while true; do
	# note start time of the loop
	started=$(date)
	#echo "Starting: $started"
	start_time=$SECONDS
	
	# build up log filename
	log="$LOG/diff-to-render-$(date +%Y%m%d).log"
	
	# call the replication & render script
	echo "==> step started $started" >> $log
	$SCRIPT $STYLE >> $log 2>&1
	echo "==> step completed $(date)" >> $log
	
	# do we need to sleep a little?
	end_time=$SECONDS
	elapsed=$((end_time - start_time))
	if [ $elapsed -lt $MINLOOP ]; then
		sleep_for=$((MINLOOP - elapsed))
		echo "==> step started $started; completed $(date); wait for $sleep_for secs"
		sleep $sleep_for
	else
		echo "==> step started $started; completed $(date)"
	fi
done

exit;

#LOG_DIR="/opt/geofictician/planet-data/ogieff/ogf-carto/replication-in"
#SLEEPTIME=60
#sudo rm -f "/opt/geofictician/planet-data/ogieff/ogf-carto/replication-in/diff-to-render-continuous.log"
#sudo -u luciano touch "/opt/geofictician/planet-data/ogieff/ogf-carto/replication-in/diff-to-render-continuous.log"
#while true
#do
#  STARTTIMESTAMP=`date "+%Y%m%d%H%M%S%Z"`
#  /opt/geofictician/planet-data/ogieff/ogf-carto/replication-in/diff-to-render.sh 2>&1 \
#    >>"$LOG_DIR/diff-to-render-continuous.log"
#  sleep $SLEEPTIME
#  ENDTIMESTAMP=`date "+%Y%m%d%H%M%S%Z"`
#  echo "=================> diff-to-render-step started $STARTTIMESTAMP , completed $ENDTIMESTAMP" 2>&1 \
#    >>"$LOG_DIR/diff-to-render-continuous.log"
#done
##################################################
