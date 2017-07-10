package OGF::Util::ElevationLine;
use strict;
use warnings;
use OGF::Util::Shape;
use OGF::Geo::Geometry;
use OGF::Data::Context;



my $ELEVATION_TAG = 'ele';
my $RECURSION_COUNT = 0;


sub randomMountainElevation {
	my( $way ) = @_;
	my $ctx = $way->{_context};
	return 2 if $way->{_elevationFlag};
	return 0 if mountainDependencies( $way, $ctx );

#	randomInteriorElevation( $way );      # _TEST_
	randomEndpointElevation( $way, 0 );
	randomEndpointElevation( $way, -1 );

	my $aNodes = $way->{'nodes'};
	my @elevIdx = grep {defined nodeElevation($way,$_)} (0..$#{$aNodes}); 
#	print STDERR "\@elevIdx <", join('|',@elevIdx), ">\n";  # _DEBUG_
	warn qq/randomMountainElevation; no elevation point available for way $way->{id}/ if ! @elevIdx;

	my $linOpt = ($#elevIdx == 1)? {'anticline' => .1} : {};
	for( my $i = 0; $i < $#elevIdx; ++$i ){
		$RECURSION_COUNT = 0;
#		randomSegmentElevation_R( $way, $elevIdx[$i], $elevIdx[$i+1] );
		linearSegmentElevation( $way, $elevIdx[$i], $elevIdx[$i+1], $linOpt );
	}

	$way->{_elevationFlag} = 1;
	return 1;
}

sub randomInteriorElevation {
	my( $way ) = @_;
	my( $e0, $e1 ) = ( nodeElevation($way,0), nodeElevation($way,-1) );
	return if defined $e0 || defined $e1;
	my $n = $#{$way->{'nodes'}} + 1;
	nodeElevation( $way, int($n/2), 4500 );
}


sub randomEndpointElevation {
	my( $way, $idx ) = @_;
	return if defined nodeElevation($way,$idx);
	my( $ctx, $aNodes ) = ( $way->{_context}, $way->{'nodes'} );
	my @elevIdx = grep {defined nodeElevation($way,$_)} (0..$#{$aNodes}); 
	warn qq/randomEndpointElevation; no elevation point available for way $way->{id}/ if ! @elevIdx;
	my $elevIdx = $elevIdx[$idx];
	my $elev = nodeElevation( $way, $elevIdx );
	my $elevRand = randomIntValue( $elev * 0.66, $elev * .9 );
#	$aNodes->[$idx]{'tags'}{$ELEVATION_TAG} = $elevRand;
	nodeElevation( $way, $idx, $elevRand );
	return $elevRand;
}

sub randomSegmentElevation_R {
	die qq/randomSegmentElevation_R: RECURSION_COUNT exceeded/ if $RECURSION_COUNT > 10000;

	my( $way, $i0, $i1 ) = @_;
	my $idx = int( ($i0 + $i1) / 2 );
	print STDERR "randomSegmentElevation_R $i0 $i1 -> $idx\n";
	return if $idx == $i0 || $idx == $i1;
	my( $e0, $e1 ) = ( nodeElevation($way,$i0), nodeElevation($way,$i1) );

	my $elevLin  = ($e1 * ($idx - $i0) + $e0 * ($i1 - $idx)) / ($i1 - $i0);
	my $mult     = min( 1, ($i1 - $i0) / 5 );
	my $elevRand = randomIntValue( $elevLin * (1 - $mult * .3), $elevLin * (1 + $mult * .2) );
	nodeElevation( $way, $idx, $elevRand );

	randomSegmentElevation_R( $way, $i0,  $idx );
	randomSegmentElevation_R( $way, $idx, $i1  );

	return $elevRand;
}


sub linearElevation {
	my( $way, $terrainTool ) = @_;
	my $ctx = $way->{_context};
	return 2 if $way->{_elevationFlag};
	print STDERR "-----\n";
	elevationPointsFromTerrain( $way, $terrainTool ) if ! defined nodeElevation( $way, 0 );
	print STDERR "linearElevation ", $way->{'id'}, "\n";
	return 0 if ! defined nodeElevation( $way, -1 );
	print STDERR "-> OK\n";

	my $aNodes = $way->{'nodes'};
	my @elevIdx = grep {defined nodeElevation($way,$_)} (0..$#{$aNodes}); 
#	print STDERR "\@elevIdx <", join('|',@elevIdx), ">\n";  # _DEBUG_
	warn qq/linearElevation; no elevation point available for way $way->{id}/ if ! @elevIdx;

	for( my $i = $#elevIdx; $i > 0; --$i ){
		linearSegmentElevation( $way, $elevIdx[$i-1], $elevIdx[$i] );
	}

	$way->{_elevationFlag} = 1;
	return 1;
}

sub linearSegmentElevation {
	my( $way, $i0, $i1, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my $ac = $hOpt->{'anticline'} || 0;
	my $i2 = ($i0 + $i1) / 2;
	my( $e0, $e1 ) = ( nodeElevation($way,$i0), nodeElevation($way,$i1) );
	for( my $i = $i0+1; $i < $i1; ++$i ){
		my $elevLin  = ($e1 * ($i - $i0) + $e0 * ($i1 - $i)) / ($i1 - $i0);
		if( $ac ){
			my $x = ($i - $i2) / ($i1 - $i2);
#			$elevLin *= ($ac * $x * $x + 1 - $ac);
			$elevLin *= ($ac * abs($x) + 1 - $ac);
		}
		nodeElevation( $way, $i, $elevLin );
	}
}

sub constantElevation {
	my( $way, $elev ) = @_;
	my $ctx = $way->{_context};
	foreach my $nodeId ( @{$way->{'nodes'}} ){
		nodeElevation( $nodeId, $ctx, $elev );
	}
}


sub randomIntValue {
	my( $min, $max ) = @_;
	my $val = $min + rand( $max - $min );
	return int( $val + .5 );
}

sub nodeElevation {
	my( $node, $elev );
	if( ref($_[0]) ){
		my( $way, $idx ) = @_;
#		print STDERR "nodeElevation $way->{id} [$idx] ", $way->{'nodes'}[$idx], "\n";
		$node = $way->{_context}->getNode( $way->{'nodes'}[$idx] );
		$elev = nodeElevation( $way->{'nodes'}[$idx], $way->{_context} );
#		print STDERR "-> elev <", ((defined $elev)? $elev : ''), ">\n";  # _DEBUG_
	}else{
        my( $nodeId, $ctx ) = @_;
        $node = $ctx->getNode( $nodeId );
	}
	if( defined $_[2] ){
#		print STDERR "nodeElevation $node->{id} -> $_[2]\n";
		$elev = $node->{'tags'}{$ELEVATION_TAG} = $_[2];
	}else{
        $elev = $node->{'tags'} ? $node->{'tags'}{$ELEVATION_TAG} : undef;
	}
    return $elev;
}

sub nodeOtherWays {
	my( $nodeId, $way ) = @_;
	my $ctx = $way->{_context};
	$nodeId = $nodeId->{'id'} if ref($nodeId);
	my $nodeRevInfo = $ctx->{_rev_info}{'N|'.$nodeId};
	my @wayIds = $nodeRevInfo ? (keys %$nodeRevInfo) : ();
	@wayIds = grep	{$_ ne 'W|'.$way->{'id'}} @wayIds;
	return @wayIds;
}

sub mountainDependencies {
	my( $way, $ctx ) = @_;
	my %dep;
#	foreach my $nodeId ( @{$way->{'nodes'}} ){
	foreach my $nodeId ( $way->{'nodes'}[0], $way->{'nodes'}[-1] ){
		my $elev = nodeElevation( $nodeId, $ctx );
		if( ! defined $elev ){
			my @wayIds = nodeOtherWays( $nodeId, $way );
			if( @wayIds ){
				map {$dep{$_} = 1} @wayIds;
			}
		}
	}
	my @dep = keys %dep;
	print STDERR "dependencies ", $way->{'id'} ," (", join(';',@dep), ")\n";  # _DEBUG_
	return @dep;
}


sub elevationPointsFromTerrain {
	my( $way, $terrainTool, $aIndex, $maxElev ) = @_;
	my( $ctx, $aNodes ) = ( $way->{_context}, $way->{'nodes'} );
	print STDERR "elevationPointsFromTerrain $way->{id} (", $#{$aNodes}, ")\n";
	$maxElev = 0     if !defined $maxElev;
#	$aIndex  = [ 0, -1 ] if !defined $aIndex;
	$aIndex  = [ 0 ] if !defined $aIndex;

	my $hElev = {};
	$hElev = printNodeElevation( $way, 'known beforehand', $hElev );  # _DEBUG_
	foreach my $nodeId ( @$aNodes ){
		my $node = $ctx->getNode( $nodeId );
		my $terrainElev = $terrainTool->getNodeElevation( $node );
#		print STDERR "\$terrainElev <", $terrainElev, ">\n" if $way->{'id'} == 213166 || $way->{'id'} == 66761 || $way->{'id'} == -353494 || $way->{'id'} == -384560;  # _DEBUG_
		nodeElevation( $nodeId, $ctx, $terrainElev ) if $terrainElev <= $maxElev;
#		my @otherWays = grep {$ctx->getObject($_)->tagMatch({'natural' => 'coastline'})} nodeOtherWays( $nodeId, $way );
#		nodeElevation( $nodeId, $ctx, 0 ) if @otherWays;
	}
	$hElev = printNodeElevation( $way, 'from terrain (max)', $hElev );  # _DEBUG_
	foreach my $i ( @$aIndex ){
		my $node = $ctx->getNode( $aNodes->[$i] );
		my $terrainElev = $terrainTool->getNodeElevation( $node );
		nodeElevation( $way, $i, $terrainElev ) unless defined nodeElevation($way,$i);
	}
	$hElev = printNodeElevation( $way, 'from terrain (index)', $hElev );  # _DEBUG_

#	my @elevIdx = grep {defined nodeElevation($way,$_)} (0..$#{$aNodes}); 
#	for( my $i = $#elevIdx; $i > 0; --$i ){
#		my( $e0, $e1 ) = ( nodeElevation($way,$elevIdx[$i-1]), nodeElevation($way,$elevIdx[$i]) );
#		nodeElevation( $way, $elevIdx[$i-1], $e1+1 ) if $e0 < $e1;
#	}

	for( my $i = $#{$aNodes}-1; $i >= 0; --$i ){  # set last nonzero elevation to 1
		my $elev  = nodeElevation( $way, $i );
		my $elevP = nodeElevation( $way, $i+1 );
		if( defined($elevP) && $elevP == 0 && ! defined $elev ){
			nodeElevation( $way, $i, 1 );
			last;
		}
	}
	$hElev = printNodeElevation( $way, 'last nonzero', $hElev );  # _DEBUG_
}

sub printNodeElevation {
	my( $way, $text, $hExclude ) = @_;
#	return unless $way->{'id'} == 213166 || $way->{'id'} == 66761 || $way->{'id'} == -353494 || $way->{'id'} == -384560;

	my( $ctx, $aNodes ) = ( $way->{_context}, $way->{'nodes'} );
#	my %exclude = map {$_ => 1} @$aExclude;
	print STDERR "W $way->{id}: $text\n";
	for( my $i = 0; $i <= $#{$aNodes}; ++$i ){
		next if defined $hExclude->{$i};
		my $elev  = nodeElevation( $way, $i );
		if( defined $elev ){
			print STDERR "    [$i] $aNodes->[$i] - $elev\n";
			$hExclude->{$i} = $elev;
		}
	}
	return $hExclude;
}


sub shapeElevation {
	my( $way, $terrainTool, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my $tm = time();

	my $aNodes = $way->{'nodes'};
	if( $aNodes->[0] != $aNodes->[-1] && ! $hOpt->{'coastalPlain'} ){
		warn qq/shapeElevation: way $way->{'id'} not closed.\n/;
		return undef;
	}
	my $wayElev = $way->{'tags'}{$ELEVATION_TAG};
	print STDERR "shapeElevation wayElev = ", $wayElev, "\n";  # _DEBUG_
	if( $hOpt->{'boundaryTerrain'} ){
		elevationPointsFromTerrain( $way, $terrainTool, [], 999999 );
	}elsif( defined $wayElev ){
		map {nodeElevation($way,$_,$wayElev)} (0..$#{$aNodes});
	}else{
		elevationPointsFromTerrain( $way, $terrainTool, [], 0 ) if $hOpt->{'coastalPlain'};
		if( ! defined nodeElevation($way,0) ){
            if( defined nodeElevation($way,-1) ){
                nodeElevation( $way, 0, nodeElevation($way,-1) );
            }else{
                my @elevIdx = grep {defined nodeElevation($way,$_)} (0..$#{$aNodes}); 
                warn qq/shapeElevation; no elevation point available for way $way->{id}/ if ! @elevIdx;
                my( $i0, $i1, $n ) = ( $elevIdx[0], $elevIdx[1], $#{$aNodes} );
                my $elev = (($n-$i1) * nodeElevation($way,$i0) + $i0 * nodeElevation($way,$i1)) / ($i0 + $n - $i1);
                nodeElevation( $way, 0,  $elev );
                nodeElevation( $way, -1, $elev );
            }
        }
		linearElevation( $way, $terrainTool );
		foreach my $i ( 0..$#{$aNodes} ){
			my $elev = nodeElevation( $way, $i );
			print STDERR "A $way->{id} [$i] $aNodes->[$_] $elev\n" if $elev > 6000 || $elev < 0;
		}
	}
	my $aBorder = $terrainTool->getPathPoints( $way, {'linePoints' => 1, 'elevIndex' => 2} );
	foreach my $i ( 0..$#{$aBorder} ){
		my $elev = $aBorder->[$i][2];
		print STDERR "B $way->{id} [$i] $elev\n" if $elev > 6000 || $elev < 0;
	}

	my $aWay   = $terrainTool->getPathPoints( $way, {'linePoints' => 0, 'elevIndex' => 2} );
	my %points = map {OGF::Util::Shape::ptag($_) => $_} @$aBorder;
	my $shapeB = OGF::Util::Shape->new( {_width => 100000, _height => 100000}, \%points );
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$shapeB], ['shapeB'] ), "\n";  # _DEBUG_
#	foreach my $key ( keys %{$shapeB->{_shape}} ){  print "-- $key\n" if ! defined $shapeB->{_shape}{$key};  }  exit;

#	my $rectB = $shapeB->outerRectangle( 0, {'sizeOnly' => 1} );
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$rectB], ['rectB'] ), "\n";  # _DEBUG_

	unless( $hOpt->{'noBorder'} ){
        print STDERR "shapeElevation draw border\n";
        foreach my $pt ( $shapeB->points ){
			next if $hOpt->{'coastalPlain'} && $pt->[2] <= 0;
            my $ptX = [ $pt->[0], $pt->[1], $pt->[2] / $terrainTool->{_maxElev} ];
            $terrainTool->drawLinePoint( $ptX, $ptX );
#    		    $terrainTool->drawPixel( $pt, '#FF0000' );
            $terrainTool->canvas()->update();
        }
	}
    print STDERR "shapeElevation enclosedArea\n";
	my $shapeA = $hOpt->{'coastalPlain'} ? coastalPlainArea($shapeB,$terrainTool) : $shapeB->enclosedArea();

#	my $rectA = $shapeA->outerRectangle( 0, {'sizeOnly' => 1} );
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$rectA], ['rectA'] ), "\n";  # _DEBUG_

	my( $randFlag, $randMult ) = $hOpt->{'random'} ? @{$hOpt->{'random'}} : ( 0, 0 );
	my $mult = $hOpt->{'mult'} || 0;
	my( $ct, $size ) = ( 0, $shapeA->size() );
	print STDERR "\$ct <", $ct, ">  \$size <", $size, ">\n";  # _DEBUG_
	foreach my $pt ( $shapeA->points ){
		++$ct;
		next if defined $pt->[2];

		my $elev = (defined $wayElev)? $wayElev : borderDistanceElevation($pt,$aWay,1);
		$elev *= (1 - $randMult + rand(2 * $randMult)) if $randMult;
		$elev *= $mult if $mult;

#		my $ptX = [ $pt->[0], $pt->[1], $elev / $terrainTool->{_maxElev} ];
#		my $drawFlag = $randFlag ? (rand() <= $randFlag) : 1;
#		$terrainTool->drawLinePoint( $ptX, $ptX ) if $drawFlag;
		$terrainTool->setPixel_max( $pt->[0], $pt->[1], $elev, 0 );

		if( $ct % 1000 == 0 ){
			print STDERR qq|shapeElevation $way->{id}; $ct/$size  (elev=$elev)\n|;
			$terrainTool->canvas()->update();
		}
	}

	require OGF::Util::Line;
	my $aRect = OGF::Util::Line::boundingRect( $terrainTool->canvas(), $way->{_drawId}, 2 );
	$terrainTool->drawRectElev( $aRect );

	print "shapeElevation [", $way->{'id'}, "] duration: ", time() - $tm, " sec\n";;
	return $shapeA;
}

sub coastalPlainArea {
	my( $shape, $terrainTool ) = @_;
	my $cElev1 = sub {	$terrainTool->getTerrainElevation(@_) > 0 };

	my $rectOuter = $shape->outerRectangle( 1 )->filter( $cElev1 )->diff( $shape );
	my $rectFrame = $shape->outerRectangle( 1, {'frameOnly' => 1} );
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 1; print STDERR Data::Dumper->Dump( [$rectOuter], ['rectOuter'] ), "\n";  # _DEBUG_
	my @shapes = $rectOuter->connectedSubshapes( 'E4' );
#	print STDERR "\@shapes <", join('|',@shapes), ">\n";  # _DEBUG_
	@shapes = grep {OGF::Util::Shape::intersection(undef,$_,$rectFrame)->isEmpty()} @shapes;
	my $cpArea = OGF::Util::Shape::union( undef, @shapes );
	return $cpArea;
}

sub coastlineIntersectionWay {
	require OGF::Util::Line;
	my( $way, $terrainTool ) = @_;
	my $cnv = $terrainTool->canvas();
	my $aPoints = $cnv->ogfLinePoints( $way->{_drawId} );
	my @isctInfo = OGF::Util::Line::findIntersectLines( $cnv, $way->{_drawId}, {'natural' => 'coastline'}, $aPoints );
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 10; print STDERR Data::Dumper->Dump( [\@isctInfo], ['*isctInfo'] ), "\n";  # _DEBUG_
	die qq/Unexpected error: no intersecting coastline found for $way->{id}./ if ! @isctInfo;

	$OGF::Util::Line::MAX_APPLY_DIST = 999_999_999;
	my( $lineId, $aPointsNew ) = OGF::Util::Line::applyIntersection( $cnv, $way->{_drawId}, $aPoints, \@isctInfo, [['close_other']], {'retain' => 1} ) if @isctInfo;
	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$aPointsNew], ['aPointsNew'] ), "\n";  # _DEBUG_

#	my @coord = map {$_->[0],$_->[1]} @$aPointsNew;
#	my $lineIdNew = $cnv->createLine( @coord, -fill => '#00FF00' );
#	my $cstWay = $terrainTool->addWay( $lineIdNew );

	my $cstWay = $terrainTool->addWayExistingNodes( $aPointsNew, $lineId, $way->{_drawId} );
	my @elevIdx = map {nodeElevation($cstWay,$_) || '-'} (0..$#{$cstWay->{'nodes'}}); 
	print STDERR "cstWay \@elevIdx <", join('|',@elevIdx), ">\n";  # _DEBUG_

	return $cstWay;
}

sub drawCanvasWay {
	my( $terrainTool, $way, $tag ) = @_;
	print STDERR "drawCanvasWay $tag ", $way->{'id'}, "\n";
	my $lineId = $terrainTool->{_view}->drawWay( $way, $way->{_context} );
	$terrainTool->canvas->itemconfigure( $lineId, -arrow => 'last' );
}


sub borderDistanceElevation {
	my( $pt, $aPoints, $step ) = @_;
	$step = 1 if ! defined $step;
	my( $elev, $distS ) = ( 0, 0 );
	foreach( my $i = 0; $i < $#{$aPoints}; $i+=$step ){
		my $dist = OGF::Geo::Geometry::dist( $pt, $aPoints->[$i] );
		$dist = $dist * $dist;
		if( $dist == 0 ){
			( $elev, $dist ) = ( $aPoints->[$i][2], 1 );
			last;
		}
		$dist = 1 / $dist;
		$elev  += $aPoints->[$i][2] * $dist; 
		$distS += $dist;
	}
	$elev /= $distS;
	return $elev;
}



sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }


#-------------------------------------------------------------------------------

sub setContextElevation_Ridge_1 {
	my( $ctx, $terrainTool ) = @_;
	my $ctRepeat = 0;
	while( 1 ){
		die qq/setContextElevation_Ridge_1: ctRepeat exceeded/ if ++$ctRepeat >= 1000;
		my %ct = ( 0 => 0, 1 => 0, 2 => 0 );
        foreach my $way ( values %{$ctx->{_Way}} ){
			next unless $way->tagMatch( {'ogf:terrain' => 'ridge_1'} );
			my $ret = randomMountainElevation( $way );
			++$ct{$ret}
        }
		if( $ct{1} == 0 ){
			warn qq/setContextElevation_Ridge_1: $ct{0} unresolved dependencies/ if $ct{0} > 0;
			last;
		}
	}
}

sub setContextElevation_River {
	my( $ctx, $terrainTool ) = @_;
	setContextElevation_Coastline( $ctx, 0 );
	my $ctRepeat = 0;
	while( 1 ){
		die qq/setContextElevation_River: ctRepeat exceeded/ if ++$ctRepeat >= 1000;
		my %ct = ( 0 => 0, 1 => 0, 2 => 0 );
        foreach my $way ( values %{$ctx->{_Way}} ){
#       foreach my $way ( map {$ctx->{_Way}{$_}} ( 213166, 66761, -353494, -384560 ) ){
			next unless $way->tagMatch( {'waterway' => 'river'} );
			my $ret = linearElevation( $way, $terrainTool );
			++$ct{$ret}
        }
		if( $ct{1} == 0 ){
			warn qq/setContextElevation_River: $ct{0} unresolved dependencies/ if $ct{0} > 0;
			last;
		}
	}
}

sub setContextElevation_Coastline {
	my( $ctx, $terrainTool ) = @_;
    foreach my $way ( values %{$ctx->{_Way}} ){
        next unless $way->tagMatch( {'natural' => 'coastline'} );
        constantElevation( $way, 0 );
    }
}



#-------------------------------------------------------------------------------

sub drawContextElevation_Ridge_1 {
	my( $ctx, $terrainTool ) = @_;
    foreach my $way ( values %{$ctx->{_Way}} ){
        next unless $way->tagMatch( {'ogf:terrain' => 'ridge_1'} ) && $way->{_elevationFlag};
    	   print STDERR "ridge \$way <", $way->{'id'}, ">\n";  # _DEBUG_
		my $aPoints = $terrainTool->getPathPoints( $way, {'linePoints' => 1, 'elevIndex' => 3} );
		$terrainTool->applyTerrainInfo( $aPoints );
#		use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$aPoints], ['aPoints'] ), "\n";  # _DEBUG_
		$terrainTool->drawElevationPath( $aPoints, {'nosave' => 1} );
    }
}

sub drawContextElevation_River {
	my( $ctx, $terrainTool ) = @_;

    my $cnv = $terrainTool->canvas();
    my( $wd2, $hg2 ) = ( int($cnv->width / 2), int($cnv->height / 2) );
    
    foreach my $way ( values %{$ctx->{_Way}} ){
        next unless $way->tagMatch( {'waterway' => 'river'} ) && $way->{_elevationFlag};
    	   print STDERR "river \$way <", $way->{'id'}, ">\n";  # _DEBUG_
		my $aPoints = $terrainTool->getPathPoints( $way, {'linePoints' => 1, 'elevIndex' => 3} );

        my( $x, $y ) = @{$aPoints->[int($#{$aPoints} / 2)]};
        $cnv->ogfMoveView( $x-$wd2, $y-$hg2 );

		$terrainTool->applyTerrainInfo( $aPoints );
#		use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$aPoints], ['aPoints'] ), "\n";  # _DEBUG_
		$terrainTool->drawElevationPath( $aPoints, {'nosave' => 1} );
    }
}

sub drawContextElevation_Plateau {
	my( $ctx, $terrainTool ) = @_;
    foreach my $way ( values %{$ctx->{_Way}} ){
        next unless $way->tagMatch( {'ogf:terrain_area' => 'plateau'} );
    	   print STDERR "plateau \$way <", $way->{'id'}, ">\n";  # _DEBUG_
		my $shape = shapeElevation( $way, $terrainTool );
    }
}

sub drawContextElevation_Lake {
	my( $ctx, $terrainTool ) = @_;
    foreach my $way ( values %{$ctx->{_Way}} ){
        next unless $way->tagMatch( {'natural' => 'water'} );
    	   print STDERR "lake \$way <", $way->{'id'}, ">\n";  # _DEBUG_
		my $shape = shapeElevation( $way, $terrainTool );
    }
}

sub drawContextElevation_Karst {
	my( $ctx, $terrainTool ) = @_;
    foreach my $way ( values %{$ctx->{_Way}} ){
        next unless $way->tagMatch( {'ogf:terrain_area' => 'karst'} );
    	   print STDERR "karst \$way <", $way->{'id'}, ">\n";  # _DEBUG_
		my $shape1 = shapeElevation( $way, $terrainTool, {'noBorder' => 1, 'mult' => .3} );
		my $shape2 = shapeElevation( $way, $terrainTool, {'noBorder' => 1, 'random' => [.15,.3]} );
    }
}

sub drawContextElevation_Mountains {
	my( $ctx, $terrainTool ) = @_;
    foreach my $way ( values %{$ctx->{_Way}} ){
        next unless $way->tagMatch( {'ogf:terrain_area' => 'mountains_1'} );
    	   print STDERR "mountains \$way <", $way->{'id'}, ">\n";  # _DEBUG_
		$way->{'tags'}{$ELEVATION_TAG} = 2500;
		my $shape = shapeElevation( $way, $terrainTool );
    }
}

sub drawContextElevation_CoastalPlain {
	my( $ctx, $terrainTool ) = @_;
    foreach my $way ( values %{$ctx->{_Way}} ){
        if( $way->tagMatch( {'natural' => 'coastline'} ) ){
            drawCanvasWay( $terrainTool, $way, 'coastline' );
            map {nodeElevation($_,$ctx,1)} @{$way->{'nodes'}};
        }
    }

    foreach my $way ( values %{$ctx->{_Way}} ){
#   foreach my $way ( map {$ctx->{_Way}{$_}} ( -353650 ) ){
        next unless $way->tagMatch( {'ogf:terrain_area' => 'coastal_plain'} );
#		my $shape = shapeElevation( $way, $terrainTool, {'coastalPlain' => 1} );
        drawCanvasWay( $terrainTool, $way, 'coastal_plain' );
#		$terrainTool->canvas->update();
#		sleep 2;
		my $way2 = coastlineIntersectionWay( $way, $terrainTool );
		push @{$way2->{'nodes'}}, $way2->{'nodes'}[0];
#		use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 4; print STDERR Data::Dumper->Dump( [$way2], ['way2'] ), "\n";  # _DEBUG_
		my $shape = shapeElevation( $way2, $terrainTool );
    }
}






1;

