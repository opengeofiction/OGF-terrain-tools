#! /usr/bin/perl -w
# 

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use File::Copy;
use JSON::PP;
use OGF::Data::Context;
use OGF::Util::File;
use OGF::Util::Overpass;
use OGF::Util::Usage qw( usageInit usageError );
use POSIX;
use File::Path;

sub housekeeping($$);
sub exportOverpassConvert($$$);
sub buildOverpassQuery($$);
sub fileExport_Overpass($$$);
sub validateCoastline($$$$$);
sub validateCoastlineDb($$);
sub saveToJSON($$);
sub publishFile($$);
sub createShapefilePublish($$$$$);

STDOUT->autoflush(1);
setpriority 0, 0, getpriority(0, 0) + 4; # nice ourselves

# parse options
my %opt;
usageInit( \%opt, qq/ h od=s copyto=s /, << "*" );
[-od <output_directory>] [-copyto <publish_directory>]

-od     Location to output JSON files
-copyto Location to publish JSON files for wiki & other use
*
usageError() if $opt{'h'};

my $BASE = '/opt/opengeofiction';
my $OUTPUT_DIR  = ($opt{'od'} and -d $opt{'od'}) ? $opt{'od'} : '/tmp';
my $PUBLISH_DIR = ($opt{'copyto'} and -d $opt{'copyto'}) ? $opt{'copyto'} : undef;
my $MISSING_NODE_LON = -180.0; my $MISSING_NODE_INCR = 3.0;

my $OSMCOASTLINE = "$BASE/osmcoastline/bin/osmcoastline";
$OSMCOASTLINE = 'osmcoastline' if( ! -x $OSMCOASTLINE );

chdir $OUTPUT_DIR or die "Cannot cd to $OUTPUT_DIR\n";
my $now       = time;
my $started   = strftime '%Y%m%d%H%M%S', gmtime $now;
my $startedat = strftime '%Y-%m-%d %H:%M:%S UTC', gmtime $now;
housekeeping $OUTPUT_DIR, $now;

# system load - do not continue coastline process if a backup is running
my $LOCKFILE="$BASE/backup/backup.lock";
if( -d $LOCKFILE )
{
	print "skipping, backup is running...\n";
	exit 0;
}

# build up Overpass query to get the top level admin_level=0 continent relations
my $ADMIN_CONTINENT_QUERY = '[timeout:1800][maxsize:4294967296];((relation["type"="boundary"]["boundary"="administrative"]["admin_level"="0"]["ogf:id"~"^[A-Z]{2}$"];);>;);out;';

