package OGF::Data::Consolidate;
use strict;
use warnings;
use OGF::Const;
use OGF::Data::Context;
use OGF::View::TileLayer;
use OGF::Geo::Topology;
use OGF::Geo::Geometry;



#-------------------------------------------------------------------------------

#sub connectAdjacentWays {
#	my( $ctx, $hOpt ) = @_;
#	$hOpt = {} if ! $hOpt;
#	my $tagMatch = $hOpt->{'tagMatch'} || undef;
#
#	foreach my $nodeUid ( grep {/^N/} keys %{$ctx->{_rev_info}} ){
#		my $hNodeInfo = $ctx->{_rev_info}{$nodeUid};
#		my @wayS = grep {$hNodeInfo->{$_} eq 'S'} keys %$hNodeInfo;
#		my @wayE = grep {$hNodeInfo->{$_} eq 'E'} keys %$hNodeInfo;
#		die qq/Unexpected error/ if $#wayS > 0 || $#wayE > 0;
#		next unless $#wayS == 0 && $#wayE == 0;
#
#		my( $wayA, $wayB ) = ( $ctx->getObject($wayE[0]), $ctx->getObject($wayS[0]) );
#		next if $tagMatch && !($wayA->tagMatch($tagMatch) && $wayB->tagMatch($tagMatch));
#		next if ! tagEqual( $wayA, $wayB );
#		next if $#{$wayA->{'nodes'}} + $#{$wayB->{'nodes'}} > 1990;
#		connectWays( $ctx, $wayA, $wayB );
#	}
#}

