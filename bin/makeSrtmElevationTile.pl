#! /usr/bin/perl -w

use strict;
use warnings;
use OGF::Const;
use OGF::Terrain::Transform;
use OGF::Util::Usage qw( usageInit usageError );


# makeSrtmElevationTile.pl Roantra:4 -- -21 45 1200
# makeSrtmElevationTile.pl OGF:12 89 18  3600
# makeSrtmElevationTile.pl OGF:13 -- 124 -26
# makeSrtmElevationTile.pl OGF:9 -- 100 -64
# makeSrtmElevationTile.pl OGF:13 -- 50 -9
# makeSrtmElevationTile.pl OGF:13 -- 108 -63  3600
# makeSrtmElevationTile.pl OGF:13 3600 bbox=....
# perl C:/usr/OGF-terrain-tools/bin/makeSrtmElevationTile.pl Paxtar:0 1200 bbox=18.6,-45.94,37.86,-36.3
# perl C:/usr/OGF-terrain-tools/bin/makeSrtmElevationTile.pl Roantra:4 1200 bbox=25.97,43.14,31.34,47.10
# perl C:/usr/OGF-terrain-tools/bin/makeSrtmElevationTile.pl SathriaLCC:6 1200 bbox=41.22852,47.27061,42.13469,47.92959
# perl C:/usr/OGF-terrain-tools/bin/makeSrtmElevationTile.pl SathriaLCC:6 1200 bbox=41.1,47.1,41.9,47.9


my %opt;
usageInit( \%opt, qq/ noExist /, << "*" );
[-noExist] <layer> <x> <y>
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
	$BBOX =~ s/^bbox=//;
	$BBOX = [ map {POSIX::floor($_)} split /,/, $BBOX ];
    OGF::Terrain::Transform::makeSrtmElevationTile( $LAYER, $LEVEL, $SAMP_SIZE, $BBOX, \%opt );
}else{
    OGF::Terrain::Transform::makeSrtmElevationTile( $LAYER, $LEVEL, $SAMP_SIZE, [$X,$Y], \%opt );
}