my $osmFile = $OUTPUT_DIR . '/continent_polygons.osm';
print "QUERY: $ADMIN_CONTINENT_QUERY\n";
fileExport_Overpass $osmFile, $ADMIN_CONTINENT_QUERY, 12000;
if( -f $osmFile )
{
	# load in continent relations
	my $ctx = OGF::Data::Context->new();
	$ctx->loadFromFile( $osmFile );
	$ctx->setReverseInfo();
	
	# save coastline errors
	my @errs;
	my %issues;
	
	# for each continent - error check
	foreach my $rel ( values %{$ctx->{_Relation}} )
	{
		my $continent = $rel->{'tags'}{'ogf:id'};
		my $relid     = $rel->{'id'};
		
		print "\n*** $continent ** $relid ** $startedat **************************\n";
		
		# get osm coastline data via overpass and convert to osm.pbf
		my($rc, $pbfFile) = exportOverpassConvert \$ctx, \$rel, $started;
		unless( $rc eq 'success' )
		{
			print "unable to download $continent coastline, will use last good\n";
			next;
		}
		
		# run osmcoastline to validate
		my $dbFile   = "$OUTPUT_DIR/coastline-$continent-$started.db";
		$issues{$continent} = validateCoastline $continent, \@errs, $pbfFile, $dbFile, 'quick';
		unless( $issues{$continent}  == 0 )
		{
			print "issues with $continent coastline, will use last good\n";
			next;
		}
		
		# mark continent coastline as valid
		my $goldenFile = "$OUTPUT_DIR/coastline-$continent.osm.pbf";
		print "marking $continent as valid: $goldenFile\n";
		unlink $goldenFile if( -f $goldenFile );
		link $pbfFile, $goldenFile;
	}
	
	# save errors to JSON
	my %err = ();
	my $outputat = strftime '%Y-%m-%d %H:%M:%S UTC', gmtime;
	$err{'control'} = 'InfoBox';
	$err{'text'} = "Coastline check completed at <b>$outputat</b>, from $startedat run";
	$err{'started'} = $startedat;
	$err{'finished'} = $outputat;
	push @errs, \%err;
	saveToJSON 'coastline_errors.json', \@errs;
	
	# for each continent - construct worldwide coastlines
	my $filesToMerge = '';
	my @summary;
	my $nMissing = 0;
	foreach my $rel ( values %{$ctx->{_Relation}} )
	{
		my $continent = $rel->{'tags'}{'ogf:id'};
		my $goldenFile = "$OUTPUT_DIR/coastline-$continent.osm.pbf";
		my %sum = ();
		$sum{'continent'} = $continent;
		$sum{'errors'} = $issues{$continent} if( exists $issues{$continent} );
		$sum{'status'} = 'stale' if( !exists $issues{$continent} );
		$sum{'status'} = 'valid' if( exists $issues{$continent} and $issues{$continent} == 0 );
		$sum{'status'} = 'ERROR' if( exists $issues{$continent} and $issues{$continent} < 0 );
		$sum{'status'} = 'errors, using old coastline' if( exists $issues{$continent} and $issues{$continent} > 0 );
		
		if( -f $goldenFile )
		{
			my $mtime = (stat $goldenFile)[9];
			$sum{'mtime'} = strftime '%Y-%m-%d %H:%M:%S UTC', gmtime $mtime;
			$filesToMerge .= $goldenFile . ' ';
		}
		else
		{
			$sum{'status'} = 'missing';
			$nMissing++;
		}
		push @summary, \%sum;
	}
	
	# merge coastlines
	my $pbfFile = "$OUTPUT_DIR/coastline-$started.osm.pbf";
	my $dbFile  = "$OUTPUT_DIR/coastline-$started.db";
	print "merge to: $pbfFile using osmium merge\n";
	system "osmium merge --no-progress --verbose --output=$pbfFile $filesToMerge";
	if( ! -f $pbfFile )
	{
		print "issues merging world coastline\n";
		exit 1;
	}
	publishFile $pbfFile, 'coastline.osm.pbf';
	
	# save summary to JSON
	my %sum = ();
	$sum{'continent'} = 'world';
	$sum{'errors'} = 0;
	$sum{'status'} = 'in progress';
	$sum{'mtime'} = strftime '%Y-%m-%d %H:%M:%S UTC', gmtime time;
	push @summary, \%sum;
	saveToJSON 'coastline_summary.json', \@summary;
	pop @summary;
	
	# validate merged world coastline
	my @worlderrs;
	my $worldIssues = validateCoastline undef, \@worlderrs, $pbfFile, $dbFile, 'full';
	print "issues with world coastline\n" unless( $worldIssues == 0 );
	$sum{'errors'} = $worldIssues;
	$sum{'status'} = ($worldIssues == 0) ? 'valid' : 'ERROR';
	$sum{'mtime'} = strftime '%Y-%m-%d %H:%M:%S UTC', gmtime time;
	push @summary, \%sum;
	
	# save summary to JSON (again, now with the overall world coastline)
	saveToJSON 'coastline_summary.json', \@summary;
	
	# save world errors to JSON
	%err = ();
	$outputat = strftime '%Y-%m-%d %H:%M:%S UTC', gmtime;
	$err{'control'} = 'InfoBox';
	$err{'text'} = "World coastline check completed at <b>$outputat</b>, from $startedat run - there should be no errors";
	$err{'started'} = $startedat;
	$err{'finished'} = $outputat;
	push @worlderrs, \%err;
	saveToJSON 'coastline_errors_world.json', \@worlderrs;
	
	if( $worldIssues == 0 )
	{
		# at this point we now have an obsolutely clean coastline db file
		# which we can use to create land and coast shapefiles
		
		createShapefilePublish $dbFile, 'land-polygons-split-3857', 'land_polygons.shp', 'land_polygons', 0;
		createShapefilePublish $dbFile, 'water-polygons-split-3857', 'water_polygons.shp', 'water_polygons', 0;
		my $simplify = createShapefilePublish $dbFile, 'simplified-water-polygons-split-3857', 'simplified_water_polygons.shp', 'water_polygons', 25;
		createShapefilePublish $dbFile, 'simplified-land-polygons-complete-3857', 'simplified_land_polygons.shp', 'land_polygons', $simplify;

		print "complete\n";
		exit 0;
	}
	else
	{
		print "issues with world coastline\n";
		exit 1;
	}
}
else
{
	print "Error querying overpass\n";
	exit 1;
}

