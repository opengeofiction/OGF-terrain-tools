#! /usr/bin/perl -w

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use File::Copy;
use OGF::Data::Context;
use OGF::Util::File;
use OGF::Util::Overpass;
use OGF::Util::Usage qw( usageInit usageError );
use POSIX;

sub fileExport_Overpass($$);
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
usageInit( \%opt, qq/ h degincr=s od=s copyto=s overpass=s /, << "*" );
[-degincr <degrees>] [-od <output_directory>] [-copyto <publish_directory>] [-overpass <local|remote>]

-degincr  Summarise per x degree squares, default 15
-od       Location to output CSV files
-copyto   Location to publish JSON files for wiki use
-overpass local or remote overpass instance, default local
*
usageError() if $opt{'h'};
my $DEGINCR     = $opt{'degincr'}  || 15;
my $OUTPUT_DIR  = $opt{'od'}       || '/tmp';
my $PUBLISH_DIR = $opt{'copyto'}   || undef;
my $OVERPASS    = $opt{'overpass'} || 'local';

# validate arguments
usageError() if( ($DEGINCR < 1) or ($DEGINCR > 180) or (180 % $DEGINCR != 0) or ($DEGINCR % 1 != 0) );
usageError() if( !-d $OUTPUT_DIR );
usageError() if( (defined $PUBLISH_DIR) and (!-d $PUBLISH_DIR) );
usageError() if( ($OVERPASS ne 'local') and ($OVERPASS ne 'remote') and ($OVERPASS ne 'nop') );

# calculate time base
my $DAY = 86400;
my $yesterday = floor((time - $DAY) / $DAY) * $DAY;
my $yesterday_fmt = strftime '%Y-%m-%dT%H:%M:%SZ', gmtime $yesterday;
print "Changes in $DEGINCR degree squares since $yesterday_fmt\n";

# build up overpass query strings, working around 1MB max - break into chunks
my $QUERY_START = "[out:csv(name, total; true; \",\")][timeout:1800][maxsize:4294967296];\n";
my $MAXITEMS = 8200;
my @query;
for( my $items = 0, my $q = 0, my $lat = $MAX_LAT; $lat > $MIN_LAT; $lat -= $DEGINCR )
{
	for( my $lon = $MIN_LON; $lon < $MAX_LON; $lon += $DEGINCR )
	{
		my $latN = $lat;
		my $latS = $lat - $DEGINCR;
		my $lonW = $lon;
		my $lonE = $lon + $DEGINCR;
		
		my $key = latlon_to_key $latN, $lonW, $latS, $lonE;

		$query[$q] = $QUERY_START if( !defined $query[$q] );
		$query[$q] .= << "EOF";
nw($latS,$lonW,$latN,$lonE)(newer:"$yesterday_fmt");make count name="$key",total=count(nodes)+count(ways);out;
EOF
		if( ++$items > $MAXITEMS )
		{
			$q++;
			$items = 0;
		}
	}
}

# execute overpass queries
my $i = 0;
foreach my $querystr( @query )
{
	print "overpass query iteration: $i\n";
	
	my $fn = build_filename $OUTPUT_DIR, $FN_ACTIVITY, $yesterday, "$DEGINCR°", $i++, 'csv';
	if( -e $fn )
	{
		print "cached: $fn - will not query\n";
	}
	else
	{
		print "export to: $fn\n";
		fileExport_Overpass $fn, $querystr;
	}
}

# read in query output
my %squares = ();
for( my $ii = 0; $ii <= $i; $ii++ )
{
	my $fn = build_filename $OUTPUT_DIR, $FN_ACTIVITY, $yesterday, "$DEGINCR°", $ii, 'csv';
	if( open F, "<$fn" )
	{
		while( my $line = <F> )
		{
			next if( $line =~ /^name/ );
			my($key, $count) = split /,/, $line;
			$squares{$key} = $count+0 if( $count > 0 );
		}
		close F;
	}
}

# create polygon JSON
my $polygon_fn = build_filename $OUTPUT_DIR, $FN_POLYGONS, $yesterday, undef, undef, 'json';
my $first = 0;
if( open F, ">$polygon_fn" )
{
	print F "{\n";
	foreach my $key( keys %squares )
	{
		my($latN, $lonW, $latS, $lonE) = key_to_latlon $key;
		print F ",\n" unless( $first++ == 0 );
		print F "\"$key\": [[$latN, $lonW], [$latN, $lonE], [$latS, $lonE], [$latS, $lonW]]";
	}
	print F "\n}\n";
	close F;
}

# create activity JSON
my $activity_fn = build_filename $OUTPUT_DIR, $FN_ACTIVITY, $yesterday, undef, undef, 'json';
$first = 0;
if( open F, ">$activity_fn" )
{
	print F "[\n";
	foreach my $key( keys %squares )
	{
		my($latN, $lonW, $latS, $lonE) = key_to_latlon $key;
		my $name = key_to_name $key;
		my $class = classify $squares{$key};
		my $midpoint = midpoint $latN, $lonW, $latS, $lonE;
		print F ",\n" unless( $first++ == 0 );
		print F qq/\t{\n\t\t"key": "$key",\n\t\t"name": "$name",\n\t\t"total": "$squares{$key}",\n\t\t"class": "$class",\n\t\t"midpoint": "$midpoint"\n\t}/;
	}
	print F "\n]\n";
	close F;
}

