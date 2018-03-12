package OGF::Terrain::ContourLines;
use strict;
use warnings;
use POSIX;
use OGF::View::TileLayer;
use OGF::Geo::Geometry;
use OGF::Util::File qw( writeToFile );
use OGF::Terrain::ElevationTile;



our $ELEVATION_TAG = 'ele';


sub writeContourTiles {
	my( $ctx, $tileLayer, $aTileSize, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	$aTileSize = [ 256, 256 ] if ! $aTileSize;

#	my $tileLayer = OGF::View::TileLayer->new( "contour:OGF:$level" );
	$tileLayer = OGF::View::TileLayer->new( $tileLayer ) if ! ref($tileLayer);
	my $hInfo = {
		_tileLayer => $tileLayer,
		_tileCache => {},
		_bbox      => [ 180, 90, -180, -90 ],
		_tileSize  => $aTileSize,
		_add       => ($hOpt->{'add'} ? 1 : 0),
	};
	if( $hOpt->{'bounds'} ){
	    my( $minLon, $minLat, $maxLon, $maxLat ) = ref($hOpt->{'bounds'}) ? @{$hOpt->{'bounds'}} : (split /,/, $hOpt->{'bounds'});
		my( $x0, $y1, $x1, $y0 ) = ( $tileLayer->geo2cnv($minLon,$minLat), $tileLayer->geo2cnv($maxLon,$maxLat) );
		$hInfo->{_bounds} = [ $x0, $y0, $x1, $y1 ];
		$hInfo->{_range}  = $tileLayer->bboxTileRange([$minLon, $minLat, $maxLon, $maxLat]);
	}

    my $hWays = separateWayClasses( $ctx->{_Way} );

    writeElevationWays( $ctx, $hWays, $hInfo );
    writeWaterWays( $ctx, $hWays, $hInfo );
    writeElevationNodes( $ctx, $hInfo );

	unless( $hOpt->{'nosave'} ){
        saveElevationTiles( $hInfo );
        delete $hInfo->{_tileCache};
	}

	return $hInfo;
}

sub separateWayClasses {
    my( $hCtxWays ) = @_;
	my( @coastWays, @contourWays, @waterWays );
	foreach my $way ( values %$hCtxWays ){
		my $hTags = $way->{'tags'};
		if( $hTags->{'natural'} && $hTags->{'natural'} eq 'coastline' ){  # handle coastline first to give it priority if "ele" tag is also present
			$way->{_elev} = 0;
			push @coastWays, $way;
		}elsif( $hTags && defined($hTags->{$ELEVATION_TAG}) ){
			next unless $hTags->{$ELEVATION_TAG} =~ /^-?[.\d]+$/;
			$way->{_elev} = $hTags->{$ELEVATION_TAG};
			push @contourWays, $way;
#			print STDERR "\%\$way <", join('|',%$way), ">\n";  # _DEBUG_
		}elsif( $hTags && $hTags->{'waterway'} ){
			push @waterWays, $way;
		}
	}
	if( scalar(@contourWays) == 0 ){
		die qq/ERROR: Found no contour ways.\n/
	}
    my $hWays = {
        _coastline => \@coastWays,
        _contour   => \@contourWays,
        _waterway  => \@waterWays,
    };
    return $hWays;	
}

sub writeElevationWays {
    my( $ctx, $hWays, $hInfo ) = @_;
	print STDERR "write contour ways\n";
	@{$hWays->{_contour}} = sort {$a->{_elev} <=> $b->{_elev}}  @{$hWays->{_contour}};
	foreach my $way ( @{$hWays->{_contour}}, @{$hWays->{_coastline}} ){
		writeElevationWay( $ctx, $way, $hInfo );
	}
}

sub writeWaterWays {
    my( $ctx, $hWays, $hInfo ) = @_;
    @{$hWays->{_waterway}} = sortHierarchical( $hWays->{_waterway} );

	print STDERR "linear interpolation of waterways\n";
	my( $ct, $num ) = ( 0, scalar(@{$hWays->{_waterway}}) );
	foreach my $way ( @{$hWays->{_waterway}} ){
		++$ct;
		print STDERR "+ way ", $way->{'id'}, "  $ct/$num\n";
		my @isctAll;
		convertWayPoints( $ctx, $way, $hInfo );
		foreach my $wayC ( @{$hWays->{_contour}}, @{$hWays->{_coastline}} ){
			next unless OGF::Geo::Geometry::rectOverlap( $way->{_rect}, $wayC->{_rect} );
			my @isct = OGF::Geo::Geometry::array_intersect( $way->{_points}, $wayC->{_points}, {'infoAll' => 1, 'rect' => [$way->{_rect},$wayC->{_rect}]} );
#			use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [\@isct], ['*isct'] ), "\n";  # _DEBUG_
			map {$_->{_point}[2] = $wayC->{_elev}} @isct;
			push @isctAll, @isct if @isct;
		}
		next if ! @isctAll;
        $way->{_points} = addIntersectionPoints( $way->{_points}, \@isctAll );
        linearWayElevation( $way->{_points} );
        writeElevationWay( $ctx, $way, $hInfo );
	}
}

sub writeElevationNodes {
    my( $ctx, $hInfo ) = @_;
	my $proj = $hInfo->{_tileLayer}->projection();
    foreach my $node ( grep {$_->{'tags'} && defined $_->{'tags'}{$ELEVATION_TAG}} values %{$ctx->{_Node}} ){
        minMaxArea( $hInfo->{_bbox}, $node );
        my $pt = $proj->geo2cnv( [$node->{'lon'},$node->{'lat'}] );
        setElevationPoint( $pt, int($node->{'tags'}{$ELEVATION_TAG}), $hInfo );
    }
}



sub writeContourTiles__ {
	my( $ctx, $tileLayer, $aTileSize, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	$aTileSize = [ 256, 256 ] if ! $aTileSize;

#	my $tileLayer = OGF::View::TileLayer->new( "contour:OGF:$level" );
	$tileLayer = OGF::View::TileLayer->new( $tileLayer ) if ! ref($tileLayer);
	my $hInfo = {
		_tileLayer => $tileLayer,
		_tileCache => {},
		_bbox      => [ 180, 90, -180, -90 ],
		_tileSize  => $aTileSize,
		_add       => ($hOpt->{'add'} ? 1 : 0),
	};
	if( $hOpt->{'bounds'} ){
	    my( $minLon, $minLat, $maxLon, $maxLat ) = ref($hOpt->{'bounds'}) ? @{$hOpt->{'bounds'}} : (split /,/, $hOpt->{'bounds'});
		my( $x0, $y1, $x1, $y0 ) = ( $tileLayer->geo2cnv($minLon,$minLat), $tileLayer->geo2cnv($maxLon,$maxLat) );
		$hInfo->{_bounds} = [ $x0, $y0, $x1, $y1 ];
		$hInfo->{_range}  = $tileLayer->bboxTileRange([$minLon, $minLat, $maxLon, $maxLat]);
	}

	my( @coastWays, @contourWays, @waterWays );
	foreach my $way ( values %{$ctx->{_Way}} ){
		my $hTags = $way->{'tags'};
		if( $hTags->{'natural'} && $hTags->{'natural'} eq 'coastline' ){  # handle coastline first to give it priority if "ele" tag is also present
			$way->{_elev} = 0;
			push @coastWays, $way;
		}elsif( $hTags && defined($hTags->{$ELEVATION_TAG}) ){
			next unless $hTags->{$ELEVATION_TAG} =~ /^-?[.\d]+$/;
			$way->{_elev} = $hTags->{$ELEVATION_TAG};
			push @contourWays, $way;
#			print STDERR "\%\$way <", join('|',%$way), ">\n";  # _DEBUG_
		}elsif( $hTags && $hTags->{'waterway'} ){
			push @waterWays, $way;
		}
	}
	if( scalar(@contourWays) == 0 ){
		die qq/ERROR: Found no contour ways.\n/
	}

	print STDERR "write contour ways\n";
	@contourWays = sort {$a->{_elev} <=> $b->{_elev}}  @contourWays;
	foreach my $way ( @contourWays, @coastWays ){
		writeElevationWay( $ctx, $way, $hInfo );
	}

    @waterWays = sortHierarchical( \@waterWays );

	print STDERR "linear interpolation of waterways\n";
	my( $ct, $num ) = ( 0, scalar(@waterWays) );
	foreach my $way ( @waterWays ){
		++$ct;
		print STDERR "+ way ", $way->{'id'}, "  $ct/$num\n";
		my @isctAll;
		convertWayPoints( $ctx, $way, $hInfo );
		foreach my $wayC ( @contourWays, @coastWays ){
			next unless OGF::Geo::Geometry::rectOverlap( $way->{_rect}, $wayC->{_rect} );
			my @isct = OGF::Geo::Geometry::array_intersect( $way->{_points}, $wayC->{_points}, {'infoAll' => 1, 'rect' => [$way->{_rect},$wayC->{_rect}]} );
#			use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [\@isct], ['*isct'] ), "\n";  # _DEBUG_
			map {$_->{_point}[2] = $wayC->{_elev}} @isct;
			push @isctAll, @isct if @isct;
		}
		next if ! @isctAll;
        $way->{_points} = addIntersectionPoints( $way->{_points}, \@isctAll );
        linearWayElevation( $way->{_points} );
        writeElevationWay( $ctx, $way, $hInfo );
	}

	my $proj = $tileLayer->projection();
    foreach my $node ( grep {$_->{'tags'} && defined $_->{'tags'}{$ELEVATION_TAG}} values %{$ctx->{_Node}} ){
        minMaxArea( $hInfo->{_bbox}, $node );
        my $pt = $proj->geo2cnv( [$node->{'lon'},$node->{'lat'}] );
        setElevationPoint( $pt, int($node->{'tags'}{$ELEVATION_TAG}), $hInfo );
    }

	unless( $hOpt->{'nosave'} ){
        saveElevationTiles( $hInfo );
        delete $hInfo->{_tileCache};
	}

	return $hInfo;
}





my $INT_MAX = 2 ** 31;


sub convertWayPoints {
	my( $ctx, $way, $hInfo ) = @_;
	my $proj = $hInfo->{_proj} || $hInfo->{_tileLayer}->projection();
	my $bbox = $hInfo->{_bbox};
	my $num = $#{$way->{'nodes'}};

	$way->{_points} = [];
	$way->{_rect}   = [ $INT_MAX, $INT_MAX, -$INT_MAX, -$INT_MAX ];
	for( my $i = 0; $i <= $num; ++$i ){
		my $node = $ctx->{_Node}{$way->{'nodes'}[$i]};
#		print STDERR "$i ", $way->{'nodes'}[$i] ,"  \$node <", $node, ">\n";  # _DEBUG_
		my $pt = $proj->geo2cnv( [$node->{'lon'},$node->{'lat'}] );
#       $pt->[2] = int($node->{'tags'}{$ELEVATION_TAG}) if defined $node->{'tags'}{$ELEVATION_TAG};
        $pt->[2] = $node->{'tags'}{$ELEVATION_TAG} if defined $node->{'tags'}{$ELEVATION_TAG};
		minMaxArea( $bbox, $node );
		minMaxArea( $way->{_rect}, $pt );
		$way->{_points}[$i] = $pt;		
	}
}

sub writeElevationWay {
	my( $ctx, $way, $hInfo ) = @_;
	convertWayPoints( $ctx, $way, $hInfo ) if ! $way->{_points};
	my $num = $#{$way->{_points}};
	print STDERR $way->{'id'}, " num=$num  elev=", $way->{_elev}, "\n";  # _DEBUG_

	for( my $i = 0; $i < $num; ++$i ){
		my( $ptA, $ptB ) = ( $way->{_points}[$i], $way->{_points}[$i+1] );
		( $ptA->[2], $ptB->[2] ) = ( $way->{_elev}, $way->{_elev} ) if defined $way->{_elev};
		next unless defined($ptA->[2]) && defined($ptB->[2]);
#		print STDERR "\$i <", $i, ">\n";  # _DEBUG_
		map {$_ = POSIX::floor($_+.5)} ( $ptA->[0], $ptA->[1], $ptB->[0], $ptB->[1] );
		my @linePoints = OGF::Geo::Geometry::linePoints( $ptA, $ptB );
		@linePoints = ( $ptA, @linePoints, $ptB );
		foreach my $pt ( @linePoints ){
			setElevationPoint( $pt, $pt->[2], $hInfo );
		}
	}
}

sub setElevationPoint {
	my( $pt, $elev, $hInfo ) = @_;
	my( $tx, $ty, $xt, $yt ) = $hInfo->{_tileLayer}->cnv2tile( $pt->[0], $pt->[1] );
#	print STDERR "$tx $ty - $xt $yt\n";  # _DEBUG_
	my $aTile = getTileArray( $hInfo, $tx, $ty );
	$aTile->[$yt][$xt] = POSIX::floor( $elev + .5 );
}

sub minMaxArea {
	my( $bbox, @nodes ) = @_;
	foreach my $node ( @nodes ){
        my( $x, $y ) = (ref($node) eq 'ARRAY')? ($node->[0],$node->[1]) : ($node->{'lon'},$node->{'lat'});
        $bbox->[0] = $x if $x < $bbox->[0];
        $bbox->[1] = $y if $y < $bbox->[1];
        $bbox->[2] = $x if $x > $bbox->[2];
        $bbox->[3] = $y if $y > $bbox->[3];
	}
}

sub addIntersectionPoints {
	my( $aPoints, $aIsctList ) = @_;
	@$aIsctList = sort {$a->{_idx} <=> $b->{_idx} || $a->{_ratio} <=> $b->{_ratio}} @$aIsctList;
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$aIsctList], ['aIsctList'] ), "\n";  # _DEBUG_

	my @points;
	for( my $i = 0; $i <= $#{$aPoints}; ++$i ){
		push @points, $aPoints->[$i];
		my @idxPoints = map {$_->{_point}} grep {$_->{_idx} == $i} @$aIsctList;
		push @points, @idxPoints;
	}
	return \@points;
}

