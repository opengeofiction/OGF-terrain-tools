package OGF::Util::TileLevel;
use strict;
use warnings;
use File::Copy;
use OGF::Util::File qw( makeFilePath );
use Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( convertToPnm convertFromPnm getTempFileNames );

our $WWINFO_TYPE = 'image';
my $TMP_PNM_FILE = ($^O eq 'MSWin32')? 'C:\usr\tmp\TMP_TileLevelTools.ppm' : '/home/osm/Roantra/tmp/TMP_TileLevelTools.ppm';
my $DEFAULT_FILE_DIR = ($^O eq 'MSWin32')? 'C:\Map\Common\DefaultFiles\\' : '/home/osm/Roantra/default/';

my %CONV_CMD = (
	'tif.in'  => qq/tifftopnm "{IN}" > "{OUT}"/,
	'tif.out' => qq/pamtotiff "{IN}" > "{OUT}"/,
	'png.in'  => qq|pngtopnm "{IN}" > "{OUT}"|,
	'png.out' => qq/pnmtopng "{IN}" > "{OUT}"/,
	'jpg.in'  => qq|jpegtopnm "{IN}" > "{OUT}"|,
	'jpg.out' => qq/pnmtojpeg "{IN}" > "{OUT}"/,
	'gif.in'  => qq|giftopnm "{IN}" > "{OUT}"|,
	'gif.out' => qq/pnmtogif "{IN}" > "{OUT}"/,
	'ppm.in'  => 'NOCONV',
	'ppm.out' => 'NOCONV',
	'pgm.in'  => 'NOCONV',
	'pgm.out' => 'NOCONV',
);

my $CMD_PNMCUT   = ($^O eq 'MSWin32')? 'pamcut'   : 'pnmcut';
my $CMD_PNMSCALE = ($^O eq 'MSWin32')? 'pamscale' : 'pnmscale';
my $CMD_COPY     = ($^O eq 'MSWin32')? 'copy'     : 'cp';


sub convertToPnm {
	my( $fileIn, $filePnm, $wd, $hg ) = @_;
#	print STDERR "convertToPnm( $fileIn, $wd, $hg )\n"; # _DEBUG_
	$filePnm = $TMP_PNM_FILE if !defined $filePnm;
	if( -e $fileIn ){
		runConvCommand( $fileIn, $filePnm, 'in' );
	}elsif( defined $hg ){
#		my $cmd = qq|ppmmake rgb:0/0/20 $wd $hg > "$filePnm"|;
		my $defaultFile = $DEFAULT_FILE_DIR . (($WWINFO_TYPE =~ /^(?:phys|relief)$/)? 'phys_01.ppm' : 'image.ppm');
		$defaultFile =~ s/\.ppm/_$wd.ppm/ unless $wd == 512;
		my $cmd = qq|$CMD_COPY "$defaultFile" "$filePnm"|;
		print STDERR "CMD: ", $cmd, "\n";  # _DEBUG_
		system $cmd;
	}else{
		die qq/convertToPnm: No such file: $fileIn\n/;
	}
	return $filePnm;
}

sub convertFromPnm {
	my( $fileOut, $filePnm ) = @_;
	$filePnm = $TMP_PNM_FILE if !defined $filePnm;
	runConvCommand( $filePnm, "$fileOut.tmp", 'out' );
	move( "$fileOut.tmp", $fileOut );
	return $fileOut;
}

sub getConvCommand {
	my( $fileIn, $fileOut, $inOut ) = @_;
#	print STDERR "runConvCommand( $fileIn, $fileOut, $inOut )\n";  # _DEBUG_
	my $typeDef = ($inOut eq 'out')? $fileOut : $fileIn;
	my( $fileType ) = ($typeDef =~ /\.(\w+)(?:\.tmp)?$/g);
	$fileType = lc( $fileType );
	$fileType = 'jpg' if $fileType eq 'jpeg';
	$fileType .= '.' . $inOut;
	my $cmd = $CONV_CMD{$fileType};
	die qq/No command defined for "$fileType"/ if ! $cmd;
	return $cmd;
}

