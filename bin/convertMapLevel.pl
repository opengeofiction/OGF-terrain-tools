#! /usr/bin/perl -w

use strict;
use warnings;
use File::Find;
use OGF::LayerInfo;
use OGF::Util::TileLevel;
use OGF::Util::Usage qw( usageInit usageError );


# convertMapLevel image:Roantra:7:all 0
# convertMapLevel phys:Roantra:4:all 0
# convertMapLevel elev:Roantra:4:all 0
# convertMapLevel elev:OGF:8:all 0
# convertMapLevel -sz 256,256 elev:WebWW:9:249-1557:2344-3171 0
# convertMapLevel -sz 256,256 elev:WebWW:9:249-1238:3061-3171 0     # Khaiwoon,Tarrases
# convertMapLevel -sz 256,256 elev:WebWW:10:589-592:6326-6342 0     # Tarrases only
# convertMapLevel -sz 256,256 elev:WebWW:9:1232-1238:3061-3082 0    # Khaiwoon only
# convertMapLevel -sz 256,256 elev:WebWW:10:dir=/Map/OGF/WW_elev_02/10 0     # Khaiwoon,Tarrases
# convertMapLevel -sz 256,256 elev:OGF:11:720-749:888-917 0
# convertMapLevel -sz 256,256 image:OGF:14:5768-5998:9386-9617 0
# convertMapLevel -sz 256,256 elev:OGF:9:dir=/Map/OGF/WW_contour/9 10
# convertMapLevel -sz 1024,1024 elev:SathriaLCC:2:dir=/Map/Sathria/elev/2 0



my %opt;
usageInit( \%opt, qq/ sz=s zip /, << "*" );
[-sz wd,hg] [-zip] <layerInfo> <target_level>
*

my( $layerDsc, $targetLevel ) = @ARGV;
usageError() unless $layerDsc && defined($targetLevel);


#my( $tileWd, $tileHg ) = $opt{'sz'} ? split(',',$opt{'sz'}) : (512,512);
my @zipList;
OGF::Util::TileLevel::convertMapLevel( $layerDsc, $targetLevel, $opt{'zip'} ? \@zipList : undef );


if( @zipList ){
	require OGF::Util::File;
	require Date::Format;
	my $zipFile = $OGF::$OGF::TERRAIN_OUTPUT_DIR .'/wwtiles-'. Date::Format::time2str('%Y%m%d-%H%M%S',time) .'.zip';
	OGF::Util::File::zipFileList( $zipFile, \@zipList );
	my $zip = Archive::Zip->new();
}







