package OGF::Terrain::Transform;
use strict;
use warnings;
use POSIX;
use OGF::LayerInfo;
use OGF::Util::GlobalTile;
use OGF::Util::File qw( makeFilePath writeToFile );
use OGF::Terrain::ElevationTile qw( makeTileFromArray makeTileArray );



sub layerTransform {
#   my( $dscSrc, $dscTgt ) = ( "elev:OGF:13:all", "elev:WebWW:$level:all" );
#   my( $dscSrc, $dscTgt ) = ( "elev:WebWW:6:all", "elev:SathriaLCC:$level:all" );
#   my( $dscSrc, $dscTgt ) = ( 'C:/Map/ogf/work/eck4_Sathria_elev.cpx', "elev:SathriaLCC:$level:all" );
    my( $dscSrc, $dscTgt, $bbox, $hOpt ) = @_;
    $hOpt = {} if ! $hOpt;
    my $vtSrc = OGF::Util::GlobalTile->new( $dscSrc );
    my $vtTgt = OGF::Util::GlobalTile->new( $dscTgt );
#   use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 5; print STDERR Data::Dumper->Dump( [$vtTgt], ['vtTgt'] ), "\n";  # _DEBUG_
    my $aStrictBbox = $hOpt->{'strictBbox'} ? $bbox : undef;

    my( $minLon, $minLat, $maxLon, $maxLat ) = @$bbox;
    my( $tileWd, $tileHg ) = $vtTgt->{_layerInfo}->tileSize();
    print STDERR "\$tileWd <", $tileWd, ">  \$tileHg <", $tileHg, ">\n";  # _DEBUG_

    my @tileNW = $vtTgt->geo2tile( $minLon, $maxLat );
    my @tileSE = $vtTgt->geo2tile( $maxLon, $minLat );
    print STDERR "\@tileNW <", join('|',@tileNW), ">  \@tileSE <", join('|',@tileSE), ">\n";  # _DEBUG_

    # R:139 G:161  = 0
    $dscTgt =~ s/:all$//;

    my( $tx0, $tx1 ) = ($tileSE[0] <= $tileNW[0]) ? ($tileSE[0], $tileNW[0]) : ($tileNW[0], $tileSE[0]);
    my( $ty0, $ty1 ) = ($tileNW[1] <= $tileSE[1]) ? ($tileNW[1], $tileSE[1]) : ($tileSE[1], $tileNW[1]);
	my $hRange = { _xMin => $tx0, _xMax => $tx1, _yMin => $ty0, _yMax => $ty1 };

    # convertMapLevel -sz 256,256 elev:WebWW:9:1232-1238:3061-3082 0    # Khaiwoon only
#   my $cmdMapLevel = qq|convertMapLevel.pl  -sz $tileWd,$tileHg -zip  $dscTgt:$ty0-$ty1:$tx0-$tx1 0|;

    for( my $ty = $ty0; $ty <= $ty1; ++$ty ){
        for( my $tx = $tx0; $tx <= $tx1; ++$tx ){
#           next unless $tx == 2 && $ty == 0;
            my $file = OGF::LayerInfo->tileInfo("$dscTgt:$ty:$tx")->tileName();
            print STDERR "TILE: ", $file, "\n";  # _DEBUG_
            next if $hOpt->{'noExist'} && -f $file;
            my $aTile = (-f $file)? OGF::LayerInfo->tileInfo("$dscTgt:$ty:$tx")->tileArray() : [];
            for( my $y = 0; $y < $tileHg; ++$y ){
                $aTile->[$y] = [] if ! $aTile->[$y];
                for( my $x = 0; $x < $tileWd; ++$x ){
#                   next if $aTile->[$y][$x];
#                   print STDERR "tgt $tx $ty $x $y\n";
                    my $ptGeo = $vtTgt->tile2geo( [$tx, $ty, $x, $y] );
                    next if $aStrictBbox && ! inBbox( $aStrictBbox, $ptGeo );
#                   $ptGeo->[0] -= 50;   ### Roantra specific ###
                    print STDERR "\@\$ptGeo <", join('|',@$ptGeo), ">\n";  # _DEBUG_
                    my $ptElev = $vtSrc->geo2cnv( $ptGeo );
#                   print STDERR "\$ptElev <", join(',',@$ptElev), ">\n"; exit; # _DEBUG_
#                   my( $xe, $ye ) = ( floor($ptElev->[0]+.5), floor($ptElev->[1]+.5) );
#                   my $elev = $vtSrc->[$ye][$xe];

                    my( $xe, $ye ) = ( $ptElev->[0], $ptElev->[1] );
                    my( $x0, $y0 ) = ( floor($xe), floor($ye) );
                    my( $x1, $y1 ) = ( $x0 + 1, $y0 + 1 );
                    my( $elev00, $elev10, $elev01, $elev11 ) = ( $vtSrc->getPixel($x0,$y0), $vtSrc->getPixel($x1,$y0), $vtSrc->getPixel($x0,$y1), $vtSrc->getPixel($x1,$y1) );
                    my $elev = ($x1-$xe)*($y1-$ye)*$elev00 + ($xe-$x0)*($y1-$ye)*$elev10 + ($x1-$xe)*($ye-$y0)*$elev01 + ($xe-$x0)*($ye-$y0)*$elev11;
                    $elev = floor( $elev + .5 );
#                   print STDERR "$y $x - (", $elev, ") - \$elev00 <", $elev00, ">  \$elev10 <", $elev10, ">  \$elev01 <", $elev01, ">  \$elev11 <", $elev11, ">\n";  # _DEBUG_
                    $elev = 0 if $elev < 1;

                    $aTile->[$y][$x] = $elev;
                }
            }

            my $data = makeTileFromArray( $aTile, 2 );
            makeFilePath( $file );
            writeToFile( $file, $data, undef, {-bin => 1, -mdir => 1} );
            unlink "$file.png" if -f "$file.png";
        }
    }

	my $hInfo = {	_tileRange => $hRange, _tileSize => [$tileWd, $tileHg] };
	return $hInfo;
}

