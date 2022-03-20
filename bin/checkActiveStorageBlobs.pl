#! /usr/bin/perl -w -CSDA
# Correct issue with active_storage files which do not exist on disk

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use DBI;
use OGF::Util::Usage qw( usageInit usageError );

# parse commandline options
my %opt;
usageInit( \%opt, qq/ h host=s user=s db=s password=s storage=s/, << "*" );
-host <hostname> -user <username> -db <database> -password <password> -storage <storage path>

-host     database hostname, defaults to localhost
-user     database username
-db       database
-password database password
-storage  openstreetmap rails storage dir
*
my $DB_HOST  = (defined $opt{host}) ? $opt{host} : 'localhost';
my $DB_USER  = $opt{user};
my $DB       = $opt{db};
my $DB_PASS  = $opt{password};
my $STORAGE  = (defined $opt{storage}) ? $opt{storage} : '/var/www/html/opengeofiction.net/storage';
usageError() if( $opt{h} or !defined $DB_USER or !defined $DB or !defined $DB_PASS );

# connect to database
my $dbh = DBI->connect("dbi:Pg:dbname=$DB;host=$DB_HOST", $DB_USER, $DB_PASS, {AutoCommit => 0, RaiseError => 1, PrintError => 1});

# loop round once to output names - only avatars
my $sql = <<'SQL';
SELECT asa.id AS id, u.id AS user_id, u.display_name, asb.key, asa.created_at FROM active_storage_blobs asb, active_storage_attachments asa, users u WHERE asa.name='avatar' AND asa.record_type = 'User' AND asa.record_id = u.id AND asa.blob_id = asb.id ORDER BY asa.id;
SQL
my $sth = $dbh->prepare($sql);
$sth->execute();
while( my $row = $sth->fetchrow_hashref('NAME_lc') )
{
	if( $row->{key} =~ /^(..)(..)(........................)$/ )
	{
		my($dir1, $dir2, $dir) = ($1, $2, $1 . $2 . $3);
		my $file = "$STORAGE/$dir1/$dir2/$dir";
		unless( -f $file )
		{
			print "$row->{id}: Avatar file does not exist for $row->{user_id}:$row->{display_name}, created at $row->{created_at}\n";
		}
	}
}
$sth->finish();

# this time note the blob_id
my %delete = ();
$sql = <<'SQL';
SELECT asa.id AS id, asa.blob_id, asb.key, asa.created_at FROM active_storage_blobs asb, active_storage_attachments asa WHERE asa.blob_id = asb.id;
SQL
$sth = $dbh->prepare($sql);
$sth->execute();
while( my $row = $sth->fetchrow_hashref('NAME_lc') )
{
	if( $row->{key} =~ /^(..)(..)(........................)$/ )
	{
		my($dir1, $dir2, $dir) = ($1, $2, $1 . $2 . $3);
		my $file = "$STORAGE/$dir1/$dir2/$dir";
		$delete{$row->{blob_id}} = 1 unless( -f $file );
	}
}
$sth->finish();

# and delete the stale rows
foreach my $key ( sort { $a <=> $b } keys %delete )
{
	$sql = "DELETE FROM active_storage_variant_records WHERE blob_id = $key;";
	print "$sql\n";
	$dbh->do($sql);
	$sql = "DELETE FROM active_storage_attachments WHERE blob_id = $key;";
	print "$sql\n";
	$dbh->do($sql);
	$sql = "DELETE FROM active_storage_blobs WHERE id = $key;";
	print "$sql\n";
	$dbh->do($sql);
}

# get out of here
$dbh->commit;
$dbh->disconnect();