sub linearWayElevation {
	my( $aPoints ) = @_;
	my @elevIdx = grep {defined $aPoints->[$_][2]} (0..$#{$aPoints}); 
#	print STDERR "\@elevIdx <", join('|',@elevIdx), ">\n";  # _DEBUG_
	warn qq/linearElevation; no elevation point available\n/ if ! @elevIdx;
	for( my $i = 0; $i < $#elevIdx; ++$i ){
		linearSegmentElevation( $aPoints, $elevIdx[$i], $elevIdx[$i+1] );
	}
}

sub linearSegmentElevation {
	my( $aPoints, $i0, $i1 ) = @_;
#	print STDERR "linearSegmentElevation( $aPoints, $i0, $i1 )\n";  # _DEBUG_
	my( $zE, $zD ) = ( 2, 3 );

	$aPoints->[$i0][$zD] = 0;
	for( my $i = $i0; $i < $i1; ++$i ){
		my( $pt0, $pt1 ) = ( $aPoints->[$i], $aPoints->[$i+1] );
		my $dist = OGF::Geo::Geometry::dist( $pt0, $pt1 ); 
		$pt1->[$zD] = $pt0->[$zD] + $dist;
	}
	my( $e0, $e1 ) = ( $aPoints->[$i0][$zE], $aPoints->[$i1][$zE] );
	my $distTotal = $aPoints->[$i1][$zD];

	for( my $i = $i0+1; $i < $i1; ++$i ){
		my $pt = $aPoints->[$i];
		my $dd = $pt->[$zD];
		my $elevLin  = ($e1 * $dd + $e0 * ($distTotal - $dd)) / $distTotal;
#		print STDERR "[$i] \$elevLin <", $elevLin, ">\n";  # _DEBUG_
#		warn qq/Point elevation mismatch [$i]\n/ if defined($pt->[$zE]) && $pt->[$zE] != $elevLin;
		$pt->[$zE] = $elevLin;
	}
}

sub getTileArray {
	my( $hInfo, $tx, $ty ) = @_;
	my $tag = "$tx:$ty";
	if( ! $hInfo->{_tileCache}{$tag} ){	
		my $tileName = $hInfo->{_tileLayer}->tileName( $tx, $ty );
		print STDERR "tileName: ", $tileName, "\n";  # _DEBUG_
		my( $wd, $hg ) = @{$hInfo->{_tileSize}};
		my $aTile;

		if( -f $tileName ){
			if( $hInfo->{_add} ){
				$aTile = OGF::Terrain::ElevationTile::makeArrayFromFile( $tileName, $wd, $hg, $OGF::Terrain::ElevationTile::BPP );
			}elsif( $hInfo->{_range} && rangeBoundary($hInfo->{_range},$tx,$ty) ){
				my $aRect = tileOverlap( $hInfo, $tx, $ty, $hInfo->{_bounds} );
				$aTile = OGF::Terrain::ElevationTile::makeArrayFromFile( $tileName, $wd, $hg, $OGF::Terrain::ElevationTile::BPP );
				clearSubtile( $aTile, $aRect, $OGF::Terrain::ElevationTile::NO_ELEV_VALUE );
			}
		}
		if( ! $aTile ){
			$aTile = OGF::Terrain::ElevationTile::makeTileArray( $OGF::Terrain::ElevationTile::NO_ELEV_VALUE, $wd, $hg );
		}
	
		$hInfo->{_tileCache}{$tag} = $aTile;
	}
	return $hInfo->{_tileCache}{$tag};
}

sub rangeBoundary {
	my( $hRange, $tx, $ty ) = @_;
	my( $y0, $y1, $x0, $x1	) = ( $hRange->{'y'}[0], $hRange->{'y'}[1], $hRange->{'x'}[0], $hRange->{'x'}[1] );
	return (($ty == $y0 || $ty == $y1) && ($tx >= $x0 && $tx <= $x1)) || (($tx == $x0 || $tx == $x1) && ($ty >= $y0 && $ty <= $y1));
}

sub tileOverlap {
    my( $hInfo, $tx, $ty, $aBounds ) = @_;
    my( $tlr, $wd, $hg ) = ( $hInfo->{_tileLayer}, @{$hInfo->{_tileSize}} );
    my( $x0, $y0, $x1, $y1 ) = ( $tlr->tile2cnv($tx,$ty,0,0), $tlr->tile2cnv($tx,$ty,$wd-1,$hg-1) );
    my $aRect = OGF::Geo::Geometry::rectOverlap( $aBounds, [$x0,$y0,$x1,$y1] );
    my( $tx0, $ty0, $xt0, $yt0 ) = $tlr->cnv2tile( $aRect->[0], $aRect->[1] );
    my( $tx1, $ty1, $xt1, $yt1 ) = $tlr->cnv2tile( $aRect->[2], $aRect->[3] );
	( $xt0, $yt0, $xt1, $yt1 ) = map {POSIX::floor($_)} ( $xt0, $yt0, $xt1, $yt1 );

    my( $dx, $dy, $maxX, $maxY ) = @{$tlr->{_tileOrder}};
    $xt0 = 0 if $tx0 < $tx;
    $yt0 = ($dy >= 0)? 0 : $hg-1 if $ty0 < $ty;
    $xt1 = $wd-1 if $tx1 > $tx;
    $yt1 = ($dy >= 0)? $hg-1 : 0 if $ty1 > $ty;
    return [ $xt0, $yt0, $xt1, $yt1 ];
}

sub clearSubtile {
    my( $aTile, $aClear, $val ) = @_;
    $val = 0 if ! $val;
    my( $x0, $y0, $x1, $y1 ) = @$aClear;
    for( my $y = $y0; $y <= $y1; ++$y ){
        for( my $x = $x0; $x <= $x1; ++$x ){
            $aTile->[$y][$x] = $val;
        }
    }
}

sub boundsFromFileName {
    my( $file ) = @_;
    my $aBounds;
#   if( $file =~ /_(\d+)([EW])(\d+)([NS])_band(\d+)_/ ){
    if( $file =~ /_([NS])(\d+)([EW])(\d+)_band(\d+)_/ ){
        my( $dNS, $minLat, $dEW, $minLon, $band ) = ( $1, $2, $3, $4, $5 );
		$minLon = -$minLon if $dEW eq 'W';
		$minLat = -$minLat if $dNS eq 'S';
        ( $minLon, $minLat, my $maxLon, my $maxLat ) = ( $minLon, $minLat+($band-1)*.2, $minLon+1, $minLat+$band*.2 );
        $aBounds = [ $minLon, $minLat, $maxLon, $maxLat ];
    }elsif( $file =~ /([NS])([.\d]+)([EW])([.\d]+)_([NS])([.\d]+)([EW])([.\d]+)/ ){
        my( $minNS, $minLat, $minEW, $minLon, $maxNS, $maxLat, $maxEW, $maxLon ) = ( $1, $2, $3, $4, $5, $6, $7, $8 );
		$minLon = -$minLon if $minEW eq 'W';
		$minLat = -$minLat if $minNS eq 'S';
		$maxLon = -$maxLon if $maxEW eq 'W';
		$maxLat = -$maxLat if $maxNS eq 'S';
        $aBounds = [ $minLon, $minLat, $maxLon, $maxLat ];
    }
    return $aBounds;
}



sub saveElevationTiles {
	my( $hInfo ) = @_;
	my $hTileCache = $hInfo->{_tileCache};
	my $hRange = setMinMaxRange();

	foreach my $key ( keys %$hTileCache ){
		my( $tx, $ty ) = split /:/, $key;
		setMinMaxRange( $hRange, $tx, $ty );
		my $tileName = $hInfo->{_tileLayer}->tileName( $tx, $ty );
		my $data = OGF::Terrain::ElevationTile::makeTileFromArray( $hTileCache->{$key}, $OGF::Terrain::ElevationTile::BPP );
		writeToFile( $tileName, $data, undef, {-bin => 1, -mdir => 1} );
	}
	$hInfo->{_tileRange} = $hRange;
}

sub setMinMaxRange {
	my( $hRange, $x, $y ) = @_;
	if( $hRange ){
		$hRange->{_xMin} = $x if $x < $hRange->{_xMin};
		$hRange->{_xMax} = $x if $x > $hRange->{_xMax};
		$hRange->{_yMin} = $y if $y < $hRange->{_yMin};
		$hRange->{_yMax} = $y if $y > $hRange->{_yMax};
	}else{
	    $hRange = { _xMin => 2**32, _xMax => 0, _yMin => 2**32, _yMax => 0 };
	}
	return $hRange;
}


#-------------------------------------------------------------------------------



sub waterwayElevation {
	my( $ctx, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;

	my $proj = $ctx->{_proj};
	die qq/waterwayElevation: no projection defined for data context.\n/ if ! $proj;
	my $hInfo = {_proj => $proj, _bbox => [ 180, 90, -180, -90 ]};

	my( $aContourWays, $aWaterWays ) = separateWayCategories( $ctx );
	foreach my $wayC ( @$aContourWays ){
		convertWayPoints( $ctx, $wayC, $hInfo );
		my $elev = $wayC->{_elev};
        foreach my $nodeId ( @{$wayC->{'nodes'}} ){
            my $node = $ctx->{_Node}{$nodeId};
            $node->{'tags'}{$ELEVATION_TAG} = $elev;
        }
	}

	print STDERR "Connect waterway segments\n";
	require OGF::Geo::Topology;
	my %ways = map {$_->{'id'} => $_} @$aWaterWays;
	my $aWays = OGF::Geo::Topology::buildWaySequence( $ctx, undef, \%ways, {'wayDirection' => 1} );

	print STDERR "linear interpolation of waterways\n";
#   my @waterWays = sortHierarchical( \@waterWays );
    my @waterWays = sortHierarchical( $aWays );
	my( $ct, $num ) = ( 0, scalar(@waterWays) );

	foreach my $way ( @waterWays ){
		++$ct;
		print STDERR "+ way ", $way->{'id'}, "  $ct/$num\n";
        convertWayPoints( $ctx, $way, $hInfo );
        if( ! $hOpt->{'noIntersect'}  ){
            my @isctAll;
            foreach my $wayC ( @$aContourWays ){
                next unless OGF::Geo::Geometry::rectOverlap( $way->{_rect}, $wayC->{_rect} );
                my @isct = OGF::Geo::Geometry::array_intersect( $way->{_points}, $wayC->{_points}, {'infoAll' => 1, 'rect' => [$way->{_rect},$wayC->{_rect}]} );
#	    		    use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [\@isct], ['*isct'] ), "\n";  # _DEBUG_
                map {$_->{_point}[2] = $wayC->{_elev}} @isct;
                push @isctAll, @isct if @isct;
            }
#    		    next if ! @isctAll;
            addIntersectionNodes( $ctx, $way, \@isctAll );
        }

        my $node = $ctx->{_Node}{$way->{'nodes'}[-1]};
        $node->{'tags'}{$ELEVATION_TAG} = $way->{_points}[-1][2] = 0 if ! $node->{'tags'}{$ELEVATION_TAG};
        linearWayElevation( $way->{_points} );

#       warn qq/Way length mismatch\n/ if $#{$way->{_points}} != $#{$way->{'nodes'}};
        for( my $i = 0; $i <= $#{$way->{_points}}; ++$i ){
            my $pt = $way->{_points}[$i];
            next if ! defined $pt->[2];
            my( $node, $elev ) = ( $ctx->{_Node}{$way->{'nodes'}[$i]}, $pt->[2] );
            my $elevExist = ($node->{'tags'} && $node->{'tags'}{$ELEVATION_TAG})? $node->{'tags'}{$ELEVATION_TAG} : undef;
            warn qq/Elevation mismatch: [$i] $elevExist != $elev\n/ if defined($elevExist) && $elevExist != $elev;
            $node->{'tags'}{$ELEVATION_TAG} = sprintf( '%.2f', $elev );
            $node->{'tags'}{$ELEVATION_TAG} =~ s/\.0+$//;
        }
	}
}

sub separateWayCategories {
    my( $ctx ) = @_;
	my( @contourWays, @waterWays );
	foreach my $way ( values %{$ctx->{_Way}} ){
		my $hTags = $way->{'tags'};
		if( $hTags->{'natural'} && $hTags->{'natural'} eq 'coastline' ){  # handle coastline first to give it priority if "ele" tag is also present
			$way->{_elev} = 0;
			push @contourWays, $way;
		}elsif( $hTags && defined($hTags->{$ELEVATION_TAG}) ){
			next unless $hTags->{$ELEVATION_TAG} =~ /^-?[.\d]+$/;
			$way->{_elev} = $hTags->{$ELEVATION_TAG};
			push @contourWays, $way;
#			print STDERR "\%\$way <", join('|',%$way), ">\n";  # _DEBUG_
		}elsif( $hTags && $hTags->{'waterway'} ){
			push @waterWays, $way;
		}
	}
	if( scalar(@contourWays) == 0 ){
		die qq/ERROR: Found no contour ways.\n/
	}
	@contourWays = sort {$a->{_elev} <=> $b->{_elev}}  @contourWays;
	return ( \@contourWays, \@waterWays );
}

sub addIntersectionNodes {
	my( $ctx, $way, $aIsctList ) = @_;
	@$aIsctList = sort {$a->{_idx} <=> $b->{_idx} || $a->{_ratio} <=> $b->{_ratio}} @$aIsctList;
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$aIsctList], ['aIsctList'] ), "\n";  # _DEBUG_

	my( $proj, $aNodes, $aPoints ) = ( $ctx->{_proj}, $way->{'nodes'}, $way->{_points} );
	my( @nodes, @points );
	for( my $i = 0; $i <= $#{$aNodes}; ++$i ){
		push @points, $aPoints->[$i];
		push @nodes,  $aNodes->[$i];
		my @idxPoints = map {$_->{_point}} grep {$_->{_idx} == $i} @$aIsctList;
        foreach my $pt ( @idxPoints ){
            push @points, $pt;
            my( $lon, $lat ) = $proj->cnv2geo( $pt->[0], $pt->[1] ); 
            my $node = OGF::Data::Node->new( $ctx, {'lon' => $lon, 'lat' => $lat} );
            $node->{_keep} = 1;
		    push @nodes, $node->{'id'};
		}
	}
	$way->{_points} = \@points;
	$way->{'nodes'} = \@nodes;
}

