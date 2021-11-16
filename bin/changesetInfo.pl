#! /usr/bin/perl -w -CSDA
# 

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use DBI;
use OGF::Util::Usage qw( usageInit usageError );

my $LOG_DIR = '/var/www/html/opengeofiction.net/log';
my $ACCESS_LOG = 'access.log';
my $ROTATES = 4;
my $min_changeset_id = 0;

# parse commandline options
my %opt;
usageInit( \%opt, qq/ h host=s user=s db=s password=s/, << "*" );
-host <hostname> -user <username> -db <database> -password <password>

-host     database hostname, defaults to localhost
-user     database username
-db       database
-password database password
*
my $DB_HOST  = (defined $opt{'host'}) ? $opt{'host'} : 'localhost';
my $DB_USER  = $opt{'user'};
my $DB       = $opt{'db'};
my $DB_PASS  = $opt{'password'};
usageError() if( $opt{'h'} or !defined $DB_USER or !defined $DB or !defined $DB_PASS );

# connect to database
my $dbh = DBI->connect("dbi:Pg:dbname=$DB;host=$DB_HOST", $DB_USER, $DB_PASS, {AutoCommit => 0, RaiseError => 1, PrintError => 1});

# create the changeset_ip table if needed and get the latest changeset ID
my $sql = <<'SQL';
CREATE TABLE IF NOT EXISTS changeset_ip(
  changeset_id bigint            NOT NULL,
  user_ip      inet              NOT NULL,
  user_agent   character varying,
  PRIMARY KEY(changeset_id, user_agent),
  FOREIGN KEY(changeset_id) REFERENCES changesets(id)
);
SQL
$dbh->do($sql);
my $id = $dbh->selectrow_array('SELECT max(changeset_id) FROM changeset_ip');
$min_changeset_id = $id if( defined $id );
print "Max changeset IP: $id\n" if( defined $id );

# create the changesets_with_ip view
my $sql = <<'SQL';
CREATE OR REPLACE VIEW changesets_with_ip AS
  SELECT c.id AS changeset_id, c.created_at AS created_at, c.num_changes AS num_changes, c.user_id AS user_id, u.display_name AS display_name, u.creation_ip::inet AS user_creation_ip, u.creation_time AS user_creation_time, u.languages AS user_languages, CONCAT_WS(',', u.email, NULLIF(u.new_email, '')) AS user_emails, u.changesets_count AS changeset_counts, ip.user_ip AS changesest_ip, ip.user_agent AS changeset_user_agent
  FROM changesets c, users u, changeset_ip ip
  WHERE c.user_id = u.id AND c.id = ip.changeset_id;
SQL
$dbh->do($sql);

# prepare insert
$sql = 'INSERT INTO changeset_ip(changeset_id, user_ip, user_agent) VALUES(?, ?, ?) ON CONFLICT DO NOTHING';
my $sth = $dbh->prepare($sql);

# loop over the access logs, oldest first
for( my $log = $ROTATES; $log >= 0; $log-- )
{
	# the latest log is uncompressed, the others have been rotated and compressed
	my $logfile = $LOG_DIR . '/' . $ACCESS_LOG . '.' . $log . '.gz';
	$logfile = $LOG_DIR . '/' . $ACCESS_LOG if( $log == 0 );
	if( ! -e $logfile )
	{
		print "$logfile does not exist\n";
		next;
	}
	my $cat = ($log == 0) ? '/bin/cat ' : '/bin/zcat';
	
	# open the log, pipe it in to decompress
	print STDERR "LOG: $cat $logfile\n";
	open IN, "$cat $logfile |" or die "$cat $logfile: $!";
	while( <IN> )
	{
		# chomp & condense one or more whitespace character to one single space
		chomp; s/\s+/ /go;

		#  break each apache access_log record into nine variables
		my($ip, undef, undef, undef, $http_request, undef, undef, undef, $user_agent) = /^(\S+) (\S+) (\S+) \[(.+)\] \"(.+)\" (\S+) (\S+) \"(.*)\" \"(.*)\"/o;
		if( $http_request =~ /^PUT \/api\/0\.6\/changeset\/(\d+)\/close/ )
		{
			my $changeset_id = $1;
			if( $changeset_id > $min_changeset_id )
			{
				print "$changeset_id | $ip | $user_agent\n";
				$sth->execute($changeset_id, $ip, $user_agent);
			}
		}
	}
	close IN;
}

# get out of here
$dbh->commit;
$dbh->disconnect();