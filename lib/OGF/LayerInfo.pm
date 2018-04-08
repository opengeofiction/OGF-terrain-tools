package OGF::LayerInfo;
use strict;
use warnings;
use File::Spec;
use File::Copy qw( move );
use OGF::Const;
use OGF::Util::File qw( readFromFile writeToFile );


our( $NO_ELEV_VALUE, $T_WIDTH, $T_HEIGHT, $BPP ) = ( -30001, 512, 512, 2 );


our $PATH_PREFIX = $OGF::LAYER_PATH_PREFIX;
our $TASK_PROCESSING_LIST    = $PATH_PREFIX . '/Common/TaskService/list.txt';
our $GENERATOR_CACHE_DIR     = $PATH_PREFIX . '/Common/Cache';
our %ITERATOR_OPTS           = ();


our %INFO_MAP = (
    'DEFAULT' => {
        'tile'  => [ '%d/%04d/%04d_%04d.%s', 'level', 'y', 'y', 'x', 'suffix' ],
        'image' => {
            'baseDir'  => [ $PATH_PREFIX.'/%s/WW_1200', 'layer' ],
            'suffix'   => 'png',
            'valEmpty' => [ 255, 255, 255 ],
        },
        'phys' => {
            'baseDir'  => [ $PATH_PREFIX.'/%s/WW_phys', 'layer' ],
        },
        'graymap' => {
            'baseDir'  => [ $PATH_PREFIX.'/%s/WW_graymap', 'layer' ],
            'suffix'   => 'pgm',
            'valEmpty' => $NO_ELEV_VALUE,
        },
        'elev' => {
#           'baseDir'  => [ $PATH_PREFIX.'/WorldWind_Cache/Cache/Earth/SRTM/%sElev', 'layer' ],
#           'baseDir'  => [ $PATH_PREFIX.'/NASA/World Wind 1.4/Cache/Earth/SRTM/%s-elev', 'layer' ],
            'baseDir'  => [ $PATH_PREFIX.'/%s/WW_elev', 'layer' ],
            'suffix'   => 'bil',
            'valEmpty' => 0,
        },
        'contour' => {
            'baseDir'  => [ $PATH_PREFIX.'/%s/WW_contour', 'layer' ],
            'suffix'   => 'cnr',
            'valEmpty' => $NO_ELEV_VALUE,
        },
        'stream' => {
            'baseDir'  => [ $PATH_PREFIX.'/%s/WW_contour', 'layer' ],
            'suffix'   => 'stm',
            'valEmpty' => $NO_ELEV_VALUE,
        },
        'water' => {
            'baseDir'  => [ $PATH_PREFIX.'/%s/WW_contour', 'layer' ],
            'suffix'   => 'wat',
            'valEmpty' => $NO_ELEV_VALUE,
        },
        'relief' => {
            'baseDir'  => [ $PATH_PREFIX.'/%s/WW_relief', 'layer' ],
            'suffix'   => 'png',
            'valEmpty' => [ 255, 255, 255 ],
        },
        'vector' => {
            'baseDir'  => [ $PATH_PREFIX.'/%s/WW_vector', 'layer' ],
            'suffix'   => 'txt',
        },
    },
    'WebWW' => {
        'tile'     => [ '%d/%d/%d_%d.%s', 'level', 'y', 'y', 'x', 'suffix' ],
        'size'     => [ 256, 256 ],
#       'minMax'   => { baseLevel => 2, min_Y => 0, max_Y => 3, min_X => 0, max_X => 7 },
        'minMax'   => { baseLevel => 0, min_Y => 0, max_Y => 3, min_X => 0, max_X => 7, order_X => 1, order_Y => -1 },
        'image' => {
            'baseDir'  => [ $PATH_PREFIX.'/OGF/WW_elev_02' ],
        },
        'phys' => {
            'baseDir'  => [ $PATH_PREFIX.'/OGF/WW_phys_02' ],
        },
        'elev' => {
            'baseDir'  => [ $PATH_PREFIX.'/OGF/WW_elev_02' ],
            'suffix'   => 'bil',
            'valEmpty' => 0,
        },
    },
    'Roantra' => {
        'size'     => [ 512, 512 ],
        'minMax'   => { baseLevel => 0, maxLevel => 4, min_Y => 47, max_Y => 49, min_X => 55, max_X => 57 },
        'image' => {
            'baseDir' => [ $PATH_PREFIX.'/%s/WW', 'layer' ],
        },
        'elev' => {
            'baseDir'  => [ $PATH_PREFIX.'/Roantra/WW_elev' ],
            'suffix'   => 'bil',
            'valEmpty' => 0,
        },
    },
    'Cearno' => {
        'image' => {
            'baseDir' => [ $PATH_PREFIX.'/%s/WW', 'layer' ],
        },
    },
    'Larraincon' => {
        'image' => {
            'baseDir' => [ $PATH_PREFIX.'/%s/WW_600', 'layer' ],
        },
    },
    'OGF' => {
        'size'     => [ 256, 256 ],
        'minMax'   => { baseLevel => 0, maxLevel => 19, min_Y => 0, max_Y => 0, min_X => 0, max_X => 0 },
        'proj4'    => '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs',
        'tile'     => [ '%d/%d/%d.%s', 'level', 'x', 'y', 'suffix' ],
        'image' => {
            'baseDir'  => [ 'http://tile.opengeofiction.net/osmcarto' ],
#           'baseDir'  => [ '/opt/osm/Map/Common/Cache/opengeofiction.net/osmcarto' ],
        },
        'phys' => {
            'baseDir'  => [ $PATH_PREFIX.'/OGF/WW_phys' ],
            'tile'     => [ '%d/%04d/%04d_%04d.%s', 'level', 'y', 'y', 'x', 'suffix' ],
        },
        'elev' => {
            'baseDir'  => [ $PATH_PREFIX.'/OGF/WW_elev' ],
            'tile'     => [ '%d/%d/%d_%d.%s', 'level', 'y', 'y', 'x', 'suffix' ],
        },
    },
    'OGFT' => {
        'baseDir' => [ 'http://tile.opengeofiction.net/topomap' ],
        'tile'    => [ '%d/%d/%d.%s', 'level', 'x', 'y', 'suffix' ],
        'size'    => [ 256, 256 ],
        'minMax'  => { baseLevel => 0, maxLevel => 16, min_Y => 0, max_Y => 0, min_X => 0, max_X => 0 },
        'proj4'   => '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs',
    },
    'OGFR' => {
        'baseDir' => [ 'http://tile.opengeofiction.net/planet/Roantra' ],
        'tile'    => [ '%d/%d/%d.%s', 'level', 'x', 'y', 'suffix' ],
        'size'    => [ 256, 256 ],
        'minMax'  => { baseLevel => 0, maxLevel => 14, min_Y => 0, max_Y => 0, min_X => 0, max_X => 0 },
        'proj4'   => '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs',
    },
    'OTM' => {
        'baseDir' => [ 'https://%s.tile.opentopomap.org', randValue('a','b','c') ],
        'tile'    => [ '%d/%d/%d.%s', 'level', 'x', 'y', 'suffix' ],
        'size'    => [ 256, 256 ],
        'minMax'  => { baseLevel => 0, maxLevel => 17, min_Y => 0, max_Y => 0, min_X => 0, max_X => 0 },
        'proj4'   => '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs',
    },
    'Cesium' => {  # elev only
        'baseDir'  => [ $PATH_PREFIX.'/OGF/Cesium_elev' ],
        'tile'     => [ '%d/%d/%d.terrain', 'level', 'x', 'y', 'suffix' ],
        'suffix'   => 'terrain',
        'valEmpty' => 0,
        'minMax'   => { baseLevel => 0, min_Y => 0, max_Y => 0, min_X => 0, max_X => 1 },
        'size'     => [ 64, 64 ],
    },
    'DYNAMIC' => {
        'minMax'  => { baseLevel => 0, min_Y => 0, max_Y => 0, min_X => 0, max_X => 0 },
    },
    'SathriaLCC' => {
        'transform' => {
#           'X' => [-1623435.18586881, 0, 1297358.0927498,  54242 ],
#           'Y' => [ 6008235.49623158, 0, 3351155.95016265, 49344 ],
            'X' => [-1623435.18586881, 0, 1297358.0927498,  1695.0625 ],
            'Y' => [ 6008235.49623158, 0, 3351155.95016265, 1542 ],
        },
        'mapScale' => 200000,
        'minMax'   => { baseLevel => 0, min_Y => 0, max_Y => 1, min_X => 0, max_X => 1, order_X => 1, order_Y => 1 },
        'size'     => [ 1024, 1024 ],
        'proj4'    => '+proj=lcc +lat_1=32.5 +lat_2=46.5 +lon_0=43 +x_0=0 +y_0=0',
        'elev' => {
            'baseDir'  => [ $PATH_PREFIX.'/Sathria/elev' ],
            'tile'     => [ '%d/%d/%d_%d.%s', 'level', 'y', 'y', 'x', 'suffix' ],
            'suffix'   => 'bil',
        },
    },
    'Paxtar' => {
        'size'     => [ 1024, 1024 ],
        'minMax'   => { baseLevel => 0, maxLevel => 19, min_Y => 0, max_Y => 7, min_X => 0, max_X => 7, order_X => 1, order_Y => 1 },
        'proj4'    => '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs',
        'tile'     => [ '%d/%d/%d.%s', 'level', 'x', 'y', 'suffix' ],
        'elev' => {
            'baseDir'  => [ $PATH_PREFIX.'/Paxtar/elev' ],
            'tile'     => [ '%d/%d/%d.%s', 'level', 'x', 'y', 'suffix' ],
        },
        'transform' => {
            'X' => [  2046411.1508409,  0, 4284199.51430543, 8192 ],
            'Y' => [ -3875764.20684828, 0, -6113552.57031249, 8192 ],
        },
    },
#    'SathriaEck4' => {
#        'definitionFile' => $PATH_PREFIX.'/OGF/work/eck4_Sathria_elev.cpx',
#        'transform' => {
#           'X' => [-8460601.461472, 5000,   8460601.461472, 15000 ],
#           'Y' => [ 8460601.461472,    0,  -8460601.461472, 10000 ],
#        },
#        'minMax'   => { baseLevel => 0, min_Y => 0, max_Y => 1, min_X => 0, max_X => 1, order_X => 1, order_Y => 1 },
#        'size'     => [ 1600, 1600 ],
#        'proj4'    => '+proj=eck4 +lon_0=44 +x_0=0 +y_0=0',
#    },
);



