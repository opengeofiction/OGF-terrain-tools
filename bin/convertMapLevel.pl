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
[-sz wd,hg] [-zip] <ww_info> <target_level>
*

my( $wwInfoDsc, $targetLevel ) = @ARGV;
usageError() unless $wwInfoDsc && defined($targetLevel);


#my( $tileWd, $tileHg ) = $opt{'sz'} ? split(',',$opt{'sz'}) : (512,512);
my @zipList;
OGF::Util::TileLevel::convertMapLevel( $wwInfoDsc, $targetLevel, $opt{'zip'} ? \@zipList : undef );


if( @zipList ){
	require OGF::Util::File;
	require Date::Format;
	my $zipFile = 'C:/Map/Elevation/tmp/maptiles-'. Date::Format::time2str('%Y%m%d-%H%M%S',time) .'.zip';
	OGF::Util::File::zipFileList( $zipFile, \@zipList );
	my $zip = Archive::Zip->new();
}




#sub convertMapLevel {
#	my( $wwInfoDsc, $targetLevel, $aZipList ) = @_;
#
#   my $wwInfo = OGF::LayerInfo->tileInfo( $wwInfoDsc );
#   $OGF::Util::TileLevel::WWINFO_TYPE = $wwInfo->{'type'};
#
#   my( $upDown, @list );
#   if( $targetLevel < $wwInfo->{'level'} ){
#       ( $upDown, @list ) = ( 'down', reverse ($targetLevel .. $wwInfo->{'level'}) );
#   }elsif( $targetLevel > $wwInfo->{'level'} ){
#       ( $upDown, @list ) = ( 'up', $wwInfo->{'level'} .. $targetLevel );
#   }else{
#       die qq/level == targetLevel, nothing to do/;
#   }
#   pop @list;
#
#   foreach my $level ( @list ){
#       my $hCreated = {};
#       OGF::LayerInfo->tileIterator( $wwInfo, sub {
#           my( $item ) = @_;
#           if( $upDown eq 'down' ){
#               OGF::Util::TileLevel::downLevelConcat( $tileWd, $tileHg, $item, $hCreated );
#           }else{
#               OGF::Util::TileLevel::upLevelSplit( $tileWd, $tileHg, $item );
#           }
#           push @zipList, $item->tileName() if $opt{'zip'} && $level == $list[0];
#       } );
#       $wwInfo = $wwInfo->copy( 'level' => $upDown );
#       print STDERR $wwInfo->toString(), "\n";
#
#       push @$aZipList, (keys %$hCreated) if $aZipList;
#   }
#}
#
#
#if( @zipList ){
#	require Archive::Zip;
#	require Date::Format;
#	my $zipFile = 'C:/Map/Elevation/tmp/maptiles-'. Date::Format::time2str('%Y%m%d-%H%M%S',time) .'.zip';
#	my $zip = Archive::Zip->new();
#	foreach my $file ( @zipList ){
#		(my $fname = $file) =~ s|^.*?/(\d+/)|$1|;
#		print STDERR $file, " -> ", $fname, "\n";
#		$zip->addFile( $file, $fname );
#	}
#	$zip->writeToFileNamed( $zipFile );
#	print STDERR "Zip file: ", $zipFile, "\n";
#}