sub sortHierarchical {
	my( $aWays, $hOpt ) = @_;
    $hOpt = {} if ! $hOpt;
    my $maxIter = $hOpt->{'maxIterations'} || 20;

	my( @ways, %ways, %endNodes, %parent );

	foreach my $way ( @$aWays ){
        my $endNode = $way->{'nodes'}[-1];
        $endNodes{$endNode} = $way->{'id'};
	}
	foreach my $way ( @$aWays ){
        foreach my $nodeId ( @{$way->{'nodes'}} ){
			if( $endNodes{$nodeId} && $endNodes{$nodeId} != $way->{'id'} ){
                $parent{$endNodes{$nodeId}} = $way->{'id'};
#               print STDERR "\$parent{$endNodes{$nodeId}} <", $parent{$endNodes{$nodeId}}, ">\n";  # _DEBUG_
			}
        }
	}
    my $ct = $#{$aWays} * $maxIter;
	while( @$aWays ){
	    my $way = shift @$aWays;
        my $parentId = $parent{$way->{'id'}};
	    if( $parentId && ! $ways{$parentId} ){
			push @$aWays, $way;
	    }else{
	        $ways{$way->{'id'}} = 1;
            push @ways, $way;
	    }
	    die qq/sortHierarchical: too many iterations/ if --$ct <= 0;
	}

    return @ways;
}

