#! /usr/bin/perl -w -CSDA
# 

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use POSIX;
use OGF::Util::Usage qw( usageInit usageError );

# parse commandline options
my %opt;
usageInit( \%opt, qq/ h host=s user=s db=s password=s od=s/, << "*" );
-host <hostname> -user <username> -db <database> -password <password> -od <output_directory>

-host     database hostname, defaults to localhost
-user     database username
-db       database
-password database password
-od       output directory
*
my $DB_HOST    = $opt{'host'} || 'localhost';
my $DB_USER    = $opt{'user'};
my $DB         = $opt{'db'};
my $DB_PASS    = $opt{'password'};
my $OUTPUT_DIR = $opt{'od'} || '/tmp';
usageError() if( $opt{'h'} or !defined $DB_USER or !defined $DB or !defined $DB_PASS );

# we want to get all changesets within a "UNIX week", offset slightly from current time
my $HOUR = 3600;
my $WEEK = 604800;
my $nowish = time - $HOUR; # 1 hour ago
my $from = floor($nowish / $WEEK) * $WEEK;
my $to = ceil($nowish / $WEEK) * $WEEK;

# name the output based on the start time
my $output = strftime 'changesets-%Y%m%d-%H%M%S', gmtime $from;
$output = "$OUTPUT_DIR/$output.txt";

# build up SQL query
my $sql = "SELECT changeset_id, created_at, num_changes, user_id, display_name, user_creation_ip, user_creation_time, user_languages, user_emails, changeset_counts, changesest_ip, changeset_user_agent FROM changesets_with_ip WHERE created_at >= to_timestamp($from) AT TIME ZONE 'UTC' AND created_at < to_timestamp($to) AT TIME ZONE 'UTC' ORDER BY created_at;";

# debug
print "db: postgresql://$DB_USER\@$DB_HOST/$DB\n";
print "selecting user changesets between: $from and $to\n";
print "output to $output\n";
print "sql query: $sql\n";

# and user psql to write out the file - just becasue it was done like this in the past, keep file format same
system "PGPASSWORD='$DB_PASS' psql -h $DB_HOST -U $DB_USER -d $DB --no-align --tuples-only --output $output -c \"$sql\"";

# data retention policy - remove all IP addresses older than 90 days
my $NINETY_DAYS = 7776000;
if( opendir my $dh, $OUTPUT_DIR )
{
	while( my $file = readdir $dh )
	{
		if( $file =~ /^changesets-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})\.txt$/ )
		{
			my $t = mktime $6, $5, $4, $3, $2 - 1, $1 - 1900;
			$t += $WEEK; # base on the newest entry within the file
			if( time - $t > $NINETY_DAYS )
			{
				print "FILE $file - DELETE\n";
				unlink "$OUTPUT_DIR/$file";
			}
			else
			{
				print "FILE $file - keep\n";
			}
		}
	}
	closedir $dh;
}