sub runConvCommand {
	my( $fileIn, $fileOut, $inOut ) = @_;
	my $cmd = getConvCommand( $fileIn, $fileOut, $inOut );
	unless( $cmd eq 'NOCONV' ){
		$cmd =~ s/\{IN\}/$fileIn/g;
		$cmd =~ s/\{OUT\}/$fileOut/g;
		print STDERR "CMD: ", $cmd, "\n";  # _DEBUG_
		system $cmd;
	}else{
		$fileIn  =~ s|/|\\|g;
		$fileOut =~ s|/|\\|g;
		my $copyCmd = qq|$CMD_COPY "$fileIn" "$fileOut"|;
		system $copyCmd if $fileIn ne $fileOut;
	}
}

sub convFileType {
	my( $fileIn, $fileOut ) = @_;
	$fileOut = makeOutFileName( $fileOut, $fileIn );
	convertToPnm( $fileIn );
	convertFromPnm( $fileOut );
}

sub makeOutFileName {
	my( $fileOut, $fileIn ) = @_;
	if( $fileOut =~ /^\w+$/ ){
		my $typeDst = $fileOut;
		$fileOut = $fileIn;
		$fileOut =~ s/\.\w+$/.$typeDst/;
		die qq/fileOut == fileIn: $fileOut/ if $fileOut eq $fileIn;
	}
	return $fileOut;
}


sub runConversionPipe {
	my( $fileIn, $cmd, $fileOut, $hOpt ) = @_;
	$fileOut = makeOutFileName( $fileOut, $fileIn );
	my @cmd = split /\s*\|\s*/, $cmd;
	my @tmp = ( $fileIn );
	push @tmp, getTempFileNames( scalar(@cmd) - 1 );
	push @tmp, $fileOut;
	for( my $i = 0; $i <= $#cmd; ++$i ){
		$cmd[$i] = qq/$cmd[$i] "$tmp[$i]" > "$tmp[$i+1]"/;
		print STDERR "CMD: ", $cmd[$i], "\n";  # _DEBUG_
		system $cmd[$i];
	}
	if( $hOpt->{'-del'} ){
		unlink $fileIn;
	}
}




sub getLevelDirectories {
	my( $startDir, $targetLevel ) = @_;
	my( $upDown, @list );
	my( $level ) = ($startDir =~ /(\d+)$/g);
	if( $targetLevel < $level ){
		$upDown = 'down';
		for( my $i = $level; $i >= $targetLevel; --$i ){
			my $dir = $startDir;
			$dir =~ s/\d+$/$i/;
			push @list, $dir;
		}
	}else{
		$upDown = 'up';
		for( my $i = $level; $i <= $targetLevel; ++$i ){
			my $dir = $startDir;
			$dir =~ s/\d+$/$i/;
			push @list, $dir;
		}
	}
	return ( $upDown, @list );
}

sub getTempFileNames {
	my( $num ) = @_;
	my $tp = $TMP_PNM_FILE;
	$tp =~ s/\.(\w+)$/_\%02d.$1/;
	my @tmpFileNames = map {sprintf $tp, $_} (0..($num-1));
	return @tmpFileNames;
}


sub convertMapLevel {
	require OGF::LayerInfo;
	my( $wwInfoDsc, $targetLevel, $aZipList ) = @_;

    my $wwInfo = OGF::LayerInfo->tileInfo( $wwInfoDsc );
#	if( $bbox ){
#		require OGF::View::TileLayer;
#		my $tlr = OGF::View::TileLayer->new( $wwInfoDsc );
#		my $hRange = $tlr->bboxTileRange( $bbox );
#		$wwInfo->{'y'} = $hRange->{'y'};
#		$wwInfo->{'x'} = $hRange->{'x'};
#	}

    $WWINFO_TYPE = $wwInfo->{'type'};
    my( $tileWd, $tileHg ) = $wwInfo->tileSize();
	my( $minY, $maxY, $minX, $maxX, $baseLevel, $orderX, $orderY ) = OGF::LayerInfo->minMaxInfo( $wwInfo->{'layer'}, $wwInfo->{'level'} );
    my $hTileOrder = { order_X => $orderX, order_Y => $orderY };

    my( $upDown, @list );
    if( $targetLevel < $wwInfo->{'level'} ){
        ( $upDown, @list ) = ( 'down', reverse ($targetLevel .. $wwInfo->{'level'}) );
    }elsif( $targetLevel > $wwInfo->{'level'} ){
        ( $upDown, @list ) = ( 'up', $wwInfo->{'level'} .. $targetLevel );
    }else{
        die qq/level == targetLevel, nothing to do/;
    }
    pop @list;

    foreach my $level ( @list ){
        my $hCreated = {};
        OGF::LayerInfo->tileIterator( $wwInfo, sub {
            my( $item ) = @_;
            if( $upDown eq 'down' ){
                OGF::Util::TileLevel::downLevelConcat( $tileWd, $tileHg, $item, $hCreated, $hTileOrder );
            }else{
                OGF::Util::TileLevel::upLevelSplit( $tileWd, $tileHg, $item );
            }
            push @$aZipList, $item->tileName() if $aZipList && $level == $list[0];
        } );
        $wwInfo = $wwInfo->copy( 'level' => $upDown );
        print STDERR $wwInfo->toString(), "\n";

        push @$aZipList, (keys %$hCreated) if $aZipList;
    }
}