# create template JSON
my $template_fn = build_filename $OUTPUT_DIR, $FN_TEMPLATE, undef, undef, undef, 'json';
if( open F, ">$template_fn" )
{
	print F "{\n";
	# https://gka.github.io/palettes/#/11|s|ffff00,ffa500,ff0000,303030|ffffe0,ff005e,93003a|0|0
	my @colours = ('#ffff00', '#ffe400', '#ffc900', '#ffae00', '#ff8400', '#ff5200', '#ff2100', '#ea0505', '#ac1313', '#6e2222', '#303030');
	for( my $class = 0; $class <= 10; $class++ )
	{
		my $colour = $colours[$class];
		my $opacity = 1;
		my $fillopacity = ($class <= 3) ? 0.4 : 0.8;
		my $weight = ($class <= 3) ? 0 : 1;
		print F <<"EOF";
    "$class": {
		"color": "$colour",
		"opacity": $opacity,
		"fillColor": "$colour",
		"fillOpacity": $fillopacity,
		"weight": $weight,
		"text": ["Degree square: %name%<br/>",
		         "Node and/or way edits: <b>%total%</b><br/>",
		         "<a href=\\"%API_URL%history#map=11/%midpoint%\\">Changesets</a>"]
    },
EOF
	}
	print F <<"EOF";
    "x": {}
}
EOF
	close F;
}

# and copy for web
if( $PUBLISH_DIR )
{
	print "publish $polygon_fn to $PUBLISH_DIR...\n";
	copy $polygon_fn, $PUBLISH_DIR;
	my $polygon_fn_latest = build_filename $PUBLISH_DIR, $FN_POLYGONS, undef, undef, undef, 'json';
	print "publish $polygon_fn to $polygon_fn_latest...\n";
	copy $polygon_fn, $polygon_fn_latest;
	
	print "publish $activity_fn to $PUBLISH_DIR...\n";
	copy $activity_fn, $PUBLISH_DIR;
	my $activity_fn_latest = build_filename $PUBLISH_DIR, $FN_ACTIVITY, undef, undef, undef, 'json';
	print "publish $activity_fn to $activity_fn_latest...\n";
	copy $activity_fn, $activity_fn_latest;
	
	print "publish $template_fn to $PUBLISH_DIR...\n";
	copy $template_fn, $PUBLISH_DIR;
}
	
exit;

##################################################
sub fileExport_Overpass($$)
{
	my($outFile, $query) = @_;
	
	if( $OVERPASS eq 'local' )
	{
		my $data = OGF::Util::Overpass::runQuery_local( $outFile, $query );
	}
	elsif( $OVERPASS eq 'remote' )
	{
		my $data = OGF::Util::Overpass::runQuery_remote( undef, $query );
		OGF::Util::File::writeToFile( $outFile, $data, '>:encoding(UTF-8)' );
	}
	elsif( $OVERPASS eq 'nop' )
	{
		print "query nop: $query\n";
	}
}

##################################################
sub build_filename($$$$$$)
{
	my($path, $base, $date, $suffix, $iteration, $ext) = @_;
	
	my $date_part      = defined $date ? '-' . strftime "%Y%m%d", gmtime $date : '';
	my $suffix_part    = defined $suffix ? '-' . $suffix : '';
	my $iteration_part = defined $iteration ? '-i' . $iteration : '';
	
	$path . '/' . $base . $date_part . $suffix_part. $iteration_part . '.' . $ext;
}

##################################################
sub latlon_to_key($$$$)
{
	my($latN, $lonW, $latS, $lonE) = @_;
	my $latNc = ($latN < 0) ? 'S' : 'N';
	my $lonWc = ($lonW < 0) ? 'W' : 'E';
	my $latSc = ($latS < 0) ? 'S' : 'N';
	my $lonEc = ($lonE < 0) ? 'W' : 'E';
	
	$latN *= -1 if( $latN < 0);
	$lonW *= -1 if( $lonW < 0);
	$latS *= -1 if( $latS < 0);
	$lonE *= -1 if( $lonE < 0);
	
	sprintf "%02d%s%03d%s%02d%s%03d%s", $latN, $latNc, $lonW, $lonWc, $latS, $latSc, $lonE, $lonEc;
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

##################################################
sub key_to_name($)
{
	my($key) = @_;
	if( $key =~ /^(\d{2})([NS])(\d{3})([EW])/ )
	{
		my $lat = $1 + 0;
		my $lon = $3 + 0;
		return "$lat$2, $lon$4";
	}
	return "unknown";
}

##################################################
sub classify($)
{
	my($count) = @_;

	return 10 if( $count >= 50000 );
	return  9 if( $count >= 25000 );
	return  8 if( $count >= 10000 );
	return  7 if( $count >=  5000 );
	return  6 if( $count >=  2000 );
	return  5 if( $count >=  1000 );
	return  4 if( $count >=   100 );
	return  3 if( $count >=    10 );
	return  2 if( $count >=     2 );
	return  1 if( $count >=     1 );
	return  0;
}

##################################################
sub midpoint($$$$)
{
	my($latN, $lonW, $latS, $lonE) = @_;
	my $midLat = ($latN + $latS) / 2;
	my $midLon = ($lonW + $lonE) / 2;
	"$midLat/$midLon";
}
