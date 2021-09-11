#! /usr/bin/perl -w -CSDA
# Copy a file to another host using scp, but only if it is not currently being updated

use lib '/opt/opengeofiction/OGF-terrain-tools';
use strict;
use warnings;
use File::Basename;
use POSIX 'strftime';
use OGF::Util::Usage qw( usageInit usageError );

my $TOO_NEW = 60; # seconds
my $TMP_DIR = '/tmp/scpFileIfNotUpdating';
my $START   = strftime '%Y%m%d%H%M%S', gmtime;

my %opt;
usageInit( \%opt, qq/ h file=s dest=s timestamp/, << "*" );
[-file <filename> -dest <spec> -timestamp]

-file      file to copy
-dest      destination host and directory
-timestamp add yyyymmddhhmmss timestamp to filename on copy
*
my $SRC_FILE = $opt{'file'};
my $DST_SPEC = $opt{'dest'};
my $TSTAMP   = (defined $opt{'timestamp'}) ? "-$START" : '';
usageError() if( $opt{'h'} or !defined $SRC_FILE or !defined $DST_SPEC );

print "Starting: $START\n";
unless( -r $SRC_FILE )
{
	print STDERR "$SRC_FILE does not exist, or not readable\n";
	exit 1;
}

# is the file still being created?
my (undef,undef,undef,undef,undef,undef,undef,$size,undef,$mtime) = stat $SRC_FILE;
my $modified = time - $mtime;
my $decision = (time - $mtime) <= $TOO_NEW ? 'skip' : 'copy';
print "$SRC_FILE last modified $modified seconds ago: $decision\n";
exit 1 unless( $decision eq 'copy' );

# copy file to temp location so the scp doesn't break any other script which attempts to write file
# but use cksum checking, so we avoid copying a file which has recently been copied anyway
mkdir $TMP_DIR unless( -d $TMP_DIR );
my $tmp_file = $TMP_DIR . '/' . basename($SRC_FILE);
my $cksum = `cat "$SRC_FILE" | cksum`; # we cat to avoid filename in the file
my $saved_cksum = undef;
$saved_cksum = `cat "$tmp_file.cksum"` if( -f "$tmp_file.cksum" );
unless( (!defined $saved_cksum) or ($saved_cksum ne $cksum) )
{
	print STDERR "Same $SRC_FILE has already been copied recently\n";
	exit 1;
}
system "cp \"$SRC_FILE\" \"$tmp_file\"";
system "cat \"$tmp_file\" | cksum > \"$tmp_file.cksum\"";

# build up destination path for scp
my($filename, undef, $suffix) = fileparse $tmp_file, qr/\..+/;
my $username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
my $dest = "$username\@$DST_SPEC/$filename$TSTAMP$suffix";

print "Copying...\nscp -B $tmp_file $dest\n";
system "scp -B $tmp_file $dest";
