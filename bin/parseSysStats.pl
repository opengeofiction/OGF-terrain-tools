#! /usr/bin/perl -w -CSDA
# Parse top output to CSV

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use POSIX 'strftime';
use OGF::Util::Usage qw( usageInit usageError );

my %opt;
usageInit( \%opt, qq/ h dir=s dest=s /, << "*" );
[-dir <directory> -dest <filename> ]

-dir     source directory
-dest    destination file
*
my $SRC_DIR  = $opt{'dir'} || '/opt/opengeofiction/sys-stats';
my $DST_FILE = $opt{'dest'};
usageError() if( $opt{'h'} or !defined $SRC_DIR or !-d $SRC_DIR or !defined $DST_FILE );

# open temp file and output header
my $temp_dest = "$DST_FILE.tmp";
print "Writing to: $temp_dest\n";
my $OUTPUT;
unless( open $OUTPUT, '>', $temp_dest )
{
	print STDERR "Cannot open $temp_dest for writing\n";
	exit 1;
}
print $OUTPUT "datetime, load1, load15, mem, memfree, memused, memcached, swap, swapfree, swapused, memavail\n";

# read in top data
print "reading: $SRC_DIR\n";
my $dh;
unless( (-d $SRC_DIR) and (opendir $dh, $SRC_DIR) )
{
	print STDERR "$SRC_DIR does not exist, or not readable\n";
	exit 1;
}
while( my $file = readdir $dh )
{
	if( $file =~ /^(\d{4})(\d{2})(\d{2})\.txt$/ )
	{
		my $date = "$1-$2-$3";
		print "parsing: $file $date\n";
		if( open my $F, "<$SRC_DIR/$file" )
		{
			my $lasttime = undef;
			my $time = undef;
			my ($load1, $load15);
			my($mem, $memfree, $memused, $memcached);
			while( <$F> )
			{
				$time = "$1:$2:00" if( /top - (\d{2}):(\d{2}):(\d{2})/ );
				($load1, $load15) = ($1, $3) if( /load average: (\d+.\d+), (\d+.\d+), (\d+.\d+)/ );
				($mem, $memfree, $memused, $memcached) = ($1, $2, $3, $4) if( /MiB Mem :\s+(\d+.\d+) total,\s+(\d+.\d+) free,\s+(\d+.\d+) used,\s+(\d+.\d+) buff\/cache/ );
				if( /^MiB Swap:\s+(\d+.\d+) total,\s+(\d+.\d+) free,\s+(\d+.\d+) used.\s+(\d+.\d+) avail Mem/ )
				{
					next if( defined $lasttime and $time eq $lasttime );
					my($swap, $swapfree, $swapused, $memavail) = ($1, $2, $3, $4);
					
					# output CSV
					print $OUTPUT "$date $time, $load1, $load15, $mem, $memfree, $memused, $memcached, $swap, $swapfree, $swapused, $memavail\n";
					$lasttime = $time;
				}
			}
			close $F;
		}
	}
}
closedir $dh;

# finish up and move file
close $OUTPUT;
print "Moving $temp_dest to $DST_FILE\n";
system "perl -e 'print scalar <>, sort <>;' < $temp_dest > $DST_FILE"; # sort it too
system "rm $temp_dest";
