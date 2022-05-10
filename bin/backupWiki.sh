#!/usr/bin/bash
# this is an archive copy of  /opt/opengeofiction/bin/backup-wiki.sh on the wiki server

echo "Started: $(date '+%Y%m%d%H%M%S')"
renice -10 $$

SRCDIR=/var/www/html/wiki.opengeofiction.net/public_html
DESTDIR=/opt/opengeofiction/backup-database
BACKUP_QUEUE=/opt/opengeofiction/backup-to-s3-queue
DATEPRE=$(date '+%Y%m%d')
DATESTR=$(date '+%Y%m%d%H%M')

# daily / weekly / monthly / yearly (only the XML uses this)
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

# and do the backups, queue for S3 backup as we go
echo "MediaWiki dir"
tar zcf $DESTDIR/backup-$DATESTR-mediawiki.tar.gz --exclude=cache --exclude=images --exclude=util/extracted .
ln $DESTDIR/backup-$DATESTR-mediawiki.tar.gz ${BACKUP_QUEUE}/daily:wiki:backup-$DATESTR-mediawiki.tar.gz

echo "MediaWiki images dir"
php maintenance/dumpUploads.php | tar zcfT $DESTDIR/backup-$DATESTR-images.tar.gz -
ln $DESTDIR/backup-$DATESTR-images.tar.gz ${BACKUP_QUEUE}/daily:wiki:backup-$DATESTR-images.tar.gz

echo "MediaWiki XML db backup"
php maintenance/dumpBackup.php --full --quiet | gzip > $DESTDIR/backup-$DATESTR-db.xml.gz
ln $DESTDIR/backup-$DATESTR-db.xml.gz ${BACKUP_QUEUE}/${timeframe}:wiki:backup-$DATESTR-db.xml.gz

echo "MediaWiki MySQL db backup"
mysqldump -u ogfwikiguy --password='XXXXXXXXXXXXXXXXXXX' ogf_wikiwiki -c | gzip > $DESTDIR/backup-$DATESTR-db.sql.gz
ln $DESTDIR/backup-$DATESTR-db.sql.gz ${BACKUP_QUEUE}/daily:wiki:backup-$DATESTR-db.sql.gz

echo "Backups:"
ls -lh $DESTDIR

echo "Finished: $(date '+%Y%m%d%H%M%S')"