sub housekeeping($$)
{
	my($dir, $now) = @_;
	my $KEEP_FOR = 60 * 30; # 30 mins
	my $dh;
	
	opendir $dh, $dir;
	while( my $file = readdir $dh )
	{
		next unless( $file =~ /\d{14}/ );
		if( $now - (stat "$dir/$file")[9] > $KEEP_FOR )
		{
			print "deleting: $dir/$file\n";
			unlink "$dir/$file";
		}
	}
	closedir $dh;
}

sub exportOverpassConvert($$$)
{
	my($ctxref, $relref, $started) = @_;
	my $continent = $$relref->{'tags'}{'ogf:id'};
	my $osmFile   = "$OUTPUT_DIR/coastline-$continent-$started.osm";
	my $pbfFile   = "$OUTPUT_DIR/coastline-$continent-$started.osm.pbf";
	
	my $overpass = buildOverpassQuery $ctxref, $relref;
	print "query: $overpass\n";
	print "query Overpass and save to: $osmFile\n";
	fileExport_Overpass $osmFile, $overpass, 90000;
	if( -f $osmFile )
	{
		# convert to pbf
		print "convert to: $pbfFile using osmium sort\n";
		system "osmium sort --no-progress --output=$pbfFile $osmFile";
		
		# and copy for web
		if( -f $pbfFile )
		{
			unlink $osmFile;
			publishFile $pbfFile, "coastline-$continent.osm.pbf";
			
			return 'success', $pbfFile;
		}
	}
	return 'fail';
}

sub buildOverpassQuery($$)
{
	my($ctxref, $relref) = @_;
	my $overpass = qq|[out:xml][timeout:1800][maxsize:4294967296];(|;
	
	# query all coastlines within the continent using the extracted latlons
	# to limit - normally you'd use the built in overpass support for area
	# filters, but that does not work with the OGF setup
	my $aRelOuter = $$relref->closedWayComponents('outer');
	foreach my $way ( @$aRelOuter )
	{
		my $latlons = '';
		foreach my $nodeId ( @{$way->{'nodes'}} )
		{
			my $node = $$ctxref->{_Node}{$nodeId};
			if( ! $node )
			{
				print STDERR "  invalid node $nodeId (possible Overpass problem)\n";
				next;
			}
			$latlons .= ' ' if( $latlons ne '' );
			$latlons .= $node->{'lat'} . ' ' . $node->{'lon'};
		}
		$overpass .= qq|way["natural"="coastline"](poly:"$latlons");|;
	}
	$overpass .= qq|);(._;>;);out;|;
}

sub fileExport_Overpass($$$)
{
	require OGF::Util::Overpass;
	my($outFile, $query, $minSize) = @_;
	my $data = OGF::Util::Overpass::runQuery_remoteRetry(undef, $query, $minSize);
	OGF::Util::File::writeToFile( $outFile, $data, '>:encoding(UTF-8)' ) if( defined $data );
}

sub validateCoastline($$$$$)
{
	my($continent, $errs, $pbfFile, $dbFile, $mode) = @_;
	my $exotics = 0; my $warnings = 0; my $errors = 0;
	
	my $cmd = "$OSMCOASTLINE --verbose --srs=3857 --output-lines --output-polygons=both --output-rings --max-points=2000 --output-database=$dbFile $pbfFile 2>&1";
	$cmd = "$OSMCOASTLINE --verbose --srs=3857 --max-points=0 --output-database=$dbFile $pbfFile 2>&1" if( $mode eq 'quick' );
	open(my $pipe, '-|', $cmd) or return -1;
	while( my $line = <$pipe> )
	{
		print $line;
		if( $line =~ /Hole lies outside shell at or near point ([-+]?\d*\.?\d+) ([-+]?\d*\.?\d+)/ )
		{
			my %err = ();
			$err{'text'} = "Hole lies outside shell";
			$err{'icon'} = 'red';
			$err{'lat'} = $2; $err{'lon'} = $1;
			push @$errs, \%err;
			print "EXOTIC ERROR at: $1 $2\n";
			$exotics += 1;
		}
		elsif( $line =~ /Missing location of node (\d+)/ )
		{
			my %err = ();
			$err{'text'} = "Likely Overpass issue - missing node $1";
			$err{'icon'} = 'red';
			$err{'lat'} = -75.0;
			$err{'lon'} = $MISSING_NODE_LON += $MISSING_NODE_INCR;
			push @$errs, \%err;
			print "EXOTIC ERROR missing node: $1\n";
			$exotics += 1;
		}
		$warnings = $1 if( $line =~ /There were (\d+) warnings/ );
		$errors = $1 if( $line =~ /There were (\d+) errors/ );
	}
	close $pipe;
	
	my $issues = $warnings + $errors + $exotics;
	print "$issues issues (warnings: $warnings; errors: $errors; exotics: $exotics)\n";
	
	validateCoastlineDb $errs, $dbFile;
	
	# and copy for web
	publishFile $dbFile, "coastline-$continent.db" if( defined $continent );
	
	return $issues;
}