sub downLevelConcat {
	my( $wd, $hg, $objIn, $hCreated, $hTileOrder ) = @_;
#	print STDERR "downLevelConcat( $wd, $hg, $fileIn )\n";  # _DEBUG_
	my( $level, $yD, $xD ) = ( $objIn->{'level'}, int($objIn->{'y'}/2), int($objIn->{'x'}/2) );
    my( $dx0, $dx1 ) = ($hTileOrder->{order_X} < 0)? ( 1, 0 ) : ( 0, 1 );
    my( $dy0, $dy1 ) = ($hTileOrder->{order_Y} < 0)? ( 1, 0 ) : ( 0, 1 );

	my $img00 = $objIn->copy( 'y' => $yD*2+$dy0, 'x' => $xD*2+$dx0 )->tileName();
	my $img01 = $objIn->copy( 'y' => $yD*2+$dy0, 'x' => $xD*2+$dx1 )->tileName();
	my $img10 = $objIn->copy( 'y' => $yD*2+$dy1, 'x' => $xD*2+$dx0 )->tileName();
	my $img11 = $objIn->copy( 'y' => $yD*2+$dy1, 'x' => $xD*2+$dx1 )->tileName();

	my $imgOut = $objIn->copy( 'level' => $level-1, 'y' => $yD, 'x' => $xD )->tileName();
	if( $hCreated ){
		return if $hCreated->{$imgOut};
	}else{
		return if -e $imgOut;
	}
	makeFilePath( $imgOut );
	concat4img( $wd, $hg, $img00, $img01, $img10, $img11, $imgOut );
	$hCreated->{$imgOut} = 1;
}

sub upLevelSplit {
	my( $wd, $hg, $objIn ) = @_;
	my( $level, $y0, $x0 ) = ( $objIn->{'level'}, $objIn->{'y'}, $objIn->{'x'} );
	my $img00 = $objIn->copy( 'level' => $level+1, 'y' => $y0*2,   'x' => $x0*2   )->tileName();
	my $img01 = $objIn->copy( 'level' => $level+1, 'y' => $y0*2,   'x' => $x0*2+1 )->tileName();
	my $img10 = $objIn->copy( 'level' => $level+1, 'y' => $y0*2+1, 'x' => $x0*2   )->tileName();
	my $img11 = $objIn->copy( 'level' => $level+1, 'y' => $y0*2+1, 'x' => $x0*2+1 )->tileName();
	makeFilePath( $img00 );
	makeFilePath( $img10 );
	split4img( $wd, $hg, $objIn->tileName(), $img00, $img01, $img10, $img11 );
}