our @LAYERS   = qw/ Roantra Cearno Larraincon /;
our @SUFFIXES = map {$_->{'suffix'}} grep {ref($_) eq 'HASH'} values %{$INFO_MAP{'DEFAULT'}};



sub layerInfo {
	my( $info, $attr, $optional ) = @_;
	if( ! defined $info->{'type'} ){
		die qq/LayerInfo::layerInfo: Cannot determine type of info object {/, join('|',%$info), "}";
	}
	my( $layer, $type ) = ( $info->{'layer'}, $info->{'type'} );

#	my $hInfoMap = $INFO_MAP{$type};
#	die qq/LayerInfo::layerInfo: unknown type "$type"/ if ! $hInfoMap;
#	$val = (defined $hInfoMap->{$layer}{$attr})? $hInfoMap->{$layer}{$attr} : $hInfoMap->{'DEFAULT'}{$attr};
#	die qq/LayerInfo::layerInfo: no DEFAULT value for attribute "$attr"/ if !defined $val;

	my $val = $INFO_MAP{$layer}{$type}{$attr};
	$val = $INFO_MAP{$layer}{$attr}           if !defined $val;
	$val = $INFO_MAP{'DEFAULT'}{$type}{$attr} if !defined $val;
	$val = $INFO_MAP{'DEFAULT'}{$attr}        if !defined $val;
	if( !defined $val && !$optional ){
		OGF::Util::printStackTrace();
		die qq/LayerInfo::layerInfo:cannot determine value for attribute "$layer.$type.$attr"/;
	}

	return $val;
}

sub tileSize {
	my( $info ) = @_;
	my( $layer, $type ) = ( $info->{'layer'}, $info->{'type'} );
	my $size = $info->{'tileSize'} || $info->{'scale'} || $info->layerInfo( 'size' );
	return @$size;
}

sub tileName {
	my( $info ) = @_;
	my $pkg = ref( $info );
	$info = $pkg->tileInfo( $info );
	$info->{'suffix'} = $info->layerInfo( 'suffix' );
	my( $baseDir, @dirAttr ) = @{ $info->layerInfo('baseDir') };
	my( $tile, @tileAttr )   = @{ $info->layerInfo('tile') };
	my $tileName = sprintf $baseDir .'/'. $tile, map {(ref($_) eq 'CODE')? $_->() : $info->{$_}} ( @dirAttr, @tileAttr );
#	print STDERR "\$tileName <", $tileName, ">\n";  # _DEBUG_
	return $tileName;
}

sub randValue {
	my( $n, @val ) = ( scalar(@_), @_ );
	my $cSub = sub {
		return $val[int(rand($n))];
	};
	return $cSub;
}

sub tileData {
	my( $info, $file ) = @_;
	$file = $info->tileName() if ! $file;
	my $data = (-f $file)? readFromFile($file,{-bin => 1}) : undef;
	if( ! $data ){
		require OGF::Terrain::ElevationTile;
		my $valEmpty = $info->layerInfo( 'valEmpty' );
		$data = OGF::Terrain::ElevationTile::getEmptyTile( $valEmpty );
	}
	return $data;
}

sub tileArray {
	my( $info, $file ) = @_;
	$file = $info->tileName() if ! $file;
	my( $wdT, $hgT ) = $info->tileSize();
	my $aTile;
	if( $file =~ /\.(png|jpg)$/ ){
#		die qq/tileArray: not implemented for type "image"/;
		require OGF::Util::PPM;
		require OGF::Util::TileLevel;
		my( $tmpFile ) = OGF::Util::TileLevel::getTempFileNames( 1 );
		OGF::Util::TileLevel::convertToPnm( $file, $tmpFile, $wdT, $hgT );
		$aTile = OGF::Util::PPM->new( $tmpFile, {-loadData => 1} )->{'data'};
	}else{
		require OGF::Terrain::ElevationTile;
		my $data = $info->tileData( $file );
		$aTile = OGF::Terrain::ElevationTile::makeArrayFromTile( $data, $wdT, $hgT, $BPP );
	}
	return $aTile;
}

sub tileNameGenerated {
	my( $info, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my $file = $info->tileName();

	$file = cachedUrlTile($file,$hOpt) if $file =~ /^https?:/;
#	print STDERR "A \$file <", $file, ">\n";  # _DEBUG_
#	print STDERR "\$info->{'scale'} <", $info->{'scale'}, ">\n";  # _DEBUG_
	return $file if -f $file && ! $info->{'scale'};

	my $flag = $hOpt->{'nocache'} ? 0 : 1;

	my( $type, $layer, $level, $y, $x, $suffix ) = $info->getAttr( 'type', 'layer', 'level', 'y', 'x', 'suffix' );
	$flag = 0 unless $type =~ /^(?:image|phys|relief|graymap)$/;

	my $maxLevel = $info->levelInfo()->{'maxLevel'};
	my( $minY, $maxY, $minX, $maxX ) = $info->minMaxInfo( $layer, $level );
	$flag = 0 unless $level <= $maxLevel+9 && $y >= $minY && $y <= $maxY && $x >= $minX && $x <= $maxX;
#	print STDERR "\$flag <", $flag, ">\n";  # _DEBUG_

	my( $scX, $scY, $centerY, $pxSize ) = $info->{'scale'} ? @{$info->{'scale'}} : ($T_WIDTH,$T_HEIGHT,0,0);

#	$file = sprintf '%s/%s/%s/%s/%d/%04d/%04d_%04d.%s', $GENERATOR_CACHE_DIR, $layer, "$scX,$scY", $type, $level, $y, $y, $x, $suffix; 
#	$file = sprintf '%s/%s/%s/%s/%d/%04d/%04d_%04d.%s', $GENERATOR_CACHE_DIR, $layer, "$centerY,$pxSize", $type, $level, $y, $y, $x, $suffix; 
	$file =~ s|^.*?\Q/$level/|$GENERATOR_CACHE_DIR/$layer/$centerY,$pxSize/$type/$level/| if $info->{'scale'};
#	print STDERR "B \$file <", $file, ">\n";  # _DEBUG_
	if( $flag && ! -f $file ){
		my $dL2 = ($level > $maxLevel)? (2 ** ($level - $maxLevel)) : 1;
		my( $baseY, $baseX ) = ( int($y/$dL2), int($x/$dL2) );
		my $baseFile = $info->copy( 'level' => (($level > $maxLevel)? $maxLevel : $level), 'y' => $baseY, 'x' => $baseX )->tileName();
		$baseFile =~ s|^https?://([a-z]\.)?|$GENERATOR_CACHE_DIR/|;
		print STDERR "\$baseFile <", $baseFile, ">\n";  # _DEBUG_
		if( -f $baseFile ){		
			my( $sizeY, $sizeX ) = ( $T_HEIGHT/$dL2, $T_WIDTH/$dL2 );
			my( $posY, $posX ) = ( $T_HEIGHT - ($y+1 - $baseY*$dL2)*$sizeY, ($x - $baseX*$dL2 )*$sizeX );
			require OGF::Util::TileLevel;
			OGF::Util::TileLevel::extractAndResize( $T_WIDTH,$T_HEIGHT, $baseFile, $posX,$posY, $sizeX,$sizeY, $file, $scX,$scY );
		}
	}
	return $file;
}

sub tileDataGenerated {
	my( $info ) = @_;
	my $file = $info->tileNameGenerated();
	my $data = (-f $file)? readFromFile($file,{-bin => 1}) : undef;
	return $data;
}

sub cachedUrlTile {
	require LWP::UserAgent;
	my( $url, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
#	print STDERR "\$url <", $url, ">\n";  # _DEBUG_

	my $outFile = $url;
	$outFile =~ s|^https?://([a-z]\.)?|$GENERATOR_CACHE_DIR/|;
	return $outFile if -f $outFile || $hOpt->{'nocache'};

	my( $suffix ) = ($url =~ /\.(\w+)$/g);
	my $userAgent = LWP::UserAgent->new();
	print STDERR "GET $url\n";
	my $resp = $userAgent->get( $url, 'Content_Type' => "image/$suffix" );
	if( ! $resp->is_success ){
		warn $resp->status_line;
		return undef;
	}

	writeToFile( "$outFile.tmp", $resp->content, '>', {-bin => 1, -mdir => 1} );
	move( "$outFile.tmp", $outFile );
	return $outFile;
}



our %TILE_CACHE = ();

sub cachedTileArray {
	my( $pkg, $key, $aExtend ) = @_;
	if( ! $TILE_CACHE{$key} ){
		my $info = $pkg->tileInfo( $key );
		my $aTile = $info->tileArray();
		if( $aExtend ){
			my( $y0, $x0 ) = $info->getAttr( 'y', 'x' );
			my( $extY, $extX ) = @$aExtend;
			my( $aExtY, $aExtX, $aExtXY ) = (
				$info->copy( 'y' => $y0+1 )->tileArray(),
				$info->copy( 'x' => $x0+1 )->tileArray(),
				$info->copy( 'y' => $y0+1, 'x' => $x0+1 )->tileArray(),
			);
			for( my $y = 0; $y < $extY; ++$y ){
				$aTile->[$T_HEIGHT+$y] = [];
				for( my $x = 0; $x < $T_WIDTH; ++$x ){
					$aTile->[$T_HEIGHT+$y][$x] = $aExtXY->[$y][$x];
				}
			}
			for( my $y = 0; $y < $T_HEIGHT; ++$y ){
				for( my $x = 0; $x < $extX; ++$x ){
					$aTile->[$y][$T_HEIGHT+$x] = $aExtXY->[$y][$x];
				}
			}
			for( my $y = 0; $y < $extY; ++$y ){
				for( my $x = 0; $x < $extX; ++$x ){
					$aTile->[$T_HEIGHT+$y][$T_HEIGHT+$x] = $aExtXY->[$y][$x];
				}
			}
		}
		$TILE_CACHE{$key} = $aTile;
	}
	return $TILE_CACHE{$key};
}



sub tileInfo {
	my( $pkg, $info ) = @_;
#	print STDERR "LayerInfo::tileInfo <", $info, ">\n";
	if( ref($info) ){
		# do nothing
	}elsif( $info =~ /^list=(.*)/ ){
		my $listFile = $1;
		$info = { 'list' => $pkg->parseListFile($listFile) };
		bless $info, $pkg;
	}elsif( $info =~ /\d+_\d+\.[a-z]+$/ ){
		$info = File::Spec->rel2abs( $info );
		$info =~ s|\\|/|g;
		my $reSuffix = join( '|', @SUFFIXES );
		my $reLayer  = join( '|', @LAYERS );
		if( $info =~ m|($reLayer).*/(\d+)/\d+/(\d+)_(\d+)\.($reSuffix)$| ){
			$info = {
				'level'  => $2,
				'y'      => 0+$3,
				'x'      => 0+$4,
				'suffix' => $5,
			};
			bless $info, $pkg;
			$info->{'type'} = $info->layerInfo( 'type' );
		}else{
			die qq/LayerInfo::tileInfo: cannot parse file name "$info"/;
		}
	}else{
		my @attrs = split /:/, $info;
		die qq/LayerInfo::tileInfo: invalid info object: $info/ if scalar(@attrs) < 4;
		$info = {
			'type'  => $attrs[0],
			'layer' => $attrs[1],
			'level' => $attrs[2],
		};
		my $range = $attrs[3];
		bless $info, $pkg;
		if( $attrs[3] =~ /^(\*|\d+|\d+\-\d+)$/ && $attrs[4] =~ /^(\*|\d+|\d+\-\d+)$/ ){
            $range = "$attrs[3]:$attrs[4]";
			my( $rangeY, $rangeX ) = ( $attrs[3], $attrs[4] );
			( $info->{'y'}, $info->{'x'} ) = $pkg->parseRange( $info->{'layer'}, $info->{'level'}, $rangeY, $rangeX );
            splice @attrs, 4, 1;
		}elsif( $range =~ /^(all|random)$/ ){
			( $info->{'y'}, $info->{'x'} ) = $pkg->parseRange( $info->{'layer'}, $info->{'level'}, '*', '*' );
			$info->{'random'} = 1 if $attrs[3] eq 'random';
		}elsif( $range =~ /^bbox=([-,.\w]+)$/ ){
			my $bbox = $1;
			require OGF::View::TileLayer;
			my $tlr = OGF::View::TileLayer->new( $info );
			my $hRange = $tlr->bboxTileRange( $bbox );
			$info->{'y'} = $hRange->{'y'};
			$info->{'x'} = $hRange->{'x'};
		}elsif( $range =~ /^dir=([-.\\\/\w]+)$/ ){
			my $dir = $1;
			if( -d $dir ){
				( $info->{'y'}, $info->{'x'} ) = $pkg->directoryRange( $info->{'layer'}, $info->{'level'}, $dir );
			}else{
				warn qq/No such directory: $dir/;
				return undef;
			}
		}elsif( $range =~ /^scan=(\w+)$/ ){   # obsolete
			my $scanTag = $1;
			( $info->{'y'}, $info->{'x'} ) = $pkg->scanRange( $info->{'layer'}, $info->{'level'}, $scanTag );
		}else{
			warn qq/LayerInfo::tileInfo: invalid selection descriptor "$range"/;
			return undef;
		}
		for( my $i = 4; $i <= $#attrs; ++$i ){
			if( $attrs[$i] =~ /^(\w+)=(.*)/ ){
				my( $opt, $val ) = ( $1, $2 );
#				$val = [ split /,/, $val ] if $val =~ /^[.\d]+,([.\d]+,)*[.\d]+$/; 
				$val = [ split /,/, $val ] if $val =~ /^[-.\d]+,([-.\d]+,)*[-.\d]+$/; 
				$info->{$opt} = $val;
			}
		}		
	}
	$info->convertOptions();
	return $info;
}

sub convertOptions {
	my( $info, $tagProj, $tagScale ) = @_;
	if( $info->{'proj'} ){
		my $layer = $info->{'layer'};
		if( $info->layerInfo('proj4','opt') ){
			my( $centerY, $pxSize ) = @{$info->{'proj'}};
			my( $cLon, $cLat ) = makeProjectionInfo( $centerY, $pxSize );
			my $tileLon = 360 / (2 ** $info->{'level'});
			my $sizeX = int( $tileLon * $cLon + .5 );
			$info->{'scale'} = [ $sizeX, $sizeX, $centerY, $pxSize ];
		}else{
			my $tileSize = 180 / (2 ** $info->{'level'});
			my( $centerY, $pxSize ) = @{$info->{'proj'}};
			my( $cLon, $cLat ) = makeProjectionInfo( $centerY, $pxSize );
			my( $sizeX, $sizeY ) = ( int($tileSize * $cLon + .5), int($tileSize * $cLat + .5) );
#			print STDERR "\$sizeX <", $sizeX, ">  \$sizeY <", $sizeY, ">\n";  # _DEBUG_
			$info->{'scale'} = [ $sizeX, $sizeY, $centerY, $pxSize ];
		}
	}
}

sub makeProjectionInfo {
	my( $centerY, $pxSize ) = @_;
	my $pi = atan2( 0, -1 );
	my $phiY = $centerY * $pi / 180;
#	print STDERR "\$phiY <", $phiY, ">\n";  # _DEBUG_

	my( $radAeq, $radPol ) = ( 6_378_137, 6_356_752.314 );
	my $rE2 = 1 - (($radPol ** 2) / ($radAeq ** 2));
#	print STDERR "\$rE <", $rE, ">\n";  # _DEBUG_
	my( $rM, $rN ) = ( $radAeq*(1 - $rE2) / (1 - $rE2 * sin($phiY)**2)**1.5, $radAeq / sqrt(1 - $rE2 * sin($phiY)**2) );
#	print STDERR "\$rM <", $rM, ">  \$rN <", $rN, ">\n";  # _DEBUG_

	my $dgLon = $rN * cos($phiY) * $pi / 180 / $pxSize;
	my $dgLat = $rM * $pi / 180 / $pxSize;
#	print STDERR "\$dgX <", $dgX, ">  \$dgY <", $dgY, ">\n";  # _DEBUG_

	return ( $dgLon, $dgLat );
}

sub getProjectionParameters {
	my( $info ) = @_;
	my( $layer, $level, $aScale ) = map {$info->{$_}} qw/layer level scale/;
	my( $minY, $maxY, $minX, $maxX ) = OGF::LayerInfo->minMaxInfo( $layer, $level );
	print STDERR "\$minY <", $minY, ">  \$maxY <", $maxY, ">  \$minX <", $minX, ">  \$maxX <", $maxX, ">\n";  # _DEBUG_

	if( $info->layerInfo('proj4','opt') ){
		require Geo::Proj4;
		my $proj = Geo::Proj4->new( $info->layerInfo('proj4') );
		# $proj->forward( 85.0511287798066, 180 ) -> ( 20037508.3427892, 20037508.3427892 );
		my( $worldWd, $worldHg ) = map {$_ * 2**$level} $info->tileSize();
		my $worldConst = 2 * 20037508.3427892;
		my( $pxSizeX, $pxSizeY ) = ( $worldConst/$worldWd, $worldConst/$worldHg );
		my( $x0, $y0 ) = ( $worldWd/2, $worldHg/2 ); 
		return ( $proj, $pxSizeX, $pxSizeY, $x0, $y0 );
	}else{
#		my( $wdT, $hgT ) = $aScale ? @$aScale : (512,512);
		my( $wdT, $hgT ) = $aScale ? @$aScale : (256,256);
		my $tileSize = 180 / (2 ** $level);
		print STDERR "\$minY <", $minY, ">  \$maxY <", $maxY, ">  \$minX <", $minX, ">  \$maxX <", $maxX, ">  \$wdT <", $wdT, ">  \$hgT <", $hgT, ">  \$tileSize <", $tileSize, ">\n";  # _DEBUG_

#		my( $centerY, $pxSize ) = $aScale ? ($aScale->[2],$aScale->[3]) : (0,$tileSize/$hgT .' deg');
		my( $centerY, $pxSizeX, $pxSizeY ) = ( $aScale ? $aScale->[2] : 0, $tileSize/$wdT .' deg', $tileSize/$hgT .' deg' );
		my $minLat = $minY * $tileSize -  90;
		my $minLon = $minX * $tileSize - 180;
		my $maxLat = ($maxY + 1) * $tileSize -  90;
		my $maxLon = ($maxX + 1) * $tileSize - 180;
		print STDERR "A \$minLon <", $minLon, ">  \$maxLon <", $maxLon, ">  \$minLat <", $minLat, ">  \$maxLat <", $maxLat, ">\n";  # _DEBUG_
		return ( $pxSizeX, $pxSizeY, $centerY, $minLon, $maxLon, $minLat, $maxLat );
	}
}

sub parseListFile {
	my( $pkg, $file ) = @_;
	my( @list, %dup );
	local *FILE;
	open( FILE, $file ) or die qq/Cannot open "$file": $!\n/;
	while( <FILE> ){
		chomp;
		my( $dsc ) = grep {/:/} split /\s+/, $_;
		next if $dup{$dsc};
		push @list, $pkg->tileInfo( $dsc );
		$dup{$dsc} = 1;
#		print STDERR "\$dsc <", $dsc, ">\n";  # _DEBUG_
	}
	close FILE;
	return \@list;
}


sub copy {
	my( $info, %attrs ) = @_;
	my $infoNew = { %$info };
	bless $infoNew, ref($info);
	foreach my $key ( keys %attrs ){
		if( $key eq 'level' && $attrs{$key} =~ /^(up|down)$/i ){
			my $upDown = $1;
			$infoNew->setLevelConv( $upDown, $info );
		}else{
			$infoNew->{$key} = $attrs{$key};
		}
	}
	$infoNew->convertOptions();
	return $infoNew;
}

sub setLevelConv {
	my( $info, $upDown, $infoSrc ) = @_;
	my( $level, $y, $x ) = $infoSrc->getAttr( 'level', 'y', 'x' );
	if( $upDown eq 'up' ){
		$info->{'level'} = $level + 1;
		$info->{'y'} = ref($y)? [$y->[0]*2,$y->[1]*2+1] : [$y*2,$y*2+1];
		$info->{'x'} = ref($x)? [$x->[0]*2,$x->[1]*2+1] : [$x*2,$x*2+1];
	}else{
		$info->{'level'} = $level - 1;
		$info->{'y'} = ref($y)? [int($y->[0]/2),int($y->[1]/2)] : int($y/2);
		$info->{'x'} = ref($x)? [int($x->[0]/2),int($x->[1]/2)] : int($x/2);
	}
}



sub getAttr {
	my( $info, @attr ) = @_;
	my @val;
	foreach my $attr ( @attr ){
		my $val;
		if( $attr =~ s/^:// ){
			next if ! defined( $info->{$attr} );
			$val = $info->{$attr};
			$val = join(',', @$val) if ref($val);
			$val = "$attr=$val";
		}else{
			$val = $info->{$attr};
#			$val = join(',', @$val) if ref($val);
		}
		push @val, $val;
	}
	return @val;
}

sub toString {
	my( $info ) = @_;
#	my $str = join ':', $info->getAttr(qw/ type layer level y x :scale /);
	my @attr = $info->getAttr(qw/ type layer level y x :scale /);
	$attr[3] = $attr[3][0] .'-'. $attr[3][1] if ref($attr[3]);
	$attr[4] = $attr[4][0] .'-'. $attr[4][1] if ref($attr[4]);
	my $str = join( ':', @attr );
#	print STDERR "\$str <", $str, ">\n";  # _DEBUG_
	return $str;
}

sub levelInfo {
	my( $info ) = @_;
#	my $hMinMax = $INFO_MAP{'image'}{$layer}{'minMax'} ? $INFO_MAP{'image'}{$layer}{'minMax'} : OGF::LayerInfo::getPlugin($layer)->minMaxInfo();
	my $hMinMax = $info->layerInfo( 'minMax' );
	$hMinMax->{'maxLevel'} = $hMinMax->{'baseLevel'} if !exists $hMinMax->{'maxLevel'};
	return $hMinMax;
}

sub minMaxInfo {
	my( $pkg, $layer, $level ) = @_;
#	my $hMinMax = $INFO_MAP{'image'}{$layer}{'minMax'} ? $INFO_MAP{'image'}{$layer}{'minMax'} : OGF::LayerInfo::getPlugin($layer)->minMaxInfo();
	my $hMinMax = layerInfo( {'layer' => $layer, 'type' => '---'}, 'minMax' );
	my( $baseLevel, $minY, $maxY, $minX, $maxX ) = map {$hMinMax->{$_}} qw/ baseLevel min_Y max_Y min_X max_X /;
	if( $level == $baseLevel ){
		# do nothing
	}elsif( $level < $baseLevel ){
		my $diffFactor = 2 ** ($baseLevel - $level);
		$minY = int( $minY / $diffFactor );
		$maxY = int( $maxY / $diffFactor );
		$minX = int( $minX / $diffFactor );
		$maxX = int( $maxX / $diffFactor );
	}elsif( $level > $baseLevel ){
		my $diffFactor = 2 ** ($level - $baseLevel);
		$minY = $minY * $diffFactor;
		$maxY = $maxY * $diffFactor + $diffFactor - 1;
		$minX = $minX * $diffFactor;
		$maxX = $maxX * $diffFactor + $diffFactor - 1;
	}
#	print STDERR "\$minY <", $minY, ">  \$maxY <", $maxY, ">  \$minX <", $minX, ">  \$maxX <", $maxX, ">  \$baseLevel <", $baseLevel, ">\n";  # _DEBUG_
	if( $hMinMax->{'order_X'} ){
		return ( $minY, $maxY, $minX, $maxX, $baseLevel, $hMinMax->{'order_X'}, $hMinMax->{'order_Y'} );
	}else{
		return ( $minY, $maxY, $minX, $maxX, $baseLevel, 1, 1 );
	}
}

sub parseRange {
	my( $pkg, $layer, $level, $rangeY, $rangeX ) = @_;
	if( $rangeX =~ /^\d+$/ && $rangeY =~ /^\d+$/ ){
		( $rangeX, $rangeY ) = ( 0+$rangeX, 0+$rangeY );
	}else{
		if( $rangeX eq '*' ){
			my( $minY, $maxY, $minX, $maxX ) = $pkg->minMaxInfo( $layer, $level );
			$rangeX = [ $minX, $maxX ];
		}elsif( $rangeX =~ /^(\d+)\-(\d+)$/ ){
			$rangeX = [ $1, $2 ];
		}elsif( $rangeX =~ /^\d+$/ ){
			$rangeX = [ $rangeX, $rangeX ];
		}
		if( $rangeY eq '*' ){
			my( $minY, $maxY, $minX, $maxX ) = $pkg->minMaxInfo( $layer, $level );
			$rangeY = [ $minY, $maxY ];
		}elsif( $rangeY =~ /^(\d+)\-(\d+)$/ ){
			$rangeY = [ $1, $2 ];
		}elsif( $rangeY =~ /^\d+$/ ){
			$rangeY = [ $rangeY, $rangeY ];
		}
	}
	return ( $rangeY, $rangeX );
}

sub scanRange {
	my( $pkg, $layer, $level, $scanTag ) = @_;

	my $tileSize = 180 / (2 ** $level);
	#print STDERR "\$tileSize <", $tileSize, ">\n";  # _DEBUG_

	my $pxSize = $tileSize / 512;
	my $plugin = OGF::LayerInfo::getPlugin( $layer );
#	my $scanPxSize = ('45.3565786345947' - '44.8400757371395') / (13599 - 34);  # from roa45.txt
	my $scanPxSize = $plugin->scanPixelSize();
#	print STDERR "\$pxSize <", $pxSize, ">  \$scanPxSize <", $scanPxSize, ">\n";  # --> maxLevel = 7

	#my( $IDX ) = ($selection =~ /(\d+)(?:$|\.ppm$)/g);
	my $tNW = $plugin->geoRef_scan( $scanTag );
	my( $x0, $y0, $dx, $dy ) = ( $tNW->{xpos}, $tNW->{ypos}, $tNW->{xsize}, -$tNW->{ysize} );

	my( $xSize, $ySize ) = ( int($dx/$pxSize), int($dy/$pxSize) );
	my( $xMin, $xMax, $yMin, $yMax ) = ( $x0, $x0+$dx, $y0-$dy, $y0 );
	my( $txMin, $txMax, $tyMin, $tyMax ) = ( int(($xMin+180)/$tileSize), int(($xMax+180)/$tileSize), int(($yMin+90)/$tileSize), int(($yMax+90)/$tileSize) );

	return ( [$tyMin,$tyMax], [$txMin,$txMax] );
}

sub directoryRange {
	# only works for WW naming convention
	require File::Find;
	my( $pkg, $layer, $level, $dir ) = @_;
	my $startMax = 99_999_999;
	my( $txMin, $txMax, $tyMin, $tyMax ) = ( $startMax, -$startMax, $startMax, -$startMax );
	File::Find::find(	{ wanted => sub{
		if( -f $File::Find::name && $File::Find::name =~ /(\d+)_(\d+)\.\w+$/ ){
			my( $y, $x ) = ( $1, $2 );
			$txMin = $x if $x < $txMin;				
			$txMax = $x if $x > $txMax;				
			$tyMin = $y if $y < $tyMin;				
			$tyMax = $y if $y > $tyMax;				
		}
	}, no_chdir => 1 }, $dir	);
	return ( [$tyMin,$tyMax], [$txMin,$txMax] );
}

sub tileIterator {
	my( $pkg, $info, $cSub ) = @_;
	$info = $pkg->tileInfo( $info );
	if( $info->{'list'} ){
		foreach my $item ( @{$info->{'list'}} ){
			$cSub->( $item );
		}
	}elsif( ref($info->{'x'}) || ref($info->{'y'}) ){
		my( $xMin, $xMax ) = ref($info->{'x'}) ? @{$info->{'x'}} : ($info->{'x'},$info->{'x'});
		my( $yMin, $yMax ) = ref($info->{'y'}) ? @{$info->{'y'}} : ($info->{'y'},$info->{'y'});
		print STDERR "tileIterator \$xMin <", $xMin, ">  \$xMax <", $xMax, ">  \$yMin <", $yMin, ">  \$yMax <", $yMax, ">\n";  # _DEBUG_
		if( $info->{'random'} ){
			my $item;
			while( 1 ){
				my $x = $xMin + int(rand($xMax - $xMin + 1));
				my $y = $yMin + int(rand($yMax - $yMin + 1));
				$item = $info->copy( 'y' => $y, 'x' => $x );
				my $fileName = $item->tileName();
				last if -f $fileName;
			}
			$cSub->( $item );
		}else{
			for( my $y = $yMin; $y <= $yMax; ++$y ){
#				print STDERR "tileIterator \$y <", $y, ">\n";  # _DEBUG_
				for( my $x = $xMin; $x <= $xMax; ++$x ){
					my $item = $info->copy( 'y' => $y, 'x' => $x );
					my $fileName = $item->tileName();
#					print STDERR "\$fileName <", $fileName, ">\n";  # _DEBUG_
					next unless -f $fileName || $ITERATOR_OPTS{'CREATE'} || $fileName =~ /^https?:/;
					$cSub->( $item );
				}
			}
		}
	}else{
		$cSub->( $info );
	}
}

sub tileCoord {
	my( $info, $aPt ) = @_;
	my( $x, $y ) = @$aPt;
	my( $level, $tx, $ty ) = $info->getAttr( 'level', 'x', 'y' );
	my $hGeo = $info->geoRef( $tx, $ty, $level );
	$x = ($x - $hGeo->{'xpos'}) / $hGeo->{'pszX'}; 
	$y = ($y - $hGeo->{'ypos'}) / $hGeo->{'pszY'}; 
	return [ $x, $y ];
}

sub geoCoord {
	my( $info, $aPt ) = @_;
	my( $x, $y ) = @$aPt;
	my( $level, $tx, $ty ) = $info->getAttr( 'level', 'x', 'y' );
	my $hGeo = $info->geoRef( $tx, $ty, $level );
	$x = $hGeo->{'xpos'} + $x * $hGeo->{'pszX'}; 
	$y = $hGeo->{'ypos'} + $y * $hGeo->{'pszY'}; 
	return [ $x, $y ];
}

sub getTransform {
	my( $info ) = @_;
#	return $info->{'transform'} if $info->{'transform'};
    my $trf;
	if( $info->{'transform'} ){
		$trf = $info->{'transform'};
	}else{
#	    my $layer = $info->{'layer'};
#	    return $INFO_MAP{'image'}{$layer}{'transform'} if $INFO_MAP{'image'}{$layer}{'transform'};
	    $trf = $info->layerInfo( 'transform', 'opt' );
	}
	$trf = {'X' => [ @{$trf->{'X'}} ], 'Y' => [ @{$trf->{'Y'}} ]} if $trf ;  # clone transform to prevent in-place modifications
	return $trf ? $trf : undef;
}

sub getProjection {
	my( $info ) = @_;
	return $info->{'proj4'} if $info->{'proj4'};
	my $layer = $info->{'layer'};
#	return $INFO_MAP{'image'}{$layer}{'proj4'} if $INFO_MAP{'image'}{$layer}{'proj4'};
	return $INFO_MAP{$layer}{'proj4'} if $INFO_MAP{$layer}{'proj4'};
	return undef;
}


#-------------------------------------------------------------------------------


sub geoRef {
	my( $pkg, $x0, $y0, $level ) = @_;
	my $tileSize = 180 / (2 ** $level);

	my $hGeo = {
		xsize  => $tileSize,
		ysize  => $tileSize,
		xpos   => (-180 + $x0     * $tileSize),
		ypos   => ( -90 + ($y0+1) * $tileSize),
		pszX   => ($tileSize / $T_WIDTH),
		pszY   => -($tileSize / $T_HEIGHT),
	};
	return $hGeo;
}




1;