sub validateCoastlineDb($$)
{
	my($errs, $dbFile) = @_;
	
	# add WGS84 to SRIDs
	unless( `echo 'SELECT srid FROM spatial_ref_sys WHERE srid=4326;' | spatialite $dbFile ` =~ /^4326/ )
	{
		open my $sql, '|-', "spatialite $dbFile | cat";
		print $sql qq{INSERT INTO spatial_ref_sys(srid,auth_name,auth_srid,ref_sys_name,proj4text,srtext) VALUES (4326, 'epsg', 4326, 'WGS 84', '+proj=longlat +datum=WGS84 +no_defs', 'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AXIS["Latitude",NORTH],AXIS["Longitude",EAST],AUTHORITY["EPSG","4326"]]');};
		close $sql;
	}
	
	# error_points
	print "checking points...\n";
	my %nodes = ();
	foreach my $line( `echo "SELECT AsText(Transform(GEOMETRY,4326)) AS geom, osm_id, error FROM error_points;"| spatialite $dbFile `)
	{
		chomp $line;
		my($geom, $osm_id, $error) = split /\|/, $line;
		my $sub = substr $geom, 0, 70;
		printf "P: %-70s / %s / %s\n", $sub, $osm_id, $error;
		
		if( $geom =~ /^POINT\(([\-\d]+\.[\d]+) ([\-\d]+\.[\d]+)\)$/ )
		{
			my $lat = $2; my $lon = $1;
			$nodes{"$lat:$lon"} = 1; # use later to avoid duplicate error_line outputs
			
			if( $error eq 'tagged_node' )
			{
				my %err = ();
				$err{'text'} = "Node $osm_id has natural=coastline property tags";
				$err{'icon'} = "coastline/$error.png"; $err{'iconAnchor'} = [10, 10];
				$err{'lat'} = $lat; $err{'lon'} = $lon;
				$err{'id'} = $osm_id;
				push @$errs, \%err;
			}
			elsif( $error eq 'intersection' )
			{
				my %err = ();
				$err{'text'} = "Intersection of coastline ways";
				$err{'icon'} = "coastline/$error.png"; $err{'iconAnchor'} = [10, 10];
				$err{'lat'} = $lat; $err{'lon'} = $lon;
				push @$errs, \%err;
			}
			elsif( $error eq 'not_a_ring' )
			{
				my %err = ();
				$err{'text'} = "Not a ring: coastline could not be constructed into a closed polygon";
				$err{'icon'} = "coastline/$error.png"; $err{'iconAnchor'} = [10, 10];
				$err{'lat'} = $lat; $err{'lon'} = $lon;
				push @$errs, \%err;
			}
			elsif( $error eq 'unconnected' or $error eq 'fixed_end_point' )
			{
				my %err = ();
				$err{'text'} = "$error: Coastline is not closed";
				$err{'icon'} = "coastline/unconnected.png"; $err{'iconAnchor'} = [10, 10];
				$err{'lat'} = $lat; $err{'lon'} = $lon;
				push @$errs, \%err;
			}
			elsif( $error eq 'double_node' )
			{
				my %err = ();
				$err{'text'} = "Node $osm_id appears more than once in coastline";
				$err{'icon'} = "coastline/$error.png"; $err{'iconAnchor'} = [10, 10];
				$err{'lat'} = $lat; $err{'lon'} = $lon;
				$err{'id'} = $osm_id;
				push @$errs, \%err;
			}
			else
			{
				my %err = ();
				$err{'text'} = "Error: $error";
				$err{'icon'} = 'red';
				$err{'lat'} = $lat; $err{'lon'} = $lon;
				push @$errs, \%err;
				print "UNKNOWN: $geom,$osm_id,$error\n";
			}
		}
	}
	# error_lines
	print "checking lines...\n";
	foreach my $line( `echo "SELECT AsText(Transform(GEOMETRY,4326)) AS geom, osm_id, error FROM error_lines;"| spatialite $dbFile `)
	{
		chomp $line;
		my($geom, $osm_id, $error) = split /\|/, $line;
		my $sub = substr $geom, 0, 70;
		printf "L: %-70s / %d / %s\n", $sub, $osm_id, $error;
		
		if( $geom =~ /^LINESTRING\(([\-\d]+\.[\d]+) ([\-\d]+\.[\d]+)/ )
		{
			my $lat = $2; my $lon = $1;
			next if( exists $nodes{"$lat:$lon"} ); # don't output if we already had a node report
			
			if( $error eq 'overlap' )
			{
				my %err = ();
				$err{'text'} = "Overlapping coastline, first node on way shown";
				$err{'icon'} = "coastline/$error.png"; $err{'iconAnchor'} = [10, 10];
				$err{'lat'} = $lat; $err{'lon'} = $lon;
				push @$errs, \%err;
			}
			elsif( $error eq 'direction' )
			{
				my %err = ();
				$err{'text'} = "Reversed coastline - should be counter-clockwise, first node on way shown";
				$err{'icon'} = "coastline/wrong_direction.png"; $err{'iconAnchor'} = [10, 10];
				$err{'lat'} = $lat; $err{'lon'} = $lon;
				push @$errs, \%err;
			}
			else
			{
				my %err = ();
				$err{'text'} = "Error lines: $error, first node on way shown";
				$err{'icon'} = "coastline/error_line.png"; $err{'iconAnchor'} = [10, 10];
				$err{'lat'} = $lat; $err{'lon'} = $lon;
				push @$errs, \%err;
			}
		}
		else
		{
			print "UNKNOWN: $geom,$osm_id,$error\n";
		}
	}
}

sub saveToJSON($$)
{
	my($file, $obj) = @_;
	
	my $outputFile = "$OUTPUT_DIR/$file";
	my $publishFile = "$PUBLISH_DIR/$file" if( $PUBLISH_DIR );
	my $json = JSON::PP->new->canonical->indent(2)->space_after;
	my $text = $json->encode($obj);
	print "output to: $outputFile\n";
	OGF::Util::File::writeToFile($outputFile, $text, '>:encoding(UTF-8)');
	if( defined $publishFile )
	{
		print "publish to: $publishFile\n";
		copy $outputFile, $publishFile;
	}
}

sub publishFile($$)
{
	my($file, $dest) = @_;
	
	my $publishFile = "$PUBLISH_DIR/$dest" if( $PUBLISH_DIR );
	if( defined $publishFile )
	{
		print "publish to: $publishFile\n";
		copy $file, $publishFile;
	}
}

sub createShapefilePublish($$$$$)
{
	my($dbFile, $dir, $shapefile, $layer, $simplify) = @_;
	
	my $zipFile = "$dir.zip";
	my $simplifyOpt = $simplify > 0 ? "-simplify $simplify" : '';
	
	rmtree $dir if( -d $dir );
	mkdir $dir;
	my $cmd = "ogr2ogr -f 'ESRI Shapefile' $simplifyOpt $dir/$shapefile $dbFile $layer 2>&1";
	print "$cmd\n";
	system $cmd ;
	if( -f "$dir/$shapefile" )
	{
		# if simplified, check it didn't create multipolygons
		if( $simplify > 0 )
		{
			if( `ogrinfo -al $dir/$shapefile | grep MULTIPOLYGON | wc -l` > 0 )
			{
				print "multipolygons in simplified shapefile, reducing simplification\n";
				return createShapefilePublish $dbFile, $dir, $shapefile, $layer, $simplify - 5;
			}
		}
		system "zip -r $zipFile $dir";
		publishFile $zipFile, $zipFile;
	}
	return $simplify;
}