sub sortConsecutive {
	my( $aWays, $hOpt ) = @_;
    $hOpt = {} if ! $hOpt;
    my $maxIter = $hOpt->{'maxIterations'} || 20;

    my %ways = map {$_->{'id'} => $_} @$aWays;
    my @ways = ( delete $ways{$aWays->[0]{'id'}} );

    my $ct = $#{$aWays} * $maxIter;
    while( %ways ){
        foreach my $id ( keys %ways ){
            my $way = $ways{$id};
            my( $idStart, $idEnd ) = ( $way->{'nodes'}[0], $way->{'nodes'}[-1] );
            my( $idListStart, $idListEnd ) = ( $ways[0]->{'nodes'}[0], $ways[-1]->{'nodes'}[-1] );
#           print STDERR "\$idListStart <", $idListStart, ">  \$idListEnd <", $idListEnd, ">\n";
            if( $idStart == $idListEnd ){
                push @ways, $way;
                delete $ways{$id};
            }elsif( $idEnd == $idListEnd ){
                @{$way->{'nodes'}} = reverse @{$way->{'nodes'}};
                push @ways, $way;
                delete $ways{$id};
            }elsif( $idEnd == $idListStart ){
                unshift @ways, $way;
                delete $ways{$id};
            }elsif( $idStart == $idListStart ){
                @{$way->{'nodes'}} = reverse @{$way->{'nodes'}};
                unshift @ways, $way;
                delete $ways{$id};
            }
        }
	    die qq/sortHierarchical: too many iterations/ if --$ct <= 0;
    }
    return @ways;
}




1;