sub concat4img {
	my( $wd, $hg, $img00, $img01, $img10, $img11, $imgOut ) = @_;
	if( $imgOut =~ /\.(bil|terrain)$/ ){
		concat4img_BIL( $wd, $hg, $img00, $img01, $img10, $img11, $imgOut );
		return;
	}
	my @tmp = getTempFileNames( 8 );

	convertToPnm( $img00, $tmp[0], $wd, $hg );
	convertToPnm( $img01, $tmp[1], $wd, $hg );
	convertToPnm( $img10, $tmp[2], $wd, $hg );
	convertToPnm( $img11, $tmp[3], $wd, $hg );

	my $cmd_01 = qq/pnmcat -leftright "$tmp[0]" "$tmp[1]" > "$tmp[4]"/;
	my $cmd_02 = qq/pnmcat -leftright "$tmp[2]" "$tmp[3]" > "$tmp[5]"/;
	my $cmd_03 = qq/pnmcat -topbottom "$tmp[4]" "$tmp[5]" > "$tmp[6]"/;
	my $cmd_SC = qq/$CMD_PNMSCALE -xsize $wd -ysize $hg "$tmp[6]" > "$tmp[7]"/;

	print STDERR "CMD: ", $cmd_01, "\n";  # _DEBUG_
	system $cmd_01;
	print STDERR "CMD: ", $cmd_02, "\n";  # _DEBUG_
	system $cmd_02;
	print STDERR "CMD: ", $cmd_03, "\n";  # _DEBUG_
	system $cmd_03;
	print STDERR "CMD: ", $cmd_SC, "\n";  # _DEBUG_
	system $cmd_SC;

	convertFromPnm( $imgOut, $tmp[7] );
}

sub concat4img_BIL {
	require POSIX;
	require OGF::Util::File;
	require OGF::Terrain::ElevationTile;
	my( $wd, $hg, $img00, $img01, $img10, $img11, $imgOut ) = @_;
#	print STDERR "\$wd <", $wd, ">  \$hg <", $hg, ">  \$img00 <", $img00, ">  \$img01 <", $img01, ">  \$img10 <", $img10, ">  \$img11 <", $img11, ">  \$imgOut <", $imgOut, ">\n"; return; # _DEBUG_
	print STDERR "\$wd <", $wd, ">  \$hg <", $hg, ">  \$imgOut <", $imgOut, ">\n"; # _DEBUG_
	my( $aSet, $bpp, $w2, $h2 ) = ( [], 2, $wd/2, $hg/2 );

	$aSet->[0][0] = OGF::Terrain::ElevationTile::makeArrayFromFile( $img00, $wd, $hg, $bpp, 0 );
	$aSet->[0][1] = OGF::Terrain::ElevationTile::makeArrayFromFile( $img01, $wd, $hg, $bpp, 0 );
	$aSet->[1][0] = OGF::Terrain::ElevationTile::makeArrayFromFile( $img10, $wd, $hg, $bpp, 0 );
	$aSet->[1][1] = OGF::Terrain::ElevationTile::makeArrayFromFile( $img11, $wd, $hg, $bpp, 0 );
	my $aDst = OGF::Terrain::ElevationTile::makeTileArray( 0, $wd, $hg );

	for( my $Y = 0; $Y <= 1; ++$Y ){
		for( my $X = 0; $X <= 1; ++$X ){
			for( my $y = 0; $y < $hg; $y+=2 ){
				for( my $x = 0; $x < $wd; $x+=2 ){
					my $aTile = $aSet->[$Y][$X];
#					print STDERR "\$x <", $x, ">  \$y <", $y, ">  \$x+1 <", ($x+1), ">  \$y+1 <", ($y+1), ">\n";  # _DEBUG_
					my $val = ($aTile->[$y][$x] + $aTile->[$y][$x+1] + $aTile->[$y+1][$x] + $aTile->[$y+1][$x+1] ) / 4;
					$aDst->[$Y*$h2+$y/2][$X*$w2+$x/2] = POSIX::floor( $val + .5 );
				}
			}
		}
	}
	my $dataOut = OGF::Terrain::ElevationTile::makeTileFromArray( $aDst, 2 );
	OGF::Util::File::writeToFile( $imgOut, $dataOut, undef, {-bin => 1} );
}


