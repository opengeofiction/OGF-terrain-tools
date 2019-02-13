#! /usr/bin/perl -w

use strict;
use warnings;
use POSIX qw( floor ceil );
use OGF::LayerInfo;
use OGF::Terrain::Transform;
use OGF::Util::Usage qw( usageInit usageError );

my %opt;
usageInit( \%opt, qq/ noExist strictBbox roantraDisplace bpp=i overlap targetLevel=i /, << "*" );
<level=...> <bbox=...> <src=...> <tgt=...>
*

#my( $BBOX ) = @ARGV;
#usageError() unless $BBOX;

# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=25.97,29.47,56.61,49.49 src=elev:SathriaLCC:2:all tgt=elev:SathriaLCC:5:all -noExist    # Sathria
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=25.97,43.14,31.346,47.10 src=elev:Roantra:4:all tgt=elev:SathriaLCC:5:all -strictBbox   # Roantra
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=30.9,43.1,31.4,43.772 src=elev:SathriaLCC:2:all tgt=elev:SathriaLCC:5:all -strictBbox   # Sathria repair
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=42.62146,48.01932,44.47266,49.42884 src=elev:SathriaLCC:2:all tgt=elev:SathriaLCC:5:all -strictBbox   # Sathria repair
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=31.15,45.48,31.346,47.10 src=elev:Roantra:4:all tgt=elev:SathriaLCC:5:all -strictBbox   # Roantra repair

# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=25.97,29.47,56.61,49.49 src=elev:SathriaLCC:5:all tgt=elev:SathriaLCC:6:all -noExist
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=41.22852,47.27061,42.13469,47.92959 src=elev:SathriaLCC:5:all tgt=elev:SathriaLCC:6:all -noExist
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl size=1024 bbox=30.99,43.78992,31.32844,46.39 src=elev:Roantra:4:all tgt=elev:SathriaLCC:6:all -strictBbox -roantraDisplace   # Roantra insert
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl bbox=25.97,43.14,31.346,47.10 src=elev:Roantra:4:all tgt=elev:OpenGlobus:13:all -roantraDisplace -bpp 4 -overlap   # Roantra -> OpenGlobus
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl bbox=25.97,43.14,31.346,47.10 src=elev:Roantra:4:all tgt=elev:OGF:12:all -roantraDisplace   # Roantra -> OGF
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl bbox=89.10,18.31,89.93,18.85 src=elev:OGF:12:all tgt=elev:OpenGlobus:14:all -overlap -bpp 4 -targetLevel 0    # Khaiwoon -> OpenGlobus
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl bbox=83.41928,-58.51041,84.18434,-58.20117 src=elev:OGF:13:all tgt=elev:OpenGlobus:14:all -overlap -bpp 4 -targetLevel 0    # Tarrases
# perl C:\usr\OGF-terrain-tools\bin\terrainTransform.pl bbox=89.10,18.31,89.93,18.85 src=elev:OpenGlobus:14:all tgt=elev:OpenGlobus:13:all -overlap    # Khaiwoon -> OpenGlobus
# single point: Kh 89.4474,18.4627,89.4474,18.4627  Ta 83.9484,-58.3295,83.9484,-58.3295


my( $tileSize, @bbox, $dscSrc, $dscTgt );

foreach my $arg ( @ARGV ){
	if( $arg =~ s/^bbox=//i ){
		die qq/Ivalid bbox descriptor: $arg\n/ unless $arg =~ /^(-?[.\d]+),(-?[.\d]+),(-?[.\d]+),(-?[.\d]+)/;
		@bbox = ( $1, $2, $3, $4 );
	}elsif( $arg =~ s/^size=//i ){
		die qq/Ivalid size descriptor: $arg\n/ unless $arg =~ /^\d+$/;
		$tileSize = $arg;
	}elsif( $arg =~ s/^src=//i ){
        $dscSrc = $arg;
	}elsif( $arg =~ s/^tgt=//i ){
        $dscTgt = $arg;
	}else{
		die qq/Unknown argument: $arg\n/;
	}
}
usageError() unless @bbox && $dscSrc && $dscTgt;
print STDERR "\nNW = [", $bbox[0], ",", $bbox[1], "]\nSE = [", $bbox[2], ",", $bbox[3], "]\n\n";  # _DEBUG_


my $hInfo = OGF::Terrain::Transform::layerTransform( $dscSrc, $dscTgt, \@bbox, \%opt );

my( $tileWd, $tileHg ) = @{$hInfo->{_tileSize}};
my( $tx0, $tx1, $ty0, $ty1 ) = map {$hInfo->{_tileRange}{$_}} qw( _xMin _xMax _yMin _yMax );


if( defined $opt{'targetLevel'} ){
    my $targetLevel = $opt{'targetLevel'};
    while( 1 ){
        $dscSrc = $dscTgt;
        my( $type, $layer, $level ) = split /:/, $dscSrc;
        $level -= 1;
        last if $level < $targetLevel;
        print STDERR qq/----- Write level $level -----\n/;
        $dscTgt = join( ':', $type, $layer, $level, 'all' );
        print STDERR qq/src=$dscSrc tgt=$dscTgt\n/;
        $hInfo = OGF::Terrain::Transform::layerTransform( $dscSrc, $dscTgt, \@bbox, \%opt );
    }
}else{
    $dscTgt =~ s/:all$//;
    my $cmdMapLevel = qq|convertMapLevel.pl  -sz $tileWd,$tileHg -zip  $dscTgt:$ty0-$ty1:$tx0-$tx1 0|;
    print STDERR "----- next cmd -----\n$cmdMapLevel\n";
}