sub connectAdjacentWays {
	my( $ctx, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my $tagMatch = $hOpt->{'tagMatch'} || undef;

	my %ways = map {$_->{'id'} => $_} grep {$_->tagMatch($tagMatch)} values %{$ctx->{_Way}};
	my $aWays = OGF::Geo::Topology::buildWaySequence( $ctx, undef, \%ways, {'copy' => 1} );

	$ctx->{_Way} = { map {$_->{'id'} => $_} @$aWays };	
}

sub tagEqual {
	my( $wayA, $wayB ) = @_;
	my $tagA = join( '|', map {"$_=".$wayA->{'tags'}{$_}} sort keys %{$wayA->{'tags'}} );
	my $tagB = join( '|', map {"$_=".$wayB->{'tags'}{$_}} sort keys %{$wayB->{'tags'}} );
	return $tagA eq $tagB; 
}

sub connectWays {
	my( $ctx, $wayA, $wayB ) = @_;
	
	my( $wayIdA, $wayIdB, $nodeIdA, $nodeIdB ) = ( $wayA->uid, $wayB->uid, $ctx->{_Node}{$wayA->{'nodes'}[-1]}->uid, $ctx->{_Node}{$wayB->{'nodes'}[-1]}->uid );
	delete $ctx->{_rev_info}{$nodeIdA}{$wayIdB};
	delete $ctx->{_rev_info}{$nodeIdB}{$wayIdB};
	$ctx->{_rev_info}{$nodeIdA}{$wayIdA} = 1;
	$ctx->{_rev_info}{$nodeIdB}{$wayIdA} = (definedEqual($ctx->{_rev_info}{$nodeIdB}{$wayIdA},'S'))? 'C' : 'E';
	
	shift @{$wayB->{'nodes'}};
	push @{$wayA->{'nodes'}}, @{$wayB->{'nodes'}};
	foreach my $relUid ( keys %{$ctx->{_rev_info}{$wayIdB}} ){
		my $rel = $ctx->getObject( $relUid );
		$rel->removeMember( $wayB );
	}

#	print STDERR "remove $idB\n";
	delete $ctx->{_Way}{$wayB->{'id'}};
	delete $ctx->{_rev_info}{$wayIdB};
}

sub definedEqual {
	my( $valA, $valB ) = @_;
	return defined($valA) && $valA eq $valB;
}


#-------------------------------------------------------------------------------



sub connectNearbyWays {
	my( $ctx, $maxDist ) = @_;
	my $proj = $ctx->{_proj};

	my @ways = values %{$ctx->{_Way}};
	my $n = scalar(@ways);

	for( my $i = 0; $i < $n; ++$i ){
		my $wayA = $ways[$i];
		my( $nodeA0, $nodeA1 ) = ( $ctx->{_Node}{$wayA->{'nodes'}[0]}, $ctx->{_Node}{$wayA->{'nodes'}[-1]} );
		if( proj_dist_max($ctx,$nodeA0,$nodeA1,$maxDist) ){
			push @{$wayA->{'nodes'}}, $wayA->{'nodes'}[0];
		}
		for( my $j = 0; $j < $i; ++$j ){
			my $wayB = $ways[$j];
			my( $nodeB0, $nodeB1 ) = ( $ctx->{_Node}{$wayB->{'nodes'}[0]}, $ctx->{_Node}{$wayB->{'nodes'}[-1]} );

			if( proj_dist_max($ctx,$nodeA1,$nodeB0,$maxDist) ){
				push @{$wayA->{'nodes'}}, $wayB->{'nodes'}[0];
			}elsif( proj_dist_max($ctx,$nodeB1,$nodeA0,$maxDist) ){
				push @{$wayB->{'nodes'}}, $wayA->{'nodes'}[0];
			}elsif( proj_dist_max($ctx,$nodeA0,$nodeB0,$maxDist) ){
				unshift @{$wayA->{'nodes'}}, $wayB->{'nodes'}[0];
			}elsif( proj_dist_max($ctx,$nodeA1,$nodeB1,$maxDist) ){
				push @{$wayA->{'nodes'}}, $wayB->{'nodes'}[-1];
			}
		}
	}
}

sub proj_dist_max {
	my( $ctx, $nodeA, $nodeB, $maxDist ) = @_;
#	print STDERR "\$nodeA->{'id'} <", $nodeA->{'id'}, ">  \$nodeB->{'id'} <", $nodeB->{'id'}, ">\n";  # _DEBUG_
	return 0 if $nodeA->{'id'} == $nodeB->{'id'};
	my $dist = $ctx->dist( $nodeA, $nodeB );
#	print STDERR "\$dist <", $dist, ">\n";  # _DEBUG_
	return $dist < $maxDist;
}

sub removeWayLoops {
	my( $ctx, $hTagFilter, $aActions ) = @_;

	my @actions = qw/ident intersect antiparallel/;
	my %actions = map {$_ => 1} ($aActions ? @$aActions : @actions);
	my( $flag_ID, $flag_IS, $flag_AP ) = map {$actions{$_}} @actions;

	my( $i, $n ) = ( 0, scalar(values %{$ctx->{_Way}}) );
	foreach my $way ( values %{$ctx->{_Way}} ){
		next if $hTagFilter && ! OGF::Data::Context::tagMatch($way,$hTagFilter); 
		++$i;
		print STDERR "removeWayLoops: $i/$n ($way->{'id'})\n";
		OGF::Geo::Topology::removeLoops_ident( $ctx, $way )        if $flag_ID;
		OGF::Geo::Topology::removeLoops_intersect( $ctx, $way )    if $flag_IS;
		OGF::Geo::Topology::removeLoops_antiparallel( $ctx, $way ) if $flag_AP;
	}
}

sub setCoastlineOrientation {
	my( $ctx ) = @_;
	foreach my $way ( values %{$ctx->{_Way}} ){
		my $aPoints = $ctx->way2points( $way );
		my $ori = OGF::Geo::Geometry::array_orientation( $aPoints );
		print STDERR $way->{'id'}, " -> ", $ori, "\n";  # _DEBUG_
		if( $ori > 0 ){
			@{$way->{'nodes'}} = reverse @{$way->{'nodes'}};
		}
	}
}

sub removeUnusedNodes {
	my( $ctx ) = @_;
	$ctx->{_rev_info} = undef;
	$ctx->setReverseInfo();
	foreach my $nodeId ( keys %{$ctx->{_Node}} ){
		delete $ctx->{_Node}{$nodeId} if ! $ctx->{_rev_info}{"N|$nodeId"};
	}
}

sub removeMissingNodes {
	my( $ctx ) = @_;
	foreach my $way ( values %{$ctx->{_Way}} ){
		foreach my $nodeId ( @{$way->{'nodes'}} ){
			$nodeId = undef if ! $ctx->{_Node}{$nodeId};
		}
		@{$way->{'nodes'}} = grep {defined} @{$way->{'nodes'}};
	}
}



#-------------------------------------------------------------------------------

sub connectRiverSegments {
	my( $ctx ) = @_;

	foreach my $way ( values %{$ctx->{_Way}} ){
		delete $ctx->{_Way}{$way->{'id'}} if scalar(@{$way->{'nodes'}}) <= 4;
		@{$way->{'nodes'}} = reverse @{$way->{'nodes'}};
	}
	mergeEndSegments( $ctx, 0.1 );
	intersectWays( $ctx );		

	$ctx->setReverseInfo();
	foreach my $way ( values %{$ctx->{_Way}} ){
		removeShortEnd( $ctx, $way, 0, 10 );
	}
}	

sub removeShortEnd {
	my( $ctx, $way, $maxStart, $maxEnd ) = @_;
	my @nodes = @{$way->{'nodes'}};
	my( $n, $idxS, $idxE ) = ( $#nodes );
	for( my $i = 0; $i < $maxStart; ++$i ){
		my @waysS = keys %{$ctx->{_rev_info}{'N|'.$nodes[$i]}};
		$idxS = $i if scalar(@waysS) >= 2;
	}
	for( my $i = 0; $i < $maxEnd; ++$i ){
		my @waysE = keys %{$ctx->{_rev_info}{'N|'.$nodes[$n-$i]}};
		$idxE = $i if scalar(@waysE) >= 2;
	}
	splice @{$way->{'nodes'}}, -$idxE   if defined $idxE;
	splice @{$way->{'nodes'}}, 0, $idxS if defined $idxS;
}

sub mergeEndSegments {
	my( $ctx, $maxDist ) = @_;

	my @ways = values %{$ctx->{_Way}};
	foreach my $way ( values %{$ctx->{_Way}} ){
		$way->{_rectStart} = $way->boundingRectangle( $ctx, $ctx->{_proj},  5 );
		$way->{_rectEnd}   = $way->boundingRectangle( $ctx, $ctx->{_proj}, -5 );
#		print STDERR "\@{\$way->{_rectStart}} <", join('|',@{$way->{_rectStart}}), ">\n";  # _DEBUG_
#		print STDERR "\@{\$way->{_rectEnd}} <", join('|',@{$way->{_rectEnd}}), ">\n";  # _DEBUG_
	}

	my $n = scalar( @ways );
	my %dist;
	for( my $i = 0; $i < $n; ++$i ){
		for( my $j = 0; $j < $n; ++$j ){
			next if $i == $j;
			my $hDist = matrixDist( $ctx, $ways[$i], $ways[$j], $maxDist );
			if( $hDist ){
				print STDERR "dist $i:$ways[$i]{id} $j:$ways[$j]{id}\n";
				my $key = $ways[$i]{'id'} .','. $ways[$j]{'id'};
				$dist{$key} = $hDist;
			}
		}
	}

	foreach my $key ( keys %dist ){
		my( $idA, $idB ) = split /,/, $key;
		print STDERR "connect $idA $idB [$ctx->{_Way}{$idA}{id} $ctx->{_Way}{$idB}{id}]\n";
		matrixConnect( $ctx, $dist{$key}, $ctx->{_Way}{$idA}, $ctx->{_Way}{$idB} );
		map {$ctx->{_Way}{$_} = $ctx->{_Way}{$idA}} grep {$ctx->{_Way}{$_}{'id'} == $idB} keys %{$ctx->{_Way}};
	}

	map {delete $ctx->{_Way}{$_} if $ctx->{_Way}{$_}{'id'} != $_} keys %{$ctx->{_Way}};
}

sub matrixDist {
	my( $ctx, $wayA, $wayB, $maxDist ) = @_;
#	print STDERR "[1] $wayA->{id} $wayB->{id}\n";
	return undef unless OGF::Geo::Geometry::rectOverlap( $wayA->{_rectEnd}, $wayB->{_rectStart}, $maxDist );
#	print STDERR "[2] $wayA->{id} $wayB->{id}\n";

	my( $maxNum, $nA, $nB ) = ( 10, scalar(@{$wayA->{'nodes'}}), scalar(@{$wayB->{'nodes'}}) );
	return undef if $nA < $maxNum || $nB < $maxNum;

	my( $numA, $numB ) = ( -1, -1 );
	for( my $i = 0; $i < $maxNum; ++$i ){
		my $node = $ctx->{_Node}{$wayA->{'nodes'}[$nA-1-$i]};
		my( $x, $y ) = $ctx->{_proj}->geo2cnv( $node->{'lon'}, $node->{'lat'} );
		if( OGF::Geo::Geometry::rectContains($wayB->{_rectStart},[$x,$y],$maxDist) ){
			$numA = 0;
		}elsif( $numA >= 0 ){
			$numA = $i+2;
			last;
		}
	}
	for( my $i = 0; $i < $maxNum; ++$i ){
		my $node = $ctx->{_Node}{$wayB->{'nodes'}[$i]};
		my( $x, $y ) = $ctx->{_proj}->geo2cnv( $node->{'lon'}, $node->{'lat'} );
		if( OGF::Geo::Geometry::rectContains($wayA->{_rectEnd},[$x,$y],$maxDist) ){
			$numB = 0;
		}elsif( $numB >= 0 ){
			$numB = $i+2;
			last;
		}
	}
	return undef if $numA <= 0 || $numB <= 0;
	return undef if $nA < 2*$numA || $nB < 2*$numB;
#	print STDERR "[3] $wayA->{id} $wayB->{id}\n";

	my %dist = ( _numA => $numA, _numB => $numB );
	for( my $i = 0; $i < $numA; ++$i ){
		for( my $j = 0; $j < $numB; ++$j ){
			my( $nodeA, $nodeB ) = ( $ctx->{_Node}{$wayA->{'nodes'}[$nA-1-$i]}, $ctx->{_Node}{$wayB->{'nodes'}[$j]} );
			$dist{"$i,$j"} = $ctx->dist( $nodeA, $nodeB );
		}
	}
	return \%dist;
}

sub matrixConnect {
	my( $ctx, $hDist, $wayA, $wayB ) = @_;
	my( $numA, $numB ) = ( delete $hDist->{_numA}, delete $hDist->{_numB} );
	my $num = max( $numA, $numB );
	my @dist = sort {$hDist->{$a} <=> $hDist->{$b}} keys %$hDist;
	splice @dist, $num;

	my $nA = scalar(@{$wayA->{'nodes'}});
	my @newNodes;
	foreach my $key ( @dist ){
		my( $i, $j ) = split /,/, $key;
		my $nodeA = $ctx->{_Node}{$wayA->{'nodes'}[$nA-1-$i]};
		my $nodeB = $ctx->{_Node}{$wayB->{'nodes'}[$j]};
		my( $xA, $yA ) = $ctx->{_proj}->geo2cnv( $nodeA->{'lon'}, $nodeA->{'lat'} );
		my( $xB, $yB ) = $ctx->{_proj}->geo2cnv( $nodeB->{'lon'}, $nodeB->{'lat'} );
		my( $lon, $lat ) = $ctx->{_proj}->cnv2geo( ($xA+$xB)/2, ($yA+$yB)/2 );
		my $node = OGF::Data::Node->new( $ctx, {'lon' => $lon, 'lat' => $lat} );
		push @newNodes, [ $j*2*$num - $i, $node ];
	}
	@newNodes = map {$_->[1]{'id'}} sort {$a->[0] <=> $b->[0]} @newNodes;

	splice @{$wayA->{'nodes'}}, $nA-$numA;
	splice @{$wayB->{'nodes'}}, 0, $numB;
	push @{$wayA->{'nodes'}}, @newNodes, @{$wayB->{'nodes'}};
}


#-------------------------------------------------------------------------------

sub makeMotorways {
	my( $ctx ) = @_;
	foreach my $way ( values %{$ctx->{_Way}} ){
		delete $ctx->{_Way}{$way->{'id'}} if scalar(@{$way->{'nodes'}}) <= 4;
		@{$way->{'nodes'}} = reverse @{$way->{'nodes'}};
	}
	mergeEndSegments( $ctx, 0.1 );
	removeWayLoops( $ctx );

	foreach my $way ( values %{$ctx->{_Way}} ){
		makeDirectionLanes( $ctx, $way, 16 );
	}
}

sub makeDirectionLanes {
	require Math::Trig;
	my( $ctx, $way, $dist ) = @_;
	my( $dist2, $n ) = ( $dist/2, scalar(@{$way->{'nodes'}}) );

	my $wayR = OGF::Data::Way->new( $ctx, {'tags' => $way->{'tags'}, 'nodes' => []} );
	my $wayL = OGF::Data::Way->new( $ctx, {'tags' => $way->{'tags'}, 'nodes' => []} );
	my $len = 100;

	for( my $i = 0; $i < $n; ++$i ){
		my( $node, $nodeA, $nodeB ) = ( $ctx->{_Node}{$way->{'nodes'}[$i]} );
		my $proj = OGF::View::Projection->latitudeProjection( $node->{'lat'}, 1 );
		my( $vA, $vB, $vN ) = ( [0,0], [0,0] );
		my( $x,$y, $xA,$yA, $xB,$yB ) = $proj->geo2cnv( $node->{'lon'}, $node->{'lat'} );
		if( $i >= 1 ){
			$nodeA = $ctx->{_Node}{$way->{'nodes'}[$i-1]};
			( $xA, $yA ) = $proj->geo2cnv( $nodeA->{'lon'}, $nodeA->{'lat'} );
			$vA = OGF::Geo::Geometry::vecToLength( [$xA-$x,$yA-$y], $len );
		}
		if( $i <= $n-2 ){
			$nodeB = $ctx->{_Node}{$way->{'nodes'}[$i+1]};
			( $xB, $yB ) = $proj->geo2cnv( $nodeB->{'lon'}, $nodeB->{'lat'} );
			$vB = OGF::Geo::Geometry::vecToLength( [$xB-$x,$yB-$y], $len );
		}

		my( $ang ) = ($i >= 1 && $i <= $n-2)? OGF::Geo::Geometry::angleInfo([0,0],$vA,$vB) : ($OGF::PI);
		my $dd = $dist2 / sin($ang/2);

		$vN = OGF::Geo::Geometry::vecToLength( [-($vB->[1] - $vA->[1]), $vB->[0] - $vA->[0]], $dd );
#		print STDERR "\$dd <", $dd, ">  \@\$vN <", join('|',@$vN), ">\n";  # _DEBUG_

		my( $lonR, $latR, $lonL, $latL ) = ( $proj->cnv2geo($x+$vN->[0],$y+$vN->[1]), $proj->cnv2geo($x-$vN->[0],$y-$vN->[1]) );
		$wayR->add_node( OGF::Data::Node->new($ctx, {'lon' => $lonR, 'lat' => $latR}) );
		$wayL->add_node( OGF::Data::Node->new($ctx, {'lon' => $lonL, 'lat' => $latL}) ); 
	}

	@{$wayL->{'nodes'}} = reverse @{$wayL->{'nodes'}};
	delete $ctx->{_Way}{$way->{'id'}};
}


#-------------------------------------------------------------------------------


sub intersectBoundaries {
	my( $ctx ) = @_;
	intersectWays( $ctx );
	$ctx->setReverseInfo();
	foreach my $way ( values %{$ctx->{_Way}} ){
		$ctx->splitIntersect( $way, {'removeEnds' => 1} );
	}
}

sub intersectWays {
	my( $ctx ) = @_;
	my @ways = values %{$ctx->{_Way}};
	my $n = scalar( @ways );
	for( my $i = 0; $i < $n; ++$i ){
		for( my $j = $i+1; $j < $n; ++$j ){
			OGF::Geo::Topology::pconnect( $ctx, $ways[$i], $ways[$j] );
		}
	}
}

sub splitWaysAtJunctions {
	my( $ctx ) = @_;
	$ctx->setReverseInfo();
	foreach my $way ( values %{$ctx->{_Way}} ){
		for( my $i = $#{$way->{'nodes'}} - 1; $i > 0; --$i ){
			my $nodeId = $way->{'nodes'}[$i];
			if( scalar(values %{$ctx->{_rev_info}{'N|'.$nodeId}}) > 1 ){
				splitWay( $ctx, $way, $i );
			}
		}
	}
}

sub splitWay {
	my( $ctx, $way, $i ) = @_;

	my $iE = $#{$way->{'nodes'}};
	my $aNodes = [ @{$way->{'nodes'}}[$i .. $iE] ];   
	@{$way->{'nodes'}} = @{$way->{'nodes'}}[0 .. $i];

	my $newWay = OGF::Data::Way->new( $ctx, {'tags' => $way->{'tags'}, 'nodes' => $aNodes} );
	return $newWay;
}

sub makeBoundaryRelations {
	my( $ctx ) = @_;
	$ctx->setReverseInfo();

	foreach my $node ( values %{$ctx->{_Node}} ){
		my $hWays = $ctx->{_rev_info}{$node->uid};
		my @ways = map {$ctx->getObject($_)} grep {$hWays->{$_} =~ /^[SE]$/} keys %$hWays;
		$node->{_ways} = [ sort {$a->[2] <=> $b->[2]} map {azimuth($ctx,$node,$_)} @ways ];
	}

	my %bndRel;
	foreach my $way ( values %{$ctx->{_Way}} ){
		followBoundary( $ctx, $way,  1, \%bndRel );
		followBoundary( $ctx, $way, -1, \%bndRel );
	}

	my %latCache;
	my $ct = 0;
	foreach my $key ( keys %bndRel ){
		print STDERR "\$key <", $key, ">\n";  # _DEBUG_
		my @members = map {{'type' => 'Way', 'role' => 'outer', 'ref' => $_}} @{$bndRel{$key}};
		my $rel = OGF::Data::Relation->new( $ctx, {'members' => \@members, 'tags' => {
#			'type'        => 'multipolygon',
#			'natural'     => 'water',
			'type'        => 'boundary',
			'boundary'    => 'administrative',
			'admin_level' => 2,
			'ogf:owner'   => '[free]',
		}} );

		if( isContinent($ctx,$rel) ){
			$rel->{'tags'}{'ogf:continent'} = 'yes';
#			$rel->{'id'} += 100000;
		}

		my $aRect = $rel->boundingRectangle();
		my $lat = int( ($aRect->[3] + $aRect->[1]) / 2 );
#		$lat = 100 - $lat if $lat < 0;
		$lat = ($lat < 0)? -$lat : 100 + $lat;
		++$lat while $latCache{$lat};
#		my $fmt = ($lat >= 125)? 'AN%03d' : 'TA%03d';
		my $fmt = 'AR%03d';
		$rel->{'tags'}{'ogf:id'} = $rel->{'tags'}{'name'} = sprintf($fmt,$lat);
		$latCache{$lat} = 1;
	}
}

sub isContinent {
	my( $ctx, $rel ) = @_;
	my $aRect = $rel->boundingRectangle();
	return ($aRect->[3] - $aRect->[1]) > 20;

#	my $isContinent = 1;
#	foreach my $mb ( @{$rel->{'members'}} ){
#		my $way = $ctx->{_Way}{$mb->{'ref'}};
#		unless( $tway->{'tags'}{'natural'} && $tway->{'tags'}{'natural'} eq 'coastline' ){
#			$isContinent = 0;
#			last;
#		}
#	}
}

sub followBoundary {
	my( $ctx, $way, $ori, $hRel ) = @_;
	my $wayId = $way->{'id'};
#	print STDERR "\$wayId <", $wayId, ">\n";  # _DEBUG_
	my @memberList = ( $wayId );

	if( $way->{'nodes'}[0] != $way->{'nodes'}[-1] ){
		my $iEnd = -1;
		while( 1 ){
			my $node = $ctx->{_Node}{$way->{'nodes'}[$iEnd]};
#			print STDERR "  \$node <", $node->{'id'}, ">  ";  # _DEBUG_
			my $n = $#{$node->{_ways}};
			my( $i ) = grep {$node->{_ways}[$_][0] == $wayId} (0..$n);
#			print STDERR "  \$i <", $i, ">  ";  # _DEBUG_
			my $hNext	= $node->{_ways}[($i+$ori) % ($n+1)];
			( $wayId, $iEnd ) = ( $hNext->[0], -1 - $hNext->[1] );
#			print STDERR "  \$wayId <", $wayId, ">  \$iEnd <", $iEnd, ">\n";  # _DEBUG_
			last if $wayId == $memberList[0];
			$way = $ctx->{_Way}{$wayId};
			push @memberList, $wayId;
		}
	}	

	my $key = join( '|', sort {$a <=> $b} @memberList );
	$hRel->{$key} = \@memberList;
}

sub azimuth {
	my( $ctx, $node, $way ) = @_;
	my( $i, $nodeB );
	if( $node->{'id'} == $way->{'nodes'}[0] ){
		( $i, $nodeB ) = ( 0, $way->{'nodes'}[1] );
	}elsif( $node->{'id'} == $way->{'nodes'}[-1] ){
		( $i, $nodeB ) = ( -1, $way->{'nodes'}[-2] );
	}else{
		die qq/Node $node->{id} is neither start nor end of way $way->{id}./;
	}
	$nodeB = $ctx->{_Node}{$nodeB};
#	print STDERR "\%\$node <", join('|',%$node), ">  \%\$nodeB <", join('|',%$nodeB), ">\n";  # _DEBUG_
	my( $angle, $sign ) = $ctx->angleInfo( $node, $nodeB );
	$angle = 2 * $OGF::PI - $angle if $sign < 0;
	return [ $way->{'id'}, $i, $angle ];
}



#-------------------------------------------------------------------------------


sub splitWays_MaxLength {
	my( $ctx, $maxlen ) = @_;
	$ctx->setReverseInfo();

	my %newWayIds;
	foreach my $way ( values %{$ctx->{_Way}} ){
		my $len = scalar( @{$way->{'nodes'}} );
		next if $len <= $maxlen;

		my @newWays;
		my $newLen = int( $len / (int($len/($maxlen+1)) + 1) ) + 1;
		for( my $i = 0; $i < $len; $i += $newLen ){
			my $iE = min( $i+$newLen, $len-1 );
			push @newWays, [ @{$way->{'nodes'}}[$i .. $iE] ];   
			print STDERR "split ", ($iE - $i + 1), "\n";
		}

		$way->{'nodes'} = $newWays[0];
		$newWayIds{$way->{'id'}} = [];
		for( my $i = 1; $i <= $#newWays; ++$i ){
			my $newWay = OGF::Data::Way->new( $ctx, {'tags' => $way->{'tags'}, 'nodes' => $newWays[$i]} );
			push @{$newWayIds{$way->{'id'}}}, $newWay->{'id'};
		}
	}
}

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }


#-------------------------------------------------------------------------------


sub makeRoantraProvinceRelations {
	my( $ctx ) = @_;
	connectOuterRelations( $ctx, {'admin_level' => 4, 'name' => 'Torxa'},     {'admin_level' => 6, 'name' => [ 'Bacrayil', 'Olxara', 'Badxebra', 'Sirgrodi', 'Chaorlem', 'Ducalinad', 'Neshabro' ]} );
	connectOuterRelations( $ctx, {'admin_level' => 4, 'name' => 'Salxolena'}, {'admin_level' => 6, 'name' => [ 'Arnamun', 'Olamsholan', 'Eltacha', 'Nabbalid', 'Odberexa' ]} );
	connectOuterRelations( $ctx, {'admin_level' => 4, 'name' => 'Beldaed'},   {'admin_level' => 6, 'name' => [ 'Aranabedcha', 'Cherpar', 'Shanulchasi' ]} );
	connectOuterRelations( $ctx, {'admin_level' => 4, 'name' => 'Talpatxa'},  {'admin_level' => 6, 'name' => [ 'Unchayem', 'Xharenshe', 'Bannonib', 'Sabazha', 'Izolan', 'Edodaunis' ]} );
	connectOuterRelations( $ctx, {'admin_level' => 4, 'name' => 'Yashbo'},    {'admin_level' => 6, 'name' => [ 'Enzhizayben', 'Glilunshe' ]} );
	connectOuterRelations( $ctx, {'admin_level' => 2, 'name' => 'Roantra'},   {'admin_level' => 4, 'name' => [ 'Yasheu', 'Yushtabere', 'Coyem', 'Donshoyex', 'Xhishoyalil', 'Neshtasan', 'Imxhaulol', 'Sadalbe',
		'Pegralya', 'Padashemya', 'Zhigrodxa', 'Yeyanagro', 'Beyabad', 'Oxzpocotan', 'Bechorud', 'Nafyashoim', 'Ulceshoy', 'Shananda', 'Chamdenaid', 'Tuxuir', 'Dalaran', 'Asodesh', 'Torxa', 'Salxolena',
		'Beldaed', 'Talpatxa', 'Yashbo' ]} );
}

sub connectOuterRelations {
	my( $ctx, $hTags, $hMatch ) = @_;
	my $ctx2 = $ctx->cloneContext( 'Relation', $hMatch );
	$ctx2->setReverseInfo();

	my $rel = $ctx2->cloneObject( (values %{$ctx2->{_Relation}})[0] );
	$rel->{'id'}      = undef;
	$rel->{'members'} = [];
	map {$rel->{'tags'}{$_} = $hTags->{$_}} keys %$hTags;
	$ctx->addObject( 'Relation', $rel );
	print $rel->toString, "\n";

	foreach my $way ( values %{$ctx->{_Way}} ){
		if( scalar(keys %{$ctx2->{_rev_info}{$way->uid}}) == 1 ){
			my $relRev = $ctx2->getObject( (keys %{$ctx2->{_rev_info}{$way->uid}})[0] );
			my( $mbRev ) = grep {$_->{'type'} eq 'Way' && $_->{'ref'} == $way->{'id'}} @{$relRev->{'members'}};
			push @{$rel->{'members'}}, {'type' => 'Way', 'role' => $mbRev->{'role'}, 'ref' => $way->{'id'}};	
		}
	}

	my $aRelOrder = OGF::Geo::Topology::buildWaySequence( $ctx, $rel, undef, {'copy' => 1, 'relOrder' => 1} );
#	use Data::Dumper; local $Data::Dumper::Indent = 0; print STDERR Data::Dumper->Dump( [$aRelOrder], ['aRelOrder'] ), "\n";  # _DEBUG_
	my @flatOrder = map {@$_} @$aRelOrder;
	my %members = map {$_->{'ref'} => $_} @{$rel->{'members'}};
	$rel->{'members'} = [ map {$members{$_}} @flatOrder ];

#	$rel->{'tags'}{'ogf:consolidate'} = 'x';
	return $rel;
}

#-------------------------------------------------------------------------------


sub convertProvinceLandAreas {
	my( $ctx ) = @_;

	foreach my $rel ( values %{$ctx->{_Relation}} ){
		my $rel2 = $ctx->cloneObject( $rel ); 
		$rel->{'tags'}{'type'} = 'multipolygon';
		$rel->{'tags'}{'land_area'} = delete $rel->{'tags'}{'boundary'};

		$rel2->{'id'} = -- $ctx->{_new_ID};
		$rel2->{'tags'}{'type'} = 'boundary';
		$ctx->addObject( 'Relation', $rel2 );
#		print join( '|', map {%{$_->{'tags'}}} map { $ctx->{'_'.$_->{'type'}}{$_->{'ref'}} } @{$rel2->{'members'}} ), "\n";
		@{$rel2->{'members'}} = grep {! OGF::Data::Context::tagMatch($ctx->{'_'.$_->{'type'}}{$_->{'ref'}}, {'natural' => 'coastline'})} @{$rel2->{'members'}};
	}
}


#-------------------------------------------------------------------------------


sub calculateRelationAreas {
	require OGF::Geo::Measure;
	my( $ctx ) = @_;

	foreach my $rel ( values %{$ctx->{_Relation}} ){
		my $hTags = $rel->{'tags'};
		print STDERR $rel->{'id'}, " " , $hTags->{'type'}, " ";
		print STDERR $hTags->{'name'},   " " if $hTags->{'name'};
		print STDERR $hTags->{'ogf:id'}, " " if $hTags->{'ogf:id'};
		my $area = eval {  OGF::Geo::Measure::geoArea( $rel, $ctx );  };
		warn $@ if $@;
		print STDERR " -> $area\n";
	}
}

# http://opengeofiction.net/api/0.6/relation/4465/full

sub calculateRelationAreas_wiki {
	require OGF::Geo::Measure;
	require Date::Format;
	require FileHandle;
	my( $ctx ) = @_;
	my $outFile = Date::Format::time2str( 'C:/Backup/OGF/calculate_area_%Y%m%d_%H%M.txt', time );
	my $fh = FileHandle->new( $outFile, '>:encoding(UTF-8)' ) or die qq/Cannot open outfile "$outFile" for writing $!/;

	$fh->print( << 'EOF' );
{| class="wikitable sortable"
|-
! id
! name
! ogf:area
! type
! admin_level
! maritime
! area (km<sup>2</sup>)
! comment
EOF

#	foreach my $rel ( values %{$ctx->{_Relation}} ){
	foreach my $rel ( map {$ctx->{_Relation}{$_}} sort {$a <=> $b} keys %{$ctx->{_Relation}} ){
		my $hTags = $rel->{'tags'};
		my $id    = $rel->{'id'};
		my $name  = $hTags->{'name'} || '';
		my $refId = $hTags->{'ogf:area'} || $hTags->{'ref'} || $hTags->{'ogf:id'} || '';
		my $type  = $hTags->{'land_area'} ? 'land_area' : 'boundary';
		my $admin_level  = $hTags->{'admin_level'} || 'unknown';
		my @mar = grep {OGF::Data::Context::tagMatch($_,{'maritime' => 'yes'})} map {$ctx->{_Way}{$_->{'ref'}}} grep {$_->{'type'} eq 'Way'} @{$rel->{'members'}};
		my $has_maritime = @mar ? 'x' : '';
		my $area = 0;
		my @comment;

		$type = "[http://opengeofiction.net/api/0.6/relation/$id/full $type]";
		$id   = "[http://opengeofiction.net/relation/$id $id]";

		eval {  
			die qq/relation is empty\n/ if ! @{$rel->{'members'}};
			die qq/relation contains no ways/ if ! (grep {$_->{'type'} eq 'Way'} @{$rel->{'members'}});
			push @comment, qq/relation members have undefined role/ if (grep {! $_->{'role'}} @{$rel->{'members'}});
			$area = OGF::Geo::Measure::geoArea( $rel, $ctx );
			$area = sprintf '%.2f', $area;
		};
		if( $@ ){
			my $comment = $@;
			$comment =~ s|\n$||;
			$comment =~ s|node (\d+)|node [http://opengeofiction.net/node/$1 $1]|;
			push @comment, $comment;
			warn "ERROR $id $name: $comment\n";
		}
		my $comment = join( '<br>', @comment );
		$fh->print( << "EOF" );
|-
| '''$id''' || $name || $refId || $type || $admin_level || $has_maritime || $area || $comment
EOF
	}

	$fh->print( "|}\n" );
}

sub calculateRelationAreas_html {
	require OGF::Geo::Measure;
	require Date::Format;
	require FileHandle;
	my( $ctx, $outFile ) = @_;
	my $dtime = Date::Format::time2str( '%Y-%m-%d %H:%M UTC', time, 'UTC' );

	my $fh = FileHandle->new( $outFile, '>:encoding(UTF-8)' ) or die qq/Cannot open outfile "$outFile" for writing $!/;
	$fh->print( << "EOF" );
<html><head><title>OGF Area Table</title>
<meta charset="UTF-8">
<style type='text/css'> body {font-family:Arial; }</style>

<script src="https://code.jquery.com/jquery-3.1.1.min.js"></script>
<script src="https://cdn.datatables.net/1.10.12/js/jquery.dataTables.min.js"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/1.10.12/css/jquery.dataTables.min.css">
<script type="text/javascript">
\$(document).ready(function() {
    \$('#adminarea').DataTable({ paging: true, pageLength: 2000, order: [[0,'asc']], columns: [
		null,
		null,
		null,
		null,
		{width: "60px"},
		{width: "60px"},
		{className: "dt-body-right"},
		null,
	] });
} );
</script>

</head><body>
OGF area table generated at $dtime <hr>
<table id="adminarea" class="cell-border stripe" style="font-size:10pt;">
<thead>
EOF

	writeTableRow( $fh, 'th', [
        'id',
        'name',
        'ogf:area',
        'type',
        'admin_level',
        'maritime',
        'area (km<sup>2</sup>)',
        'comment',
	] );
	$fh->print( "</thead><tbody>" );

#	foreach my $rel ( values %{$ctx->{_Relation}} ){
	foreach my $rel ( map {$ctx->{_Relation}{$_}} sort {$a <=> $b} keys %{$ctx->{_Relation}} ){
		my $hTags = $rel->{'tags'};
		my $id    = $rel->{'id'};
		my $name  = $hTags->{'name'} || '';
		my $refId = $hTags->{'ogf:area'} || $hTags->{'ref'} || $hTags->{'ogf:id'} || '';
		my $type  = $hTags->{'land_area'} ? 'land_area' : 'boundary';
		my $admin_level  = $hTags->{'admin_level'} || 'unknown';
		my @mar = grep {OGF::Data::Context::tagMatch($_,{'maritime' => 'yes'})} map {$ctx->{_Way}{$_->{'ref'}}} grep {$_->{'type'} eq 'Way'} @{$rel->{'members'}};
		my $has_maritime = @mar ? 'x' : '';
		my $area = 0;
		my @comment;

#		$type = "[http://opengeofiction.net/api/0.6/relation/$id/full $type]";
#		$id   = "[http://opengeofiction.net/relation/$id $id]";

		$type = htmlLink( "http://opengeofiction.net/api/0.6/relation/$id/full", $type );
		$id   = htmlLink( "http://opengeofiction.net/relation/$id", $id );

		eval {  
			die qq/relation is empty\n/ if ! @{$rel->{'members'}};
			die qq/relation contains no ways/ if ! (grep {$_->{'type'} eq 'Way'} @{$rel->{'members'}});
			push @comment, qq/relation members have undefined role/ if (grep {! $_->{'role'}} @{$rel->{'members'}});
			$area = OGF::Geo::Measure::geoArea( $rel, $ctx );
			$area = sprintf '%.2f', $area;
		};
		if( $@ ){
			my $comment = $@;
			$comment =~ s|\n$||;
			$comment =~ s|node (\d+)|'node '.htmlLink("http://opengeofiction.net/node/$1",$1)|e;
			push @comment, $comment;
			warn "ERROR $id $name: $comment\n";
		}
		my $comment = join( '<br>', @comment );
		writeTableRow( $fh, 'td', [ $id, $name, $refId, $type, $admin_level, $has_maritime, $area, $comment ] );
	}

	$fh->print( << 'EOF' );
</tbody>
</table>
</body></html>
EOF

}


sub htmlLink {
	my( $url, $text ) = @_;
	$text = $url if ! $text;
	my $link = '<a href="'. $url .'">'. $text .'</a>';
	return $link;
}

sub writeTableRow {
	my( $fh, $tag, $aValues ) = @_;
	$fh->print( "<tr>" );
	foreach my $val ( @$aValues ){
		$fh->print( "<$tag>", $val, "</$tag>" );
	}
	$fh->print( "</tr>\n" );
}

#-------------------------------------------------------------------------------


sub closedWayComponents {
	my( $ctx ) = @_;
	my $ctx2 = OGF::Data::Context->new();	

	if( ! %{$ctx->{_Relation}} ){
		my $rel = OGF::Data::Relation->new( $ctx, '' );		
		$rel->add_member( 'outer', values %{$ctx->{_Way}} );
	}

	my $newId = -1000;
	foreach my $rel ( values %{$ctx->{_Relation}} ){
		my $rel2 = $ctx->cloneObject( $rel );
		$rel2->{'members'} = [];
		$ctx2->addObject( 'Relation', $rel2 );
		my $aRelWays = $rel->closedWayComponents( 'outer' );
		map {$_->{'id'} = --$newId} @$aRelWays;
		map {$ctx2->addObject('Way',$_)} @$aRelWays;
		$rel2->add_member( 'outer', @$aRelWays );
	}

	foreach my $way ( values %{$ctx2->{_Way}} ){
		$way->{'version'} = 1;
		map {$ctx2->{_Node}{$_} = $ctx->{_Node}{$_}} @{$way->{'nodes'}};
	}
	$_[0] = $ctx2;
}


#-------------------------------------------------------------------------------

sub validateCoastline {
	my( $ctx ) = @_;
	my $rel = OGF::Data::Relation->new( $ctx, {'tags' => {}, 'members' => []} );

	foreach my $way ( values %{$ctx->{_Way}} ){
		next unless OGF::Data::Context::tagMatch( $way, {'natural' => 'coastline'} );
		$rel->add_member( 'outer', $way );
	}

	my $aRelWays = $rel->closedWayComponents( 'outer', {'wayDirection' => 1} );
}


#-------------------------------------------------------------------------------

sub moveLonCoord {
	my( $ctx, $dx ) = @_;
	foreach my $node ( values %{$ctx->{_Node}} ){
		my $lon = $node->{'lon'};
		$lon += $dx;
		$lon -= 360 if $lon > 180;
		$node->{'lon'} = $lon;
	}
}


#-------------------------------------------------------------------------------

sub applyOwnerMap {
	my( $ctx, $ogfMapFile ) = @_;

	my $ctxMap = OGF::Data::Context->new();
	$ctxMap->loadFromFile( $ogfMapFile );
	my $hMap = {};
	foreach my $rel ( sort {$a->{'tags'}{'ogf:id'} cmp $b->{'tags'}{'ogf:id'}} values %{$ctxMap->{_Relation}} ){
#		print STDERR "A \$rel->{'tags'}{'ogf:id'} <", $rel->{'tags'}{'ogf:id'}, ">\n";  # _DEBUG_
		$hMap->{$rel->{'tags'}{'ogf:id'}} = $rel->{'tags'};
#		print STDERR "\$hMap->{\$rel->{'tags'}{'ogf:id'}} <", join('|',%{$hMap->{$rel->{'tags'}{'ogf:id'}}}), ">\n";  # _DEBUG_
	}

	foreach my $rel ( sort {$a->{'tags'}{'ogf:id'} cmp $b->{'tags'}{'ogf:id'}} values %{$ctx->{_Relation}} ){
		my $hTags = $rel->{'tags'};
		my( $ogfId, $owner, $name ) = ( $hTags->{'ogf:id'}, $hTags->{'ogf:owner'}, $hTags->{'name'} );
#		print STDERR "\$ogfId <", $ogfId, ">  \$owner <", $owner, ">  \$name <", $name, ">\n";  # _DEBUG_
		if( ! $ogfId || ! $owner || ! $name ){
			warn qq/Missing ogf:id, ogf:owner or name:\n/, $rel->toString(), "\n";
			next;
		}
		$ogfId =~ s/^([a-z]+)/uc($1)/ie;
		unless( $ogfId =~ /^(UL|TA|AN|AR)\d{3}$/ ){
			warn qq/Non-standard ogf:id detected: $ogfId\n/;
			next;
		}
		$hTags->{'name'}      = $hMap->{$ogfId}{'name'}      if $hMap->{$ogfId};
		$hTags->{'ogf:owner'} = $hMap->{$ogfId}{'ogf:owner'} if $hMap->{$ogfId};
#		print STDERR "  \$hTags->{'name'} <", $hTags->{'name'}, ">  \$hTags->{'ogf:owner'} <", $hTags->{'ogf:owner'}, ">\n";  # _DEBUG_
		$hTags->{'ogf:id'} = $ogfId;
		$hTags->{'name'}   = $ogfId if uc($hTags->{'name'}) eq uc($ogfId);
		$hTags->{'ogf:owner'} = '['. $owner .']' if $owner =~ /^(free|all)$/;
	}
}


#-------------------------------------------------------------------------------

sub removeLandareaCountryRelations {
	my( $ctx ) = @_;

	my $hMap = {};
	foreach my $rel ( values %{$ctx->{_Relation}} ){
		my $ogfId = $rel->{'tags'}{'ogf:id'};
		next if ! $ogfId;
		$hMap->{$ogfId} = 1 if $rel->{'tags'}{'land_area'};
	}
	
	my @deleteList;
	foreach my $rel ( values %{$ctx->{_Relation}} ){
		my $ogfId = $rel->{'tags'}{'ogf:id'};
		if( ! $ogfId ){
			push @deleteList, $rel->{'id'};
			next;
		}
		push @deleteList, $rel->{'id'} if $hMap->{$ogfId} && ! $rel->{'tags'}{'land_area'};
	}

	map {delete $ctx->{_Relation}{$_}} @deleteList;
}


#-------------------------------------------------------------------------------

sub simplifyWays {
	require OGF::Draw::WayDraw;
	require OGF::Geo::Geometry;
	my( $ctx, $avwThreshold, $minArea ) = @_;
	( $avwThreshold, $minArea ) = ( 4.5, 20 ) if ! defined $avwThreshold;
#	( $avwThreshold, $minArea ) = ( 10, 30 ) if ! defined $avwThreshold;

	my( $wsz, $wd, $hg ) = ( 20037508.3427892, 4000, 4000 );
	my $hTransf = { 'X' => [ -$wsz => 0, $wsz => $wd ], 'Y' => [ $wsz => 0, -$wsz => $hg ] };
	my $proj = OGF::View::Projection->new( '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs', $hTransf );

	foreach my $way ( values %{$ctx->{_Way}} ){
		next unless OGF::Geo::Geometry::rectOverlap( $way->boundingRectangle($ctx), [25.97,43.14,31.34,47.10] );  # only inside Roantra rectangle
		my @points = map {$proj->geo2cnv($_)} map {[$_->{'lon'},$_->{'lat'}]} map {$ctx->{_Node}{$_}} @{$way->{'nodes'}};
		print STDERR "way: ", $way->{'id'}, "  ogfId: ", ($way->{'tags'}{'ogf:id'} || ''), "  size: ", $#points, "\n";  # _DEBUG_
#		my $aIndex = OGF::Draw::WayDraw::algVisvalingamWhyatt( \@points, {'indexOnly' => 1, 'threshold' => $AVW_THRESHOLD} );
		my $aIndex = OGF::Util::Line::algVisvalingamWhyatt( \@points, {'indexOnly' => 1, 'threshold' => $avwThreshold} );
		@{$way->{'nodes'}} = map {$way->{'nodes'}[$_]} @$aIndex;
		my $aRect = $way->boundingRectangle( $ctx );
		delete $ctx->{_Way}{$way->{'id'}} if $way->{'nodes'}[0] == $way->{'nodes'}[-1]; # && OGF::Geo::Geometry::rectArea($aRect) < $minArea;
	}
}


#-------------------------------------------------------------------------------

sub longitudeSplit {
	my( $ctx, $lon, $dist ) = @_;
	$dist = 0 if ! defined $dist;

 	foreach my $way ( values %{$ctx->{_Way}} ){
		my $rect = $way->boundingRectangle( $ctx );
#		print STDERR "\@\$rect <", join('|',@$rect), ">\n";  # _DEBUG_
		next unless OGF::Geo::Geometry::rectOverlap( $rect, [$lon,-90,$lon,90] );

		my $way2 = $ctx->cloneObject( $way );
		$ctx->addObject( 'Way', $way2 );

		foreach my $nodeId ( @{$way->{'nodes'}} ){
			my $node = $ctx->{_Node}{$nodeId};
			if( $node->{'lon'} >= $lon ){
				my $node2 = OGF::Data::Node->new( $ctx, {'lon' => $lon-$dist, 'lat' => $node->{'lat'}} );
				$nodeId = $node2->{'id'};
			}
		}
		foreach my $nodeId ( @{$way2->{'nodes'}} ){
			my $node = $ctx->{_Node}{$nodeId};
			if( $node->{'lon'} <= $lon ){
				my $node2 = OGF::Data::Node->new( $ctx, {'lon' => $lon+$dist, 'lat' => $node->{'lat'}} );
				$nodeId = $node2->{'id'};
			}
		}
 	}
}


#-------------------------------------------------------------------------------

sub hairpinTurns {
	my( $ctx, $maxAngle ) = @_;
#	$dist = 0 if ! defined $dist;

 	foreach my $way ( values %{$ctx->{_Way}} ){
        my @nodes = map {$ctx->{_Node}{$_}} @{$way->{'nodes'}};
        my @turns;
        my $n = $#nodes;
        for( my $i = 1; $i < $n; ++$i ){
            my( $node, $nodeA, $nodeB ) = ( $nodes[$i], $nodes[$i-1], $nodes[$i+1] );
            my( $angle, $sign ) = $ctx->angleInfo( $node, $nodeA, $nodeB );
            push @turns, $i if $angle < $OGF::PI / 180 * $maxAngle;
        }
		delete $ctx->{_Way}{$way->{'id'}} if ! @turns;

        my %turns;
        foreach my $i ( @turns ){
            my( $node, $nodeA, $nodeB ) = ( $nodes[$i], $nodes[$i-1], $nodes[$i+1] );
            my $pxSize = pixelSize( $ctx->{_proj}, $node->{'lon'}, $node->{'lat'} );
            my @cp = $ctx->circlePoints( $node, $nodeA, $nodeB, 15, 6, $pxSize );
#    		     use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [\@cp], ['*cp'] ), "\n";  # _DEBUG_
            $turns{$i} = [ map {$_->{'id'}} @cp ];
        }

        my @nodesNew;
        for( my $i = 0; $i <= $n; ++$i ){
            if( $turns{$i} ){
                push @nodesNew, @{$turns{$i}};
            }else{
                push @nodesNew, $nodes[$i]->{'id'};
            }
        }
        $way->{'nodes'} = \@nodesNew;
 	}
}

sub pixelSize {
	my( $proj, $x, $y ) = @_;
	my( $mlon, $mlat ) = OGF::View::Projection->latitudeProjectionInfo( $y, 1 );
	my( $x0, $y0 ) = $proj->geo2cnv( 0,       $y );
	my( $x1, $y1 ) = $proj->geo2cnv( 1/$mlon, $y );
	my $pxSize = 1/($x1 - $x0);
	return $pxSize;
}


#-------------------------------------------------------------------------------

sub wayLengthFilter {
	require OGF::Geo::Measure;
	my( $ctx, $minLength ) = @_;

	my @deleteList;
	foreach my $way ( values %{$ctx->{_Way}} ){
		my $len = OGF::Geo::Measure::geoLength( $way, $ctx );
		push @deleteList, $way->{'id'} if $len < $minLength;
#		push @deleteList, $way->{'id'} if $len < $minLength && OGF::Data::Context::tagMatch($way,{'waterway' => 'river'});
	}

	map {delete $ctx->{_Way}{$_}} @deleteList;
}


#-------------------------------------------------------------------------------

sub writeSvg {
	require FileHandle;
	require HTML::Entities;
	my( $ctx ) = @_;
	my $outFile = Date::Format::time2str( 'C:/Backup/OGF/simplified_%Y%m%d_%H%M.svg', time );
	my $fh = FileHandle->new( $outFile, '>' ) or die qq/Cannot open outfile "$outFile" for writing $!/;

#	my( $wsz, $wd, $hg ) = ( 20037508.3427892, 4000, 4000 );
	my( $wsz, $wd, $hg ) = ( 20037508.3427892, 360, 180 );
	my $hTransf = { 'X' => [ -$wsz => 0, $wsz => $wd ], 'Y' => [ $wsz => 0, -$wsz => $hg ] };
	my $proj = OGF::View::Projection->new( '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs', $hTransf );
    $fh->print( qq|<svg xmlns="http://www.w3.org/2000/svg" width="$wd" height="$hg" viewBox="-180 -90 360 180">\n| );

	my $style = << 'EOF';
.free      { fill: #66cc22; }
.owned     { fill: #ffcc99; }
.community { fill: #cc99ff; }
.all       { fill: #4488ff; }
.withdraw  { fill: #eeff22; }
.reserved  { fill: #dddddd; }
EOF

    $fh->print( qq|<style>\n$style</style>\n| );
    $fh->print( qq|<g transform="scale(1,-1)">\n| );

	foreach my $rel ( sort {$a->{'tags'}{'ogf:id'} cmp $b->{'tags'}{'ogf:id'}} grep {$_->{'tags'}{'ogf:id'}} values %{$ctx->{_Relation}} ){
#		print STDERR "\$rel <", $rel, ">\n";  # _DEBUG_
        my $ogfId = $rel->{'tags'}{'ogf:id'} || "";
        my $owner = $rel->{'tags'}{'ogf:owner'} || "";
        my $status = $owner;
		if( ! $status ){
			$status = 'reserved';
		}elsif( $status =~ s/^\[(.*)\]$/$1/ ){
			# do nothing
		}elsif( $status =~ s/\s+\*\*$// ){
			$status = 'community';
		}else{
			$status = 'owned';
		}
		HTML::Entities::encode_entities_numeric( $owner );
        $fh->print( qq|<g style="stroke:black;stroke-width:0.1;" ogfid="$ogfId" owner="$owner" class="$status">\n| );
		foreach my $way ( map {$ctx->{_Way}{$_->{'ref'}}} @{$rel->{'members'}} ){
#           my @points = map {$proj->geo2cnv($_)} map {[$_->{'lon'},$_->{'lat'}]} map {$ctx->{_Node}{$_}} @{$way->{'nodes'}};
            my @points = map {[$_->{'lon'},$_->{'lat'}]} map {$ctx->{_Node}{$_}} @{$way->{'nodes'}};
            next if $#points <= 0;

#        	  my $text = qq|  <polyline style="fill:none;stroke:black;stroke-width:1;" points="|;
            my $text = qq|  <polygon points="|;
#        	  <polyline fill="#C3DD9B" stroke="#B77A51" stroke-width="0.1" points="6.739,-3.316 5.777,-3.316 5.777,-6.12 		"/>
            for( my $i = 0; $i <= $#points; ++$i ){
                $text .= sprintf "%.2f,%.2f ", @{$points[$i]};
            }
            $text .= qq|"/>\n|;
#        	  print STDERR "\$text <", $text, ">\n";  # _DEBUG_
            $fh->print( $text );
        }
        $fh->print( "</g>\n" );
	}
    $fh->print( "</g>\n" );
    $fh->print( "</svg>\n" );
}

sub writeSvg__ {
	require FileHandle;
	my( $ctx ) = @_;
	my $outFile = Date::Format::time2str( 'C:/Backup/OGF/simplified_%Y%m%d_%H%M.svg', time );
	my $fh = FileHandle->new( $outFile, '>' ) or die qq/Cannot open outfile "$outFile" for writing $!/;

	my( $wsz, $wd, $hg ) = ( 20037508.3427892, 4000, 4000 );
	my $hTransf = { 'X' => [ -$wsz => 0, $wsz => $wd ], 'Y' => [ $wsz => 0, -$wsz => $hg ] };
	my $proj = OGF::View::Projection->new( '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs', $hTransf );
    $fh->print( qq|<svg width="$wd" height="$hg">\n| );

	foreach my $way ( sort {$a->{'tags'}{'ogf:id'} cmp $b->{'tags'}{'ogf:id'}} values %{$ctx->{_Way}} ){
		my @points = map {$proj->geo2cnv($_)} map {[$_->{'lon'},$_->{'lat'}]} map {$ctx->{_Node}{$_}} @{$way->{'nodes'}};
#       my $aPoints = [ map {[$aCoord->[2*$_],$aCoord->[2*$_+1]]} (0..$#{$aCoord}/2) ];
#       $aPoints = OGF::Draw::WayDraw::algVisvalingamWhyatt( $aPoints );  # , {'threshold' => .1} );
        next if $#points <= 0;

		my $ogfId = $way->{'tags'}{'ogf:id'} || "";
#    	  my $text = qq|<polyline style="fill:none;stroke:black;stroke-width:1;" points="|;
        my $text = qq|<polygon style="fill:#DDDDDD;stroke:black;stroke-width:1;" ogfid="$ogfId" points="|;
#    	  <polyline fill="#C3DD9B" stroke="#B77A51" stroke-width="0.1" points="6.739,-3.316 5.777,-3.316 5.777,-6.12 		"/>
        for( my $i = 0; $i <= $#points; ++$i ){
            $text .= sprintf "%.2f,%.2f ", @{$points[$i]};
        }
        $text .= qq|"/>\n|;
#    	  print STDERR "\$text <", $text, ">\n";  # _DEBUG_
        $fh->print( $text );
	}
    $fh->print( "</svg>\n" );
}

sub writeMultimap {
	require FileHandle;
	my( $ctx ) = @_;
	my $outFile = Date::Format::time2str( 'C:/Backup/OGF/multimap_%Y%m%d_%H%M.txt', time );
	my $fh = FileHandle->new( $outFile, '>:encoding(UTF-8)' ) or die qq/Cannot open outfile "$outFile" for writing $!/;

#	my( $wsz, $wd, $hg ) = ( 20037508.3427892, 4000, 4000 );
	my( $wsz, $wd, $hg ) = ( 20037508.3427892, 360, 180 );
	my $hTransf = { 'X' => [ -$wsz => 0, $wsz => $wd ], 'Y' => [ $wsz => 0, -$wsz => $hg ] };
	my $proj = OGF::View::Projection->new( '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs', $hTransf );

	my %tp = (
        'free' => {
			_color => '#66cc22',
			_title => [ '#id' ],
			_text  => [ '#id', ' is free - you can [http://opengeofiction.net/message/new/admin request this territory.]' ],
		},
        'active' => {
			_color => '#ffcc99',
			_title => [ '#name' ],
			_text  => [ '#id', ' is active - owned by user ', '#owner' ],
		},
        'collaborative' => {
			_color => '#cc99ff',
			_title => [ '#name' ],
			_text  => [ '#id', ' is collaborative - managed by user ', '#owner' ],
		},
        'community' => {
			_color => '#4488ff',
			_title => [ '#name' ],
			_text  => [ '#id', ' is a community territory - anyone may edit here, no permission needed. Happy mapping!'  ],
		},
        'inactive' => {
			_color => '#eeff22',
			_title => [ '#name' ],
			_text  => [ '#id', ' is inactive - owned by user ', '#owner', ' - if you own this territory, please contact [http://opengeofiction.net/message/new/admin admin] or you may lose it.' ],
		},
        'reserved' => {
			_color => '#dddddd',
			_title => [ '#id' ],
			_text  => [ '#id', ' is reserved for future use' ],
		},
	);

    $fh->print( "{{#multimaps: | center = 0.0,90.0 | width = 100% | height = 1000px | zoom = 3 | maxzoom = 15 | minzoom = 3 | polygon = \n\n" );

	foreach my $rel ( sort {$a->{'tags'}{'ogf:id'} cmp $b->{'tags'}{'ogf:id'}} grep {$_->{'tags'}{'ogf:id'}} values %{$ctx->{_Relation}} ){
#		print STDERR "\$rel <", $rel, ">\n";  # _DEBUG_
		my $status = $rel->{'tags'}{'ogf:status'} || 'reserved';
		my %info = (
            'relId'  => $rel->{'id'},
            'name'   => $rel->{'tags'}{'name'},
            'ogfId'  => $rel->{'tags'}{'ogf:id'} || "",
            'owner'  => $rel->{'tags'}{'ogf:owner'} || "",
            'status' => $status,
		);

		my $color = $tp{$status}{_color};
		my $title = evalTemplate( $tp{$status}{_title}, \%info, 'wiki' );
		my $text  = evalTemplate( $tp{$status}{_text},  \%info );

		foreach my $way ( map {$ctx->{_Way}{$_->{'ref'}}} @{$rel->{'members'}} ){
#           my @points = map {$proj->geo2cnv($_)} map {[$_->{'lon'},$_->{'lat'}]} map {$ctx->{_Node}{$_}} @{$way->{'nodes'}};
            my @points = map {[$_->{'lon'},$_->{'lat'}]} map {$ctx->{_Node}{$_}} @{$way->{'nodes'}};
            next if $#points <= 0;

            my $coord = '';
#        	  <polyline fill="#C3DD9B" stroke="#B77A51" stroke-width="0.1" points="6.739,-3.316 5.777,-3.316 5.777,-6.12 		"/>
            for( my $i = 0; $i <= $#points; ++$i ){
				$coord .= ' : ' if $i;
                $coord .= sprintf "%.2f , %.2f", (reverse @{$points[$i]});
            }
            $coord .= qq|\n|;
#        	  print STDERR "\$coord <", $coord, ">\n";  # _DEBUG_
            my $popupText = << "EOF";
~ Title = $title
~ Text = $text
~ Color = #111111 
~ Weight = 1 
~ Fillcolor = $color 
~ Opacity = 0.9 
~ Fillopacity = 0.5 ;

EOF
            $fh->print( $coord );
            $fh->print( $popupText );
        }
	}
    $fh->print( "}}\n" );

	my $table = << 'EOF';
{| class="wikitable sortable"
 ! status
 ! id
 ! name
 ! owner
 ! deadline
EOF

    $fh->print( $table );
	foreach my $rel ( sort {$a->{'tags'}{'ogf:id'} cmp $b->{'tags'}{'ogf:id'}} grep {$_->{'tags'}{'ogf:id'}} values %{$ctx->{_Relation}} ){
#		print STDERR "\$rel <", $rel, ">\n";  # _DEBUG_
		my $status = $rel->{'tags'}{'ogf:status'} || 'reserved';
        my $relId  = $rel->{'id'};
        my $ogfId  = $rel->{'tags'}{'ogf:id'} || "";
        my $name   = ($status eq 'free')? $ogfId : $rel->{'tags'}{'name'};
        my $owner  = $rel->{'tags'}{'ogf:owner'} || "";
		my $ownerU = URI::Escape::uri_escape($owner);
		$owner = ($status =~ /active|collab/)? "[http://opengeofiction.net/user/$ownerU $owner]" : '';
		my $color  = $tp{$status}{_color};
		my $deadline = ($status eq 'inactive')? '2015-05-31' : '';

		my $row = << "EOF";
 |-
 | style="background:$color; border:2px solid #111111; padding:1em" align="center" | ''$status''
 | style="padding:1em" align="center" | [http://opengeofiction.net/relation/$relId $ogfId]
 | style="padding:1em" | '''[[$name]]'''
 | style="padding:1em" | $owner 
 | style="padding:1em" align="center"| $deadline
EOF

        $fh->print( $row );
	}
    $fh->print( "|}\n" );
}

sub evalTemplate {
	require URI::Escape;
	my( $aTemplate, $hInfo, $opt ) = @_;
	$opt = 'ogf' if ! $opt;	
	my $str = '';
	
	foreach my $tp ( @$aTemplate ){
		if( $tp =~ /^#/ ){
			if( $tp eq '#owner' ){
				my $owner = $hInfo->{'owner'};
				$str .= '[http://opengeofiction.net/user/'. URI::Escape::uri_escape($owner) ." $owner]";
			}elsif( $tp eq '#id' ){
				my( $ogfId, $relId ) = ( $hInfo->{'ogfId'}, $hInfo->{'relId'} );
				$str .= ($opt eq 'wiki')? "[[$ogfId]]" : "[http://opengeofiction.net/relation/$relId $ogfId]";
			}elsif( $tp eq '#name' ){
				$str .= '[['. $hInfo->{'name'} .']]';
			}
		}else{
			$str .= $tp;
		}
	}

	return $str;
}


#-------------------------------------------------------------------------------


sub repairRidgeWays {
	my( $ctx ) = @_;
	foreach my $way ( values %{$ctx->{_Way}} ){
		if( $way->tagMatch({'ogf:terrain_area' => 'mountains_1'}) && $way->{'nodes'}[0] != $way->{'nodes'}[-1] ){
			$way->{'tags'}{'ogf:terrain'} = 'ridge_1';
			delete $way->{'tags'}{'ogf:terrain_area'};
		}
	}
}

sub removeIdenticalWays {
	my( $ctx ) = @_;
	my %wayInfo;
	foreach my $way ( values %{$ctx->{_Way}} ){
		my $tag = join( '|', @{$way->{'nodes'}} );
		$wayInfo{$tag} = [] if ! $wayInfo{$tag};
		push @{$wayInfo{$tag}}, $way->{'id'};
	}
	foreach my $aWays ( values %wayInfo ){
		map {delete $ctx->{_Way}{$aWays->[$_]}} (1 .. $#{$aWays});
	}
}

sub removeIdenticalNodes {
	my( $ctx ) = @_;
	my %nodeInfo;
	foreach my $node ( values %{$ctx->{_Node}} ){
		my $tag = join( '|', $node->{'lon'}, $node->{'lat'} );
		$nodeInfo{$tag} = [] if ! $nodeInfo{$tag};
		push @{$nodeInfo{$tag}}, $node->{'id'};
	}
	my %nodeReplace;
	foreach my $aNodes ( values %nodeInfo ){
		map {$nodeReplace{$aNodes->[$_]} = $aNodes->[0]} (1 .. $#{$aNodes});
		map {delete $ctx->{_Nodes}{$aNodes->[$_]}}       (1 .. $#{$aNodes});
	}
	foreach my $way ( values %{$ctx->{_Way}} ){
		foreach my $nodeId ( @{$way->{'nodes'}} ){
			$nodeId = $nodeReplace{$nodeId} if $nodeReplace{$nodeId};
		}
	}
}

sub simpleClose {
	my( $ctx ) = @_;
	foreach my $way ( values %{$ctx->{_Way}} ){
		if( $way->tagMatch({'natural' => 'water'}) && $way->{'nodes'}[0] != $way->{'nodes'}[-1] ){
			push @{$way->{'nodes'}}, $way->{'nodes'}[0];
		}
	}
}


#-------------------------------------------------------------------------------




1;