sub split4img {
	my( $wd, $hg, $imgIn, $img00, $img01, $img10, $img11 ) = @_;
	if( $imgIn =~ /\.(bil|terrain)$/ ){
		die qq/split4img_BIL: !!! NOT IMPLEMENTED !!!/;
		return;
	}
	my @tmp = getTempFileNames( 6 );
	$tmp[0]    = $imgIn                        if getConvCommand($imgIn,'','in')  eq 'NOCONV';
	@tmp[2..5] = ($img00,$img01,$img10,$img11) if getConvCommand('',$img00,'out') eq 'NOCONV';

	convertToPnm( $imgIn, $tmp[0], $wd, $hg );
	my( $wd2, $hg2 ) = ( $wd*2, $hg*2 );
#	my $cmd_SC = qq/$CMD_PNMSCALE -xsize $wd2 -ysize $hg2 "$tmp[0]" > "$tmp[1]"/;
	my $cmd_SC = qq/pamstretch -xscale 2 -yscale 2 "$tmp[0]" > "$tmp[1]"/;

	my $cmd_01 = qq/pamcut -left 0   -top $hg -width $wd -height $hg "$tmp[1]" > "$tmp[2]"/;
	my $cmd_02 = qq/pamcut -left $wd -top $hg -width $wd -height $hg "$tmp[1]" > "$tmp[3]"/;
	my $cmd_03 = qq/pamcut -left 0   -top 0   -width $wd -height $hg "$tmp[1]" > "$tmp[4]"/;
	my $cmd_04 = qq/pamcut -left $wd -top 0   -width $wd -height $hg "$tmp[1]" > "$tmp[5]"/;

	print STDERR "CMD: ", $cmd_SC, "\n";  # _DEBUG_
	system $cmd_SC;

	print STDERR "CMD: ", $cmd_01, "\n";  # _DEBUG_
	system $cmd_01;
	print STDERR "CMD: ", $cmd_02, "\n";  # _DEBUG_
	system $cmd_02;
	print STDERR "CMD: ", $cmd_03, "\n";  # _DEBUG_
	system $cmd_03;
	print STDERR "CMD: ", $cmd_04, "\n";  # _DEBUG_
	system $cmd_04;

	convertFromPnm( $img00, $tmp[2] );
	convertFromPnm( $img01, $tmp[3] );
	convertFromPnm( $img10, $tmp[4] );
	convertFromPnm( $img11, $tmp[5] );
}


sub extractAndResize {
	my( $wd, $hg, $imgIn, $x0, $y0, $dx, $dy, $imgOut, $wdOut, $hgOut ) = @_;
	my @tmp = getTempFileNames( 3 );
	convertToPnm( $imgIn, $tmp[0] );

	if( $dx == $wd && $dy == $hg ){
		my $cmd_01 = qq/$CMD_PNMSCALE -xsize $wdOut -ysize $hgOut "$tmp[0]" > "$tmp[2]"/;
		print STDERR "CMD: ", $cmd_01, "\n";  # _DEBUG_
		system $cmd_01;
	}else{
		my $cmd_01 = qq/pamcut -left $x0 -top $y0 -width $dx -height $dy "$tmp[0]" > "$tmp[1]"/;
		my $cmd_02 = qq/$CMD_PNMSCALE -xsize $wdOut -ysize $hgOut "$tmp[1]" > "$tmp[2]"/;
		print STDERR "CMD: ", $cmd_01, "\n";  # _DEBUG_
		system $cmd_01;
		print STDERR "CMD: ", $cmd_02, "\n";  # _DEBUG_
		system $cmd_02;
	}

	makeFilePath( $imgOut );
	convertFromPnm( $imgOut, $tmp[2] );
}



sub runProcess {
	my( $cmd, $hOpt ) = @_;
	my $mode = 'WScript.exec';
	$cmd =~ s/\s+$//;
	$mode = 'WScript' if $mode eq 'Default';
	$hOpt = {} if !defined $hOpt;
	my $ret;
	if( $mode =~ /^WScript/ ){
		require Win32::OLE;
		my $windowStyle = (defined $hOpt->{windowStyle})? $hOpt->{windowStyle} : 1;
		my $wsh = Win32::OLE->new( 'WScript.Shell' );
		my $ret = ($mode eq 'WScript.exec')? $wsh->exec($cmd) : $wsh->run($cmd,$windowStyle,0);
		my $lastError = Win32::OLE->LastError();
		if( $lastError ){
			exception( qq/runProcess (WScript.Shell):\n> $cmd\n\n$lastError/ );
		}
	}else{
		system $cmd;
	}
	return $ret;
}




1;

