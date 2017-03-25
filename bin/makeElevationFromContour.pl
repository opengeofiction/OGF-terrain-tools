#! /usr/bin/perl -w

use strict;
use warnings;
use Tk;
use OGF::LayerInfo;
use OGF::Terrain::ElevationTile qw( makeElevationFile );
use OGF::Util::Usage qw( usageInit usageError );


# makeElevationFromContour contour:Roantra:4:768:912
# makeElevationFromContour contour:Roantra:4:all
# makeElevationFromContour contour:OGF:12:1832:3065
# makeElevationFromContour contour:OGF:12:1829-1835:3061-3069
# makeElevationFromContour contour:OGF:13:4683-4686:6937-6939
# makeElevationFromContour contour:OGF:9:dir=/Map/OGF/WW_contour/9
# makeElevationFromContour contour:OGF:10:dir=/Map/OGF/WW_contour/10



my %opt;
usageInit( \%opt, qq//, << "*" );
<wwInfo>
*

my( $wwInfoDsc ) = @ARGV;
usageError() unless $wwInfoDsc;


#OGF::Terrain::ElevationTile::setGlobalTileInfo( 512, 512, 2 );
#our $MIN_MTIME = 0;
OGF::Terrain::ElevationTile::setGlobalTileInfo( 256, 256, 2, 1 ) if $wwInfoDsc =~ /:OGF:/;


my $wwInfo = OGF::LayerInfo->tileInfo( $wwInfoDsc );

OGF::LayerInfo->tileIterator( $wwInfo, sub {
	my( $item ) = @_;
	makeElevationFile( $item );
} );




