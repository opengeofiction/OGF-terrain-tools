use strict;
use warnings;
use OGF::Util::Usage qw( usageInit usageError );
use OGF::Util::File qw( makeFilePath );
use OGF::LayerInfo;
use OGF::Util::PPM;
use OGF::Terrain::ElevationTile qw( $T_WIDTH $T_HEIGHT $BPP makeArrayFromFile );
use OGF::Terrain::PhysicalMap qw( makeElevColorFile makeColorMap getElevColor getLandOrSeaColor setInlandWaterBorders );

# makePhysicalMap elev:Roantra:4:768:912
# makePhysicalMap elev:Roantra:4:all
# makePhysicalMap elev:Roantra:4:773-778:*
# makePhysicalMap elev:OGF:12:1832:3065
# makePhysicalMap elev:OGF:13:4683-4686:6937-6939
# makePhysicalMap elev:OGF:13:6004-6011:6327-6341
# makePhysicalMap elev:OGF:9:dir=/Map/OGF/WW_contour/9
# makePhysicalMap elev:OGF:10:dir=/Map/OGF/WW_contour/10
# makePhysicalMap elev:WebWW:9:1232-1238:3061-3082



my %opt;
usageInit( \%opt, qq/ S=s /, << "*" );
<layerInfo>
*

my( $wwInfoDsc ) = @ARGV;
usageError() unless $wwInfoDsc;


OGF::Terrain::ElevationTile::setGlobalTileInfo( 256, 256, 2, 1 )  if $wwInfoDsc =~ /:OGF:/;
OGF::Terrain::ElevationTile::setGlobalTileInfo( 256, 256, 2, -1 ) if $wwInfoDsc =~ /:WebWW:/;


my $wwInfo = OGF::LayerInfo->tileInfo( $wwInfoDsc );
my( $aColorMap ) = makeColorMap();

OGF::LayerInfo->tileIterator( $wwInfo, sub {
	my( $item ) = @_;
	convertElevFile( $item, $aColorMap );
} );


#-------------------------------------------------------------------------------

sub convertElevFile {
	my( $wwInfo, $aColorMap ) = @_;
#	die qq/convertElevFile: invalid type "$wwInfo->{type}" (must be "elev")/ unless $wwInfo->{'type'} eq 'elev';
#	print STDERR "\$fileIn <", $fileIn, ">\n";  # _DEBUG_
	my $aElev  = $wwInfo->copy('type' => 'elev')->tileArray();  # just to make sure
##	my $aWater = $wwInfo->copy('type' => 'water')->tileArray();

	my $fileOut = $wwInfo->copy( 'type' => 'phys' )->tileName();
	print STDERR "\$fileOut <", $fileOut, ">\n";  # _DEBUG_
	makeFilePath( $fileOut );

	makeElevColorFile( $aElev, $aColorMap, $fileOut, {_wwInfo => $wwInfo} );
}




#-------------------------------------------------------------------------------

# #my $START_DIR     = 'C:/Programme/Geography/World Wind 1.4/Cache/Earth/SRTM/LarrainconElev/0';
# #my $DST_DIR       = 'F:\Map\Larraincon\WW_cr';
# my $START_DIR     = 'C:/Programme/Geography/World Wind 1.4/Cache/Earth/SRTM/RoantraElev/4';
# my $DST_DIR       = 'C:\Map\Roantra\WW_phys';
# my $CONTOUR_DIR   = 'C:\Map\Roantra\WW_elev';
# #my $DST_DIR       = 'C:\Map\Roantra\WW_cn\4';
# #my $START_DIR     = 'C:/Programme/Geography/World Wind 1.4/Cache/Earth/SRTM/CearnoElev/0';
# #my $DST_DIR       = 'C:\Map\Cearno\WW_cr\4';
# my $TEMP_TER_FILE = 'C:\usr\tmp\tmp01.ter';
# my $TEMP_SHP_DIR  = 'C:\usr\tmp\tmp_shp_01';
# my $TEMP_TIF_FILE_01 = 'C:\usr\tmp\tmp01.tif';
# my $TEMP_TIF_FILE_02 = 'C:\usr\tmp\tmp02.tif';
# my $TEMP_PPM_FILE = 'C:\usr\tmp\tmp01.ppm';
# my $COLOR_MAP     = 'C:\usr\MapView\archiv\colors01.txt';
