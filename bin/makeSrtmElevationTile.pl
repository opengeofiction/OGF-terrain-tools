#! /usr/bin/perl -w

use strict;
use warnings;
use OGF::Const;
use OGF::Terrain::Transform;
use OGF::Util::Usage qw( usageInit usageError );


# perl C:/usr/MapView/bin/makeSrtmElevationTile.pl Roantra:4 -- -21 45
# perl C:/usr/MapView/bin/makeSrtmElevationTile.pl OGF:12 89 18  3600
# perl C:/usr/MapView/bin/makeSrtmElevationTile.pl OGF:13 -- 124 -26
# perl C:/usr/MapView/bin/makeSrtmElevationTile.pl OGF:9 -- 100 -64
# perl C:/usr/MapView/bin/makeSrtmElevationTile.pl OGF:13 -- 50 -9
# perl C:/usr/MapView/bin/makeSrtmElevationTile.pl OGF:13 -- 108 -63  3600
# perl C:/usr/MapView/bin/makeSrtmElevationTile.pl OGF:13 3600 bbox=....


my %opt;
usageInit( \%opt, qq//, << "*" );
<layer> <x> <y>
*

our( $LAYER, $X, $Y, $SAMP_SIZE, $BBOX );
if( $ARGV[2] =~ /^bbox=/ ){
    ( $LAYER, $SAMP_SIZE, $BBOX ) = @ARGV;
}else{
    ( $LAYER, $X, $Y, $SAMP_SIZE ) = @ARGV;
}
usageError() unless ($LAYER && $X && $Y) || ($LAYER && $BBOX);


our $LEVEL = 4;
( $LAYER, $LEVEL ) = split /:/, $LAYER if $LAYER =~ /:/;


#my $sampSize = 3600;  # SRTM1  30m
#my $sampSize = 1200;  # SRTM3  90m
my $sampSize = $SAMP_SIZE || 1200;


chdir $OGF::TERRAIN_OUTPUT_DIR;
if( $BBOX ){
#	$BBOX =~ s/^bbox=//;
#	my( $minLon, $minLat, $maxLon, $maxLat ) = map {POSIX::floor($_)} split /,/, $BBOX;
#	for( my $y = $minLat; $y <= $maxLat; ++$y ){
#       for( my $x = $minLon; $x <= $maxLon; ++$x ){
#			print STDERR "makeSrtmElevationTile $LAYER $LEVEL $x $y\n";
#			makeSrtmElevationTile( $LAYER, $LEVEL, $x, $y );
#       }
#	}
	$BBOX =~ s/^bbox=//;
	$BBOX = [ map {POSIX::floor($_)} split /,/, $BBOX ];
    OGF::Terrain::Transform::makeSrtmElevationTile( $LAYER, $LEVEL, $SAMP_SIZE, $BBOX );
}else{
    OGF::Terrain::Transform::makeSrtmElevationTile( $LAYER, $LEVEL, $SAMP_SIZE, $X, $Y );
}










