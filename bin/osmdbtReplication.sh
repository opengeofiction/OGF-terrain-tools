#!/bin/bash

BASE=/opt/opengeofiction/osmdbt
BIN=${BASE}/bin
CONFIG=${BASE}/etc/osmdbt-config.yaml
LOCKFILE=${BASE}/var/ogf-replication.lock

# ensure we're not already running
if ! mkdir ${LOCKFILE} 2>/dev/null; then
	echo "$0 is already running" >&2
	exit 1
else
	# release lock on clean exit, and if ...
	trap "rm -rf ${LOCKFILE}; exit" INT TERM EXIT
	echo "$0 got lock"
fi

echo "Started: "$(date)
set -e

# 1. Catch up old log files
#  If there are complete log files left over from a crash, they will be in the
#  log_dir directory and named *.log. osmdbt-catchup is called without command
#  line arguments. It finds those left-over log files and tells the PostgreSQL
#  database the largest of the LSNs so that the database can "forget" all
#  changes before that. If there was no crash, no such log files are found and
#  osmdbt-catchup does nothing.
${BIN}/osmdbt-catchup --config ${CONFIG}

# 2. Create log file
#  Now osmdbt-get-log is called which creates a log file in the log_dir named
#  something like osm-repl-2020-03-18T14:18:49Z-lsn-0-1924DE0.log. The file is
#  first created with the suffix .new, synced to disk, then renamed and the
#  directory is synced. If any of these steps fail or if the host crashes, a
#  .new file might be left around, which should be flagged for the sysadmin to
#  take care of. The file can be removed without loosing data, but the
#  circumstances should be reviewed in case there is some systematic problem.
${BIN}/osmdbt-get-log --config ${CONFIG}

# 3. Copy log file to separate host (optional)
#  All files named *.log in the log_dir can now be copied (using scp or rsync
#  or so) to a separate host for safekeeping. These will only be used if the
#  local host crashes and log files on its disk are lost. In this case manual
#  intervention is necessary.

# 4. Catch up database to new log file
#  Now osmdbt-catchup is called to catch up the database to the log file just
#  created in step 2. If the system crashes in step 2, 3, or 4 a log file might
#  be left around without the database being updated. In this case step 1 of
#  the next cycle will pick this up and do the database update.
${BIN}/osmdbt-catchup --config ${CONFIG}

# 5. Creating diff file
#  Now osmdbt-create-diff is called which reads any log files in the log_dir
#  and creates replication diff files. Files are first created in the tmp_dir
#  directory and then moved into place in the changes_dir and its
#  subdirectories. osmdbt-create-diff will also read the state.txt in the
#  changes_dir file and create a new one. See the manual page for
#  osmdbt-create-diff for the details on how this is done exactly.
${BIN}/osmdbt-create-diff --config ${CONFIG} --with-comment

# summary of changes in last hour
echo
echo "Change files created in last 60 minutes:"
cd $(grep changes_dir /opt/opengeofiction/osmdbt/etc/osmdbt-config.yaml | cut -d' ' -f 2)
find . -type f -name '*.gz' -mmin -60 -ls | sort -k 11

# old done logs
echo
echo "Remove done logs, older than 6 hours:"
cd $(grep log_dir /opt/opengeofiction/osmdbt/etc/osmdbt-config.yaml | cut -d' ' -f 2)
find . -type f -name '*log.done' -mmin +360 -ls -delete | sort -k 11

# not done logs
echo
echo "Not processed logs, older than 5 minutes - these should be investigated:"
find . -type f -name '*.log' -mmin +5 -ls | sort -k 11

echo "Finished: "$(date)

