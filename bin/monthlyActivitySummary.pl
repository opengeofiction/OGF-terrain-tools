#! /usr/bin/perl -w

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use File::Copy;
use OGF::Data::Context;
use OGF::Util::File;
use OGF::Util::Usage qw( usageInit usageError );
use POSIX;

use Data::Dumper;
use JSON::PP;

sub build_filename($$$$$$);
sub latlon_to_key($$$$);
sub key_to_latlon($);
sub key_to_name($);
sub classify($);
sub midpoint($$$$);

my ($MAX_LAT, $MIN_LON, $MIN_LAT, $MAX_LON) = (90, -180, -90, 180);
my $FN_ACTIVITY = 'activity';
my $FN_POLYGONS = 'activity-polygons';
my $FN_TEMPLATE = 'activity-template';

# parse arguments
my %opt;
usageInit( \%opt, qq/ h month=s sd=s copyto=s /, << "*" );
[-month <yyyymm>] [-sd <source_directory>] [-copyto <publish_directory>]

-yyyymm   Month to collate, in yyyymm format
-sd       Location to read JSON files and output CSV files
-copyto   Location to publish CSV files for wiki use
*
usageError() if $opt{'h'};
my $MONTH       = $opt{'month'};
my $SOURCE_DIR  = $opt{'sd'}       || '/tmp';
my $PUBLISH_DIR = $opt{'copyto'}   || undef;
my $OVERPASS    = $opt{'overpass'} || 'local';

# validate arguments
usageError() if( !defined $MONTH );
usageError() if( !-d $SOURCE_DIR );
usageError() if( (defined $PUBLISH_DIR) and (!-d $PUBLISH_DIR) );

# open source dir
print "reading: $SOURCE_DIR\n";
my $dh;
unless( opendir $dh, $SOURCE_DIR )
{
	print STDERR "$SOURCE_DIR does not exist, or not readable\n";
	exit 1;
}

# open output file and output header
my $dest = "$SOURCE_DIR/$MONTH.csv";
print "writing to: $dest\n";
my $OUTPUT;
unless( open $OUTPUT, ">$dest" )
{
	print STDERR "Cannot open $dest for writing\n";
	exit 1;
}
print $OUTPUT "date\tkey\ttotal\tclass\tgeom\n";

# parse source JSON
while( my $file = readdir $dh )
{
	if( $file =~ /^activity-($MONTH\d\d)\.json$/ )
	{
		my $date = undef;
		$date = "$1-$2-$3" if( $1 =~ /^(\d{4})(\d{2})(\d{2})$/ );
		next unless( defined $date );
		print "parsing: $file\n";
		
		# load JSON file into a string
		my $json;
		{
			local $/; 
			open my $fh, "<$SOURCE_DIR/$file";
			$json = <$fh>;
			close $fh;
		}

		# decode the JSON
		my $decoded = decode_json $json;
		#print Dumper($decoded);
		foreach my $square ( @$decoded )
		{
			next if( !defined $square->{'key'} );
			my ($latN, $lonW, $latS, $lonE) = key_to_latlon $square->{'key'};
			my $geom = "POLYGON(($lonW $latN, $lonE $latN, $lonE $latS, $lonW $latS, $lonW $latN))";
			print $OUTPUT "$date\t$square->{key}\t$square->{total}\t$square->{class}\t$geom\n";
		}
	}
}

# finish up
close $OUTPUT;

# and copy for web
if( $PUBLISH_DIR )
{
	print "publish to: $PUBLISH_DIR\n";
	copy $dest, $PUBLISH_DIR;
}


##################################################
sub key_to_latlon($)
{
	my($key) = @_;
	
	my($latN, $lonW, $latS, $lonE) = (0, 0, 0, 0);
	if( $key =~ /^(\d{2})([NS])(\d{3})([EW])(\d{2})([NS])(\d{3})([EW])$/ )
	{
		$latN = ($2 eq 'S') ? -$1 : $1 + 0;
		$lonW = ($4 eq 'W') ? -$3 : $3 + 0;
		$latS = ($6 eq 'S') ? -$5 : $5 + 0;
		$lonE = ($8 eq 'W') ? -$7 : $7 + 0;
	}
	($latN, $lonW, $latS, $lonE);
}
