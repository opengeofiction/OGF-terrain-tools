#!/usr/bin/bash

echo "Started: $(date '+%Y%m%d%H%M%S')"
renice -10 $$

SRCDIR=/var/www/html/wiki.opengeofiction.net/public_html
DESTDIR=/opt/opengeofiction/backup-database
BACKUP_QUEUE=/opt/opengeofiction/backup-to-s3-queue
DB=ogf_wikiwiki
DATEPRE=$(date '+%Y%m%d')
DATESTR=$(date '+%Y%m%d%H%M')

# daily / weekly / monthly / yearly 
lastthu=$(ncal -h | awk '/Th/ {print $NF}')
today=$(date +%-d)
timeframe=daily
if [[ $(date +%u) -eq 4 ]]; then
	timeframe=weekly
	if [[ $lastthu -eq $today ]]; then
		timeframe=monthly
		if [[ $(date +%-m) -eq 12 ]]; then
			timeframe=yearly
		fi
	fi
fi

# clean up
echo "Cleaning up"
mkdir -p $DESTDIR
cd $DESTDIR
find $DESTDIR -mindepth 1 -mtime +4 -delete -print
find $DESTDIR -name "backup-$DATEPRE*" -delete -print

cd $SRCDIR

# and do the XML backup, queue for S3 backup
echo "MediaWiki XML db backup"
php maintenance/dumpBackup.php --current --quiet | gzip > $DESTDIR/backup-$DATESTR-db.xml.gz
ln $DESTDIR/backup-$DATESTR-db.xml.gz ${BACKUP_QUEUE}/${timeframe}:wiki:backup-$DATESTR-db.xml.gz

# and do the ancillary backups
if [ ${timeframe} != "daily" ]; then
	echo "MediaWiki dir"
	tar zcf $DESTDIR/backup-$DATESTR-mediawiki.tar.gz --exclude=cache --exclude=images --exclude=util/extracted .

	echo "MediaWiki images dir"
	php maintenance/dumpUploads.php | tar zcfT $DESTDIR/backup-$DATESTR-images.tar.gz -

	echo "MediaWiki MySQL db backup"
	mysqldump $DB -c | gzip > $DESTDIR/backup-$DATESTR-db.sql.gz
	
	# collate and queue for S3 backup
	echo "Collate MediaWiki dir, MediaWiki images dir and MediaWiki MySQL db backup"
	tar zcf $DESTDIR/backup-$DATESTR-ancillary.tar.gz $DESTDIR/backup-$DATESTR-mediawiki.tar.gz $DESTDIR/backup-$DATESTR-images.tar.gz $DESTDIR/backup-$DATESTR-db.sql.gz
	rm $DESTDIR/backup-$DATESTR-mediawiki.tar.gz $DESTDIR/backup-$DATESTR-images.tar.gz $DESTDIR/backup-$DATESTR-db.sql.gz
	ln $DESTDIR/backup-$DATESTR-ancillary.tar.gz ${BACKUP_QUEUE}/${timeframe}:wiki:backup-$DATESTR-ancillary.tar.gz
fi

echo "Backups:"
ls -lh $DESTDIR

echo "Finished: $(date '+%Y%m%d%H%M%S')"

