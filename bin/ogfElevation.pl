#! /usr/bin/perl -w

use strict;
use warnings;
use POSIX;
use OGF::Terrain::ContourLines;
use OGF::Terrain::Transform;
use OGF::Data::Context;
use ARS::Util::Usage qw( usageInit usageError );


# ogfElevation 13 C:\Map\Elevation\extremosur.osm
# ogfElevation  9 C:\Map\Elevation\mh_oa_contour.osm
# ogfElevation 10 C:\Map\Elevation\mh_oa_contour.osm
# ogfElevation 13 C:\Map\Elevation\tarrases_02_contour.osm
# ogfElevation 13 C:\Map\Elevation\ji_contour_v20170205_for_upload.osm
# ogfElevation 13 C:\Map\Elevation\Countours_TR.osm
# ogfElevation 13 C:\Map\Elevation\mh_83E59S-84E59S_contour_v20170210_for_upload.osm
# perl C:\usr\MapView\bin\ogfElevation.pl 13 fa_v20170227_contours_121E22S_band1_for_upload.osm fa_v20170227_contours_121E22S_band2_for_upload.osm fa_v20170227_thalwegs_comala_for_upload.osm
# perl C:\usr\MapView\bin\ogfElevation.pl 13 C:\Map\Elevation\elevation_test_01.osm



my %opt;
usageInit( \%opt, qq/ c add /, << "*" );
[-c] [-add] <level> <osm_file> [<osm_file2> ...]
*

my( $LEVEL, @OSM_FILES ) = @ARGV;
usageError() unless @OSM_FILES && $LEVEL;


my $wwLevel      = 9;
my $srtmSampSize = 1200;

my $ctx = OGF::Data::Context->new();
foreach my $file ( @OSM_FILES ){
	print STDERR "load OSM file: $file\n";
	$ctx->loadFromFile( $file );
}
my $hInfo = OGF::Terrain::ContourLines::writeContourTiles( $ctx, "contour:OGF:$LEVEL", undef, \%opt );


my( $hRange, $bbox ) = ( $hInfo->{_tileRange}, $hInfo->{_bbox} );
my( $tx0, $tx1, $ty0, $ty1 ) = map {$hInfo->{_tileRange}{$_}} qw( _xMin _xMax _yMin _yMax );

$ctx = undef;   # release memory for further processing


if( $opt{'c'} ){
    require Date::Format;
	require OGF::Util::File;
	require OGF::Util::TileLevel;
	require OGF::LayerInfo;
	require OGF::Terrain::ElevationTile;

	# makeElevationFromContour
	my $infoDsc = "contour:OGF:$LEVEL:$ty0-$ty1:$tx0-$tx1";
	OGF::Terrain::ElevationTile::setGlobalTileInfo( 256, 256, 2, 1 ) if $infoDsc =~ /:OGF:/;

    my $wwInfo = OGF::LayerInfo->tileInfo( $infoDsc );
    OGF::LayerInfo->tileIterator( $wwInfo, sub {
        my( $item ) = @_;
        OGF::Terrain::ElevationTile::makeElevationFile( $item );
    } );

	# makeSrtmElevationTile
	$OGF::Terrain::Transform::OUTPUT_DIRECTORY = $OGF::TERRAIN_OUTPUT_DIR;
    OGF::Terrain::Transform::makeSrtmElevationTile( 'OGF', $LEVEL, $srtmSampSize, $bbox );

	# make WW elevation
	my( $dscSrc, $dscTgt ) = ( "elev:OGF:$LEVEL:all", "elev:WebWW:$wwLevel:all" );
	my $hInfo2 = OGF::Terrain::Transform::layerTransform( $dscSrc, $dscTgt, $bbox );
	
	# tile levels
	my( $tx20, $tx21, $ty20, $ty21 ) = map {$hInfo2->{_tileRange}{$_}} qw( _xMin _xMax _yMin _yMax );
	my $infoDsc2 = "elev:WebWW:$wwLevel:$ty20-$ty21:$tx20-$tx21";
	my @zipList;
	OGF::Util::TileLevel::convertMapLevel( $infoDsc2, 0, \@zipList );

    my $zipFile = $OGF::TERRAIN_OUTPUT_DIR .'/wwtiles-'. Date::Format::time2str('%Y%m%d-%H%M%S',time) .'.zip';
	OGF::Util::File::zipFileList( $zipFile, \@zipList );

}else{
    $bbox->[0] = POSIX::floor( 1000 * $bbox->[0] ) / 1000;
    $bbox->[1] = POSIX::floor( 1000 * $bbox->[1] ) / 1000;
    $bbox->[2] = (POSIX::floor( 1000 * $bbox->[2] ) + 1) / 1000;
    $bbox->[3] = (POSIX::floor( 1000 * $bbox->[3] ) + 1) / 1000;

    my $cmdMakeElev    = qq|makeElevationFromContour.pl contour:OGF:$LEVEL:$ty0-$ty1:$tx0-$tx1|;
    my $cmdMakeSRTM    = qq|makeSrtmElevationTile.pl OGF:$LEVEL 1200 bbox=| . join(',',@$bbox);
    my $cmdConvertElev = qq|makeOsmElevation.pl level=9 size=256 bbox=| . join(',',@$bbox);
    print STDERR "----- next cmd -----\n$cmdMakeElev\n$cmdMakeSRTM\n$cmdConvertElev\n";
}