sub inBbox {
    my( $bbox, $pt ) = @_;
    my( $x0, $y0, $x1, $y1, $x, $y ) = ( @$bbox, @$pt );
    return ($x >= $x0 && $x <= $x1 && $y >= $y0 && $y <= $y1);
}




#--- SRTM ----------------------------------------------------------------------------

our $OUTPUT_DIRECTORY;


sub makeSrtmElevationTile {
    my( $layer, $level, $sampSize, $aCoord, $hOpt ) = @_;
    $hOpt = {} if ! $hOpt;

	if( scalar(@$aCoord) == 4 ){
        my( $minLon, $minLat, $maxLon, $maxLat ) = map {POSIX::floor($_)} @$aCoord;
        for( my $y = $minLat; $y <= $maxLat; ++$y ){
            for( my $x = $minLon; $x <= $maxLon; ++$x ){
                print STDERR "makeSrtmElevationTile $layer $level $x $y\n";
                makeSrtmElevationTile( $layer, $level, $sampSize, [$x,$y], $hOpt );
            }
        }
		return;
	}
	my( $X, $Y ) = @$aCoord;

    my $outfile = sprintf( '%s%02d%s%03d.hgt', (($Y =~ /^-/)? 'S':'N'), abs($Y), (($X =~ /^-/)?'W':'E'), abs($X) );
	$outfile = $OUTPUT_DIRECTORY .'/'. $outfile if $OUTPUT_DIRECTORY;
	print STDERR "* file: ", $outfile, "\n";  # _DEBUG_
    if( $hOpt->{'noExist'} && -e $outfile ){
        print STDERR qq/File "$outfile" already exists, skipping.\n/;
        return;
    }

    my $aRows  = makeTileArray( sub{ 0; }, $sampSize+1, $sampSize+1 );
    my $vtElev = OGF::Util::GlobalTile->new( "elev:$layer:$level:all", {'-default' => 0} );

    for( my $yy = 0; $yy < ($sampSize+1); ++$yy ){
        print STDERR "* $yy/$sampSize\n" if $yy % 10 == 0;
        for( my $xx = 0; $xx < ($sampSize+1); ++$xx ){
            my $elev = getSrcElevation( $vtElev, $sampSize, $X, $Y, $xx, $yy );
            $aRows->[$yy][$xx] = $elev;
        }
    }

    my $text = makeTileFromArray( $aRows, 2, 's>' );

    writeToFile( $outfile, $text, undef, {-bin => 1} );

#   require OGF::Terrain::PhysicalMap;
#   my( $aColorMap ) = OGF::Terrain::PhysicalMap::makeColorMap();
#   OGF::Terrain::PhysicalMap::makeElevColorFile( $aRows, $aColorMap, "$OUTFILE.png", {_size => [$sampSize+1,$sampSize+1], _bigEndian => 1} );
}


sub getSrcElevation {
    my( $vtElev, $sampSize, $X, $Y, $xx, $yy ) = @_;
    my $arc = 1 / $sampSize;
    my( $degX, $degY ) = ( $X + $xx * $arc, $Y + 1 - $yy * $arc );
#   $degX -= 50;   ### Roantra specific ###
#	print STDERR "\$degY <", $degY, ">  \$degX <", $degX, ">\n";  # _DEBUG_

    my( $xC, $yC ) = $vtElev->geo2cnv( $degX, $degY );
    my( $x0, $y0 ) = ( POSIX::floor($xC), POSIX::floor($yC) );
    my( $x1, $y1 ) = ( $x0 + 1, $y0 + 1 );
#	print STDERR "[$xx:$yy] \$x0 <", $x0, ">  \$y0 <", $y0, ">  \$x1 <", $x1, ">  \$y1 <", $y1, ">\n";  # _DEBUG_

#   my( $elev00, $elev01, $elev10, $elev11 ) = ( $vtElev->getPixel($x0,$y0) || 0, $vtElev->getPixel($x1,$y0) || 0, $vtElev->getPixel($x0,$y1) || 0, $vtElev->getPixel($x1,$y1) || 0 );
#   my $elev = ($y1-$yC)*($x1-$xC)*$elev00 + ($y1-$yC)*($xC-$x0)*$elev01 + ($yC-$y0)*($x1-$xC)*$elev10 + ($yC-$y0)*($xC-$x0)*$elev00;

    my( $elev00, $elev01, $elev10, $elev11 ) = ( $vtElev->getPixel($x0,$y0) || 0, $vtElev->getPixel($x0,$y1) || 0, $vtElev->getPixel($x1,$y0) || 0, $vtElev->getPixel($x1,$y1) || 0 );
    my( $dx0, $dx1, $dy0, $dy1 ) = ( $xC - $x0, $x1 - $xC, $yC - $y0, $y1 - $yC );
    my $elev = $dx1*$dy1*$elev00 + $dx1*$dy0*$elev01 + $dx0*$dy1*$elev10 + $dx0*$dy0*$elev11;

    $elev = POSIX::floor( $elev + .5 );
    return $elev;
}


sub loadElevationArray {
    my( $layer, $x0, $y0 ) = @_;
    return OGF::LayerInfo->cachedTileArray( "elev:$layer:4:$y0:$x0", [1,1] );
}






1;


