#! /usr/bin/perl -w

use strict;
use warnings;
use Tk;
use OGF::LayerInfo;
use OGF::Terrain::ContourEditor;
use OGF::Util::Usage qw( usageInit usageError );


# editelevationtile -s 2 image:Roantra:4:768:912
# editelevationtile -s 2 phys:Roantra:4:768:912
# editelevationtile -s 2 -layout 7x7 image:OGF:7:47:79
# editelevationtile -s 2 -layout 5x5 image:OGF:6:24:39 -f C:\Map\Common\OpenStreetMap\Sample2\Sathria_E_Overview.osm
# editelevationtile -layout 9x7 image:OGF:12:1832:3065 -f C:\Map\Common\OpenStreetMap\Sample2\Khaiwoon_Elevation.osm
# editelevationtile -layout 9x7 -s 2 image:OGF:12:1832:3065 -f C:\TEMP\ogf_140817_0000_Elevation_Khaiwoon.ogf
# editelevationtile -layout 5x3 -s 2 image:OGF:13:4685:6938
# editelevationtile -layout 1x1 -s 2 image:OGF:13:5735:6001


my %opt = ('f' => []);
usageInit( \%opt, qq/ s=i layout=s test f=s /, << "*" );
[-s <scale>] [-layout XxY] [-test] [-f <ogf_file> ...] <wwInfo>
*

our( $WW_INFO ) = @ARGV;
usageError() unless $WW_INFO;


my $bpp = 2;  # bytes per pixel
my $scale   = $opt{'s'}      ? $opt{'s'} : 1;
my $aLayout = $opt{'layout'} ? [ split /x/, $opt{'layout'} ] : [ 3, 3 ];


OGF::Terrain::ElevationTile::setGlobalTileInfo( 256, 256, 2, 1 ) if $WW_INFO =~ /:OGF:/;



my $geom = $opt{'test'} ? '1200x700+0+0' : '1500x1100+0+0';

my $info = OGF::LayerInfo->tileInfo( $WW_INFO );
my $main = MainWindow->new( -title => 'Elevation Editor' );
$main->geometry( $geom );

my $obj = $main->ContourEditor(
#	-background => '#000000',
    -scale      => $scale,
    -layout     => $aLayout,
)->pack( -fill => 'both', -expand => 1 );
#	$obj->{_OGF_canvas}->focus();

$obj->{_OGF_canvas}->configure( -background => '#000000' );
#$obj->loadTiles( $LAYER, $TX, $TY, $LEVEL );
#$obj->loadTiles( $info->{'layer'}, $info->{'x'}, $info->{'y'}, $info->{'level'} );
$obj->loadTiles( $info );

if( $opt{'f'} ){
#	my $projDsc = join ':', $info->{'type'}, $info->{'layer'}, $info->{'level'}, 'all';
    my $projDsc = '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs';  # OSM
    foreach my $file ( @{$opt{'f'}} ){	
        $obj->ogfLoadFile( $file, $projDsc );
    }
}

$obj->bindInit();
$obj->{_OGF_canvas}->Tk::focus();

MainLoop();




