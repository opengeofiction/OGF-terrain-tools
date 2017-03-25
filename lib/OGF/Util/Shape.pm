package OGF::Util::Shape;
use strict;
use warnings;



my $SQRT_2 = sqrt( 2 );
my %DDXX = (
	'E8' => [ [0,-1], [1,-1], [1,0], [1,1], [0,1], [-1,1], [-1,0], [-1,-1] ],
	'E4' => [ [0,-1],         [1,0],        [0,1],         [-1,0]          ],
);
my $EDITOR;
my( $START_MIN, $START_MAX ) = ( 999_999_999, -999_999_999 );
my $LOOP_COUNT = 0;


sub new {
	my( $pkg, $aTile, $hShape ) = @_;
	my $self = {
		_shape   => ($hShape ? $hShape : {}),
		_tile    => $aTile,
#		_contour => {},
#		_dist    => {},
	};
	bless $self, $pkg;
}


sub connectedShape {
	my( $aTile, $ptStart, $envType, $cSub, $hOpt ) = @_;
	my $margin = ($hOpt && defined $hOpt->{'margin'})? $hOpt->{'margin'} : 0;
	my $aEnvP = getTypeEnvPoints( $envType );
	my( $wd, $hg ) = getTileSize( $aTile );
	my $hShape = {};
#	connectedShape_R( $hShape, $aTile, $ptStart, $aEnvP, $cSub, $wd, $hg, $margin );
	connectedShape_I( $hShape, $aTile, $ptStart, $aEnvP, $cSub, $wd, $hg, $margin );
#	print STDERR "connectedShape <", join('|',keys %$hShape), ">\n";  # _DEBUG_
#	print STDERR "connectedShape [", $ptStart->[0], ",", $ptStart->[1], "] -> ", scalar(keys %$hShape), "\n";  # _DEBUG_
	return OGF::Util::Shape->new( $aTile, $hShape );
}

sub generalShape {
	my( $aTile, $cSub, $hOpt ) = @_;
	my $margin = ($hOpt && defined $hOpt->{'margin'})? $hOpt->{'margin'} : 0;
	my( $wd, $hg ) = getTileSize( $aTile );

	my $hShape = {};
	for( my $y = $margin; $y < $hg-$margin; ++$y ){
		for( my $x = $margin; $x < $wd-$margin; ++$x ){
			my $ptag = ptag([$x,$y]);
			if( $cSub->( $x, $y ) ){
				$hShape->{$ptag} = [ $x, $y ];
#				$EDITOR->updatePhotoPixel( $x, $y ) if $EDITOR;      # _DEBUG_
			}
		}
	}
	return OGF::Util::Shape->new( $aTile, $hShape );
}




sub connectedShape_R {
	my( $hShape, $aTile, $pt, $aEnvP, $cSub, $wd, $hg, $margin ) = @_;
	my( $ptag, $x, $y ) = ( ptag($pt), @$pt );
	return if exists $hShape->{$ptag};
	return if ! $cSub->($x,$y);
#	print STDERR "\$ptag <", $ptag, ">  \$x <", $x, ">  \$y <", $y, ">\n";  # _DEBUG_
	$hShape->{$ptag} = [ $x, $y ];
	$EDITOR->updatePhotoPixel( $x, $y ) if $EDITOR;      # _DEBUG_
	foreach my $dd ( @$aEnvP ){
		my( $xd, $yd ) = ( $x + $dd->[0], $y + $dd->[1] );
#		print STDERR "\$xd <", $xd, ">  \$yd <", $yd, ">\n";  # _DEBUG_
		if( inArea([$wd,$hg],[$xd,$yd],$margin) ){
			connectedShape_R( $hShape, $aTile, [$xd,$yd], $aEnvP, $cSub, $wd, $hg, $margin );
		}
	}
}

sub connectedShape_I {
	my( $hShape, $aTile, $pt, $aEnvP, $cSub, $wd, $hg, $margin ) = @_;
	my( $ptag, $x, $y ) = ( ptag($pt), @$pt );
	return if ! $cSub->($x,$y);

	my @ptStack;
	$hShape->{$ptag} = [ $x, $y ];
	$EDITOR->updatePhotoPixel( $x, $y ) if $EDITOR;      # _DEBUG_

	while( 1 ){
#		print STDERR "\$x <", $x, ">  \$y <", $y, ">\n";  # _DEBUG_
		my( $ct, $x0, $y0 ) = ( 0 );
		foreach my $dd ( @$aEnvP ){
			my( $xd, $yd ) = ( $x + $dd->[0], $y + $dd->[1] );
#			print STDERR "\$xd <", $xd, ">  \$yd <", $yd, ">\n";  # _DEBUG_
			my $ptag = ptag( [$xd,$yd] );
			next if $hShape->{$ptag} || ! inArea([$wd,$hg],[$xd,$yd],$margin) || ! $cSub->($xd,$yd);
			$hShape->{$ptag} = [ $xd, $yd ];
			$EDITOR->updatePhotoPixel( $xd, $yd ) if $EDITOR;      # _DEBUG_
			if( $ct == 0 ){
				( $x0, $y0 ) = ( $xd, $yd );
			}else{
				push @ptStack, [ $xd, $yd ];
			}
			++$ct;
		}
		if( defined $x0 ){
			( $x, $y ) = ( $x0, $y0 );
		}elsif( @ptStack ){
#			( $x, $y ) = shiftRandom( \@ptStack );
			( $x, $y ) = @{ shift @ptStack };
		}else{
			last;
		}
#		randomPermutation();
	}
}

sub randomPermutation {
	return unless (++$LOOP_COUNT) % 100 == 0;
	my $i1 = int(rand(4));
	my $i2 = int(rand(4));
	if( $i1 != $i2 ){
		my $sw = $DDXX{'E4'}[$i1];
		$DDXX{'E4'}[$i1] = $DDXX{'E4'}[$i2];
		$DDXX{'E4'}[$i2] = $sw;
	}
}

sub shiftRandom {
	my( $aStack ) = @_;
	my $idx = int(rand(scalar(@$aStack)));
	my $pt = splice @$aStack, $idx, 1;
	return @$pt;
}


sub findBorderPoint {
	my( $aTile, $pt, $ddIdx, $aEnvP, $cSub, $wd, $hg, $margin ) = @_;
	my( $x, $y ) = @$pt;
	my( $xd, $yd ) = @{$aEnvP->[$ddIdx]};
	return undef if ! $cSub->($x,$y);
	while( inArea([$wd,$hg],[$x,$y],$margin) && $cSub->($x,$y) ){
		$x += $xd;
		$y += $yd;
	}
	return [ $x-$xd, $y-$yd ];
}



sub isEmpty {
	my( $self ) = @_;
	return (scalar(keys %{$self->{_shape}}) == 0);
}

sub minMaxInfo {
	my( $self, $aTile, $cSub ) = @_;
	return (undef,undef) if $self->isEmpty();

	$cSub = sub{ my($x,$y) = @_; return $aTile->[$y][$x]; } if ! $cSub;
	my( $min, $max, $ptMin, $ptMax ) = ( $START_MIN, $START_MAX );
	foreach my $pt ( values %{$self->{_shape}} ){
		my $val = $cSub->( @$pt );
		($min,$ptMin) = ($val,$pt) if $val < $min;
		($max,$ptMax) = ($val,$pt) if $val > $max;
	}
	return ( $min, $max, $ptMin, $ptMax );
}





sub paintShape {
	my( $self, $editor, $color, $areaColor ) = @_;

	foreach my $pt ( values %{$self->{_shape}} ){
		$editor->updatePhotoPixel( $pt->[0], $pt->[1], $color );
	}

	if( defined $areaColor ){
		my $enclosedArea = $self->enclosedArea();
		foreach my $pt ( values %{$enclosedArea->{_shape}} ){
			$editor->updatePhotoPixel( $pt->[0], $pt->[1], $areaColor );
		}
	}
}



sub setDistIndex {
	my( $self, $ptStart, $envType ) = @_;
	my $aEnvP  = getTypeEnvPoints( $envType );
	my $hShape = $self->{_shape};

	$ptStart = $hShape->{ptag($ptStart)};
	$ptStart->[2] = 0;
	$self->setDistIndex_R( $ptStart, $aEnvP, $hShape );

#	my @err = grep {!defined $_->[2]} $self->points();
#	die "setDistIndex incomlete: ", scalar(@err), "\n" if @err;
}

sub setDistIndex_R {
	my( $self, $pt, $aEnvP, $hShape ) = @_;
	my $dist = $pt->[2];
	my @ptNext;
	foreach my $dd ( @$aEnvP ){
		my( $xd, $yd ) = ( $pt->[0] + $dd->[0], $pt->[1] + $dd->[1] );
		my $ptag = ptag( [$xd,$yd] );
		if( exists $hShape->{$ptag} ){
			my $pt2 = $hShape->{$ptag};
			my $dist2 = abs($dd->[0]) + abs($dd->[1]);
			$dist2 = 1.5 if $dist2 > 1;
			if( $#{$pt2} <= 1 || $dist+$dist2 < $pt2->[2] ){
				$pt2->[2] = $dist + $dist2;
				push @ptNext, $pt2;
			}
		}
	}
	foreach my $pt2 ( sort {$a->[2] <=> $b->[2]} @ptNext ){
		$self->setDistIndex_R( $pt2, $aEnvP, $hShape );
	}
}

sub clearDistIndex {
	my( $self ) = @_;
	map {$#{$_} = 1} $self->points;
}

sub findLocalMaximums {
	my( $self, $cSub, $envType, $envType2 ) = @_;
	my $aEnvP = getTypeEnvPoints( $envType );
	my $shapeE = OGF::Util::Shape->new( $self->{_tile} );

	foreach my $pt ( $self->points ){
#		my( $flag, $val ) = ( 1, $cSub->($pt->[0],$pt->[1]) );
#		foreach my $dd ( @$aEnvP ){
#			my( $xd, $yd ) = ( $pt->[0] + $dd->[0], $pt->[1] + $dd->[1] );
#			next if ! $self->containsPoint([$xd,$yd]);
#			if( $cSub->($xd,$yd) > $val ){
#				$flag = 0;
#				last;
#			}
#		}
#		$shapeE->addPoint($pt) if $flag;
		$shapeE->addPoint($pt) if $self->isLocalMaximum($pt,$cSub,$aEnvP);
	}

	my @shapes = $shapeE->connectedSubshapes( $envType );
	my @endPoints = map {($_->points())[0]} @shapes;

	if( $envType2 ){
		my $aEnv2 = getTypeEnvPoints( $envType2 );
		@endPoints = grep {$self->isLocalMaximum($_,$cSub,$aEnv2)} @endPoints;
	}

	return @endPoints;
}

sub isLocalMaximum {
	my( $self, $pt, $cSub, $aEnvP ) = @_;
	my( $ret, $val ) = ( 1, $cSub->($pt->[0],$pt->[1]) );
	foreach my $dd ( @$aEnvP ){
		my( $xd, $yd ) = ( $pt->[0] + $dd->[0], $pt->[1] + $dd->[1] );
		next if ! $self->containsPoint([$xd,$yd]);
		if( $cSub->($xd,$yd) > $val ){
			$ret = 0;
			last;
		}
	}
	return $ret;	
}



#-------------------------------------------------------------------------------

sub getBorder {
	my( $self, $inOut, $envType ) = @_;
	my $aEnvP = getTypeEnvPoints( $envType );
	my( $aTile, $hShape, $hBorder ) = ( $self->{_tile}, $self->{_shape}, {} );
	my( $wd, $hg ) = getTileSize( $aTile );
	if( $inOut eq 'outer' ){
		foreach my $key ( keys %$hShape ){
			my( $x, $y ) = @{$hShape->{$key}};
			foreach my $dd ( @$aEnvP ){
				my( $xd, $yd ) = ( $x + $dd->[0], $y + $dd->[1] );
				next if ! inArea( [$wd,$hg], [$xd,$yd] );
				my $ptag = ptag( [$xd,$yd] );
				if( ! exists $hShape->{$ptag} ){
					$hBorder->{$ptag} = [ $xd, $yd ];
					$EDITOR->updatePhotoPixel( $xd, $yd ) if $EDITOR;      # _DEBUG_
				}
			}
		}
	}elsif( $inOut eq 'inner' ){
		foreach my $key ( keys %$hShape ){
			my( $x, $y ) = @{$hShape->{$key}};
			foreach my $dd ( @$aEnvP ){
				my( $xd, $yd ) = ( $x + $dd->[0], $y + $dd->[1] );
				next if ! inArea( [$wd,$hg], [$xd,$yd] );
				my $ptag = ptag( [$xd,$yd] );
				if( ! exists $hShape->{$ptag} ){
					$hBorder->{$key} = [ $x, $y ];
					$EDITOR->updatePhotoPixel( $x, $y ) if $EDITOR;      # _DEBUG_
					last;
				}
			}
		}
	}else{
		die qq/getShapeBorder: unknown border type "$inOut" (values = inner,outer)/;
	}
	return OGF::Util::Shape->new( $aTile, $hBorder );
}

sub getBorderArrays {
	my( $self ) = @_;
	my $border = $self->getBorder( 'inner', 'E4' );

	my( $wd, $hg ) = getTileSize( $self->{_tile} );
	my( $hEdges, $hShape, $aArea ) = ( {}, $self->{_shape}, [$wd,$hg] );

	foreach my $key ( keys %{$border->{_shape}} ){
		my( $x, $y ) = @{$border->{_shape}{$key}};
		addEdge( $hEdges, [$x,$y,     $x+1,$y  ], 1 ) if areaOutsidePoint($hShape,$aArea,[$x,$y-1]);
		addEdge( $hEdges, [$x+1,$y,   $x+1,$y+1], 2 ) if areaOutsidePoint($hShape,$aArea,[$x+1,$y]);
		addEdge( $hEdges, [$x+1,$y+1, $x,$y+1  ], 3 ) if areaOutsidePoint($hShape,$aArea,[$x,$y+1]);
		addEdge( $hEdges, [$x,$y+1,   $x,$y    ], 4 ) if areaOutsidePoint($hShape,$aArea,[$x-1,$y]);
	}

	my( $hSegments, $aEdge, $aCurrentSegment ) = ( {} );
	my $keyNext = getNonBranchingStartPoint( $hEdges );

	while( $keyNext ){
#		$hSegments->{$key} = [ $aEdge ] if ! $aPrev;
		$aCurrentSegment = $hSegments->{$keyNext} = [] if ! $aCurrentSegment;
		if( $hEdges->{$keyNext} ){
#			print STDERR "A \$keyNext <", $keyNext, ">  ";  # _DEBUG_
			my $aPt	= $hEdges->{$keyNext};
			my $num = scalar(@$aPt);
			if( $num == 1 ){
				delete $hEdges->{$keyNext};
				$aEdge = $aPt->[0];
			}elsif( $num == 2 ){
				die qq/Unexpected error: no previous edge at branch point/ if ! $aEdge;
				my( $dx, $dy )   = ( $aEdge->[2]-$aEdge->[0],   $aEdge->[3]-$aEdge->[1] );
				my( $dx0, $dy0 ) = ( $aPt->[0][2]-$aPt->[0][0], $aPt->[0][3]-$aPt->[0][1] );
				my( $dx1, $dy1 ) = ( $aPt->[1][2]-$aPt->[1][0], $aPt->[1][3]-$aPt->[1][1] );
				my( $s0, $s1 )   = ( $dx * $dy0 - $dy * $dx0, $dx * $dy1 - $dy * $dx1 );
				if( $s0 == -1 ){
					$aEdge = shift @$aPt;
				}elsif( $s1 == -1 ){
					$aEdge = pop @$aPt;
				}else{
					# L = -1, R = 1
					# (beachten, dass die y-Pixelkoordinate entgegen den \xFCblichen
					# mathematischen Koordinaten gerichtet ist)
					die qq/Unexpected error: branch without left turn/;
				}
			}else{
				die qq/Unexpected error: $num edges at point/;
			}
			push @$aCurrentSegment, $aEdge;
			$keyNext = ptag([$aEdge->[2],$aEdge->[3]]);
#			print STDERR "B \$keyNext <", $keyNext, ">\n";  # _DEBUG_
		}else{
			if( $hSegments->{$keyNext} && $hSegments->{$keyNext} != $aCurrentSegment ){
				my $aNextSegment = delete $hSegments->{$keyNext};
				push @$aCurrentSegment, @$aNextSegment;
			}
			$aCurrentSegment = undef;
			$keyNext = getNonBranchingStartPoint( $hEdges );
		}
		last if ! (%$hEdges || $keyNext);
	}

	my @borders;
	foreach my $key2 ( keys %$hSegments ){
		my $aSegment = $hSegments->{$key2};
		my( $x0, $y0, $x1, $y1 ) = ( $aSegment->[0][0], $aSegment->[0][1], $aSegment->[-1][2], $aSegment->[-1][3] );
		my $closed = ($x0 == $x1 && $y0 == $y1);
		$EDITOR->setPixelPaintColor( $closed ? '#FF0099' : '#FF9900' ) if $EDITOR;

		push @borders, {
			_closed => $closed,
			_array  => makeArrayFromSegment($aSegment),
		};
		$EDITOR->updatePhotoPixel( @{$borders[-1]{_array}[0]}, '#FFFF00' ) if $EDITOR;      # _DEBUG_
	}
	return @borders;
}


sub addEdge {
	my( $hEdge, $aEdge, $type ) = @_;
	my $ptag = ptag( [$aEdge->[0],$aEdge->[1]] );
#	print STDERR "\$hEdge <", $hEdge, ">  \$ptag <", $ptag, ">  \@\$aEdge <", join('|',@$aEdge), ">  \$type <", $type, ">\n";  # _DEBUG_
	$hEdge->{$ptag} = [] if ! $hEdge->{$ptag};
	push @{$hEdge->{$ptag}}, $aEdge;
}

sub areaOutsidePoint {
	my( $hShape, $aArea, $pt ) = @_;
	return (inArea($aArea,$pt) && ! exists $hShape->{ptag($pt)});
}

sub getNonBranchingStartPoint {
	my( $hEdges ) = @_;
	keys %$hEdges;
	return undef if ! %$hEdges;
	my( $key, $aPt );
	while( 1 ){
		( $key, $aPt ) = each %$hEdges;
		last if scalar(@$aPt) == 1;
	}
#	print STDERR "---> \$key <", $key, ">\n";  # _DEBUG_
	return $key;
}

sub makeArrayFromSegment {
	my( $aSegment ) = @_;
	my @borderArray;
	my $ptPrev;
	foreach my $aEdge ( @$aSegment ){
		my( $x, $y, $dx, $dy ) = ( $aEdge->[0], $aEdge->[1], $aEdge->[2]-$aEdge->[0], $aEdge->[3]-$aEdge->[1] );
		my $pt;
		if( $dx == 1 && $dy == 0 ){
			$pt = [ $x, $y ];
		}elsif( $dx == 0 && $dy == 1 ){
			$pt = [ $x-1, $y ];
		}elsif( $dx == -1 && $dy == 0 ){
			$pt = [ $x-1, $y-1 ];
		}elsif( $dx == 0 && $dy == -1 ){
			$pt = [ $x, $y-1 ];
		}else{
			die qq/Unexpected error: invalid edge diff [$dx,$dy]/;
		}
		unless( $ptPrev && $pt->[0] == $ptPrev->[0] && $pt->[1] == $ptPrev->[1] ){
			push @borderArray, $pt;
			$EDITOR->updatePhotoPixel( @$pt ) if $EDITOR;      # _DEBUG_
		}
		$ptPrev = $pt;
	}
	return \@borderArray;
}


#-------------------------------------------------------------------------------

sub extend {
	my( $self, $envType, $cSub ) = @_;
	while( 1 ){
		my $border = $self->getBorder( 'outer', $envType );
		$border->filter( $cSub );
		last if ! %{$border->{_shape}};
		$self->union( $border );
	}
	return $self;
}

sub filter {
	my( $self, $cSub ) = @_;
	my $hSelf = $self->{_shape};
	foreach my $key ( keys %$hSelf ){
		my $pt = $hSelf->{$key};
		if( ! $cSub->( @$pt ) ){
			delete $hSelf->{$key};
			$EDITOR->updatePhotoPixel( $pt->[0], $pt->[1], 'erase' ) if $EDITOR;      # _DEBUG_
		}
	}
	return $self;
}

#sub union {
#	my( $self, $other ) = @_;
#	my( $hSelf, $hOther ) = ( $self->{_shape}, $other->{_shape} );
#	foreach my $key ( keys %$hOther ){
#		$hSelf->{$key} = $hOther->{$key} if ! $hSelf->{$key};
#	}
#}

sub union {
	my( $self, @other ) = @_;
	$self = OGF::Util::Shape->new([],{}) if ! $self;
	my $hSelf = $self->{_shape};
	foreach my $other ( @other ){
		my $hOther = $other->{_shape};
		foreach my $key ( keys %$hOther ){
			$hSelf->{$key} = $hOther->{$key} if ! $hSelf->{$key};
		}
	}
	return $self;
}

sub intersection {
	my( $self, @other ) = @_;
	$self = (shift @other)->copy() if ! $self;
	my $hSelf = $self->{_shape};
	foreach my $other ( @other ){
		my $hOther = $other->{_shape};
		foreach my $key ( keys %$hSelf ){
			delete $hSelf->{$key} if ! $hOther->{$key};
		}
	}
	return $self;
}

sub diff {
	my( $self, $other ) = @_;
	my( $hSelf, $hOther ) = ( $self->{_shape}, $other->{_shape} );
	foreach my $key ( keys %$hOther ){
		delete $hSelf->{$key} if $hSelf->{$key};
	}
	return $self;
}

sub copy {
	my( $self ) = @_;
	my( $hSelf, $hCopy ) = ( $self->{_shape}, {} );
	map {$hCopy->{$_} = [ @{$hSelf->{$_}} ]} keys %$hSelf;
	my $copy = OGF::Util::Shape->new( $self->{_tile}, $hCopy );
	return $copy;
}

sub connectedSubshapes {
	my( $self, $envType ) = @_;
	my $copy = $self->copy();
	my @shapes;

	my $cSub = sub{
		my( $x, $y ) = @_;
		return $copy->containsPoint( [$x,$y] );
	};

	my $hShape = $copy->{_shape};
	while( %$hShape ){
		keys %$hShape;
		my( $key, $pt ) = each %$hShape;
		my $subShape = connectedShape( $copy->{_tile}, $pt, $envType, $cSub );
		$copy->diff( $subShape );
		push @shapes, $subShape;
	}

	return @shapes;
}

sub enclosedArea {
	my( $self ) = @_;
	my $rectOuter = $self->outerRectangle( 1 )->diff( $self );
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 1; print STDERR Data::Dumper->Dump( [$rectOuter], ['rectOuter'] ), "\n";  # _DEBUG_
	my $ptR = [ $rectOuter->{_minX}, $rectOuter->{_minY} ];
	my @shapes = $rectOuter->connectedSubshapes( 'E4' );
#	print STDERR "\@shapes <", join('|',@shapes), ">\n";  # _DEBUG_
	@shapes = grep {! $_->containsPoint($ptR)} @shapes;
	my $encArea = union( @shapes );
	return $encArea;
}

sub outerRectangle {
	my( $self, $margin, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my( $minX, $maxX ) = $self->minMaxInfo( undef, sub{$_[0]} );
	my( $minY, $maxY ) = $self->minMaxInfo( undef, sub{$_[1]} );

	$minX -= $margin; $maxX += $margin; $minY -= $margin; $maxY += $margin;

	my %rect;
    for( my $y = $minY; $y <= $maxY; ++$y ){
		my $step = ($hOpt->{'frameOnly'} && $y > $minY && $y < $maxY)? ($maxX - $minX) : 1;
        for( my $x = $minX; $x <= $maxX; $x += $step ){
            $rect{ptag([$x,$y])} = [ $x,$y ];
        }
    }

	my $rectOuter = $hOpt->{'sizeOnly'} ? {} : OGF::Util::Shape->new( $self->{_tile}, \%rect );
	$rectOuter->{_minX} = $minX;
	$rectOuter->{_maxX} = $maxX;
	$rectOuter->{_minY} = $minY;
	$rectOuter->{_maxY} = $maxY;

	return $rectOuter;
}



sub points {
	my( $self ) = @_;
	return values %{$self->{_shape}};
}

sub containsPoint {
	my( $self, $pt ) = @_;
	return (exists $self->{_shape}{ptag($pt)});
}

sub addPoint {
	my( $self, $pt ) = @_;
	$self->{_shape}{ptag($pt)} = [ $pt->[0], $pt->[1] ];
}

sub subtract {
	my( $self, $other ) = @_;
	foreach my $key ( keys %{$other->{_shape}} ){
		delete $self->{_shape}{$key};
	}
	return $self;
}


sub toString {
	my( $self ) = @_;
	my @points = values %{$self->{_shape}};
	use Data::Dumper; local $Data::Dumper::Indent = 0;
	my $text = Data::Dumper->Dump( [\@points], ['*points'] );
	return $text;
}

sub size {
	my( $self ) = @_;
	my $size = scalar( values %{$self->{_shape}} );
	return $size;
}


#--- UTILITIES --------------------------------------------------------------------------------

sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }

sub getTypeEnvPoints {
	my( $envType ) = @_;
	my $aEnvPoints;

	if( $envType =~ /^R(\d+)/ ){
		my $rd = $1;
		my @dd = ( [1,0],[0,1],[-1,0],[0,-1],[1,0] );
		my( $dd, $pt ) = ( shift @dd );
		$aEnvPoints = [ [0,-$rd] ];
		while( 1 ){
			$pt = [ $aEnvPoints->[-1][0]+$dd->[0], $aEnvPoints->[-1][1]+$dd->[1] ];
			if( $pt->[0] == $aEnvPoints->[0][0] && $pt->[1] == $aEnvPoints->[0][1] ){
				last;
			}elsif( pxDist([0,0],$pt) == $rd ){
				push @$aEnvPoints, $pt;
			}else{
				$dd = shift @dd;
			}
		}
	}else{
		$aEnvPoints = $DDXX{$envType};
	}
	die qq/getTypeEnvPoints: unknown shape environment type "$envType" (values = E4,E8)/ if ! $aEnvPoints;
#	use Data::Dumper; local $Data::Dumper::Indent = 0; print STDERR Data::Dumper->Dump( [$aEnvPoints], ['aEnvPoints'] ), "\n";
	return $aEnvPoints;
}

sub getTileSize {
	my( $aTile ) = @_;
	my( $wd, $hg );
	if( ref($aTile) eq 'ARRAY' ){
		( $wd, $hg ) = ( scalar(@{$aTile->[0]}), scalar(@$aTile) );
	}elsif( ref($aTile) eq 'HASH' ){
		( $wd, $hg ) = ( $aTile->{_width}, $aTile->{_height} );
	}
	return ( $wd, $hg );
}

sub pointIterator {
	my( $aTile, $cSub ) = @_;
	my( $wd, $hg ) = getTileSize( $aTile );
	for( my $y = 0; $y < $hg; ++$y ){
		for( my $x = 0; $x < $wd; ++$x ){
			$cSub->( $x, $y );
		}
	}
}

sub ptag {
	my $pt = shift;
	return $pt->[0] .",". $pt->[1];
}

sub tagPt {
	my $ptag = shift;
	if( $ptag =~ /^(\d+),(\d+)$/ ){
		my $pt = [ $1, $2 ];
		return $pt;
	}else{
		die qq/tagP: cannot parse "$ptag"/;
	}
}

sub inArea {
	my( $aSize, $aPt, $margin ) = @_;
	$margin = 0 if ! defined $margin;
	my( $wd, $hg, $x, $y ) = ( $aSize->[0], $aSize->[1], $aPt->[0], $aPt->[1] );
	return ($x >= 0+$margin && $x < $wd-$margin && $y >= 0+$margin && $y < $hg-$margin);
}

sub ptDist {
	my( $ptA, $ptB ) = @_;
	my( $dx, $dy ) = ( $ptB->[0] - $ptA->[0], $ptB->[1] - $ptA->[1] );
	return sqrt( $dx * $dx + $dy * $dy );
}

sub pxDist {
	my( $ptA, $ptB ) = @_;
	my( $dx, $dy ) = ( abs($ptB->[0] - $ptA->[0]), abs($ptB->[1] - $ptA->[1]) );
	return max( $dx, $dy );
}

sub setEditor {
	my( $editor, $delay, $color ) = @_;
	if( $editor ){
		$EDITOR = $editor;
		$EDITOR->setPixelPaintDelay( $delay ) if defined $delay;
		$EDITOR->setPixelPaintColor( $color ) if defined $color;
	}elsif( $EDITOR ){
		$EDITOR->setPixelPaintDelay( undef );
		$EDITOR->setPixelPaintColor( undef );
		$EDITOR = undef;
	}
}



#----------------------------------------------------------------------------------------------

sub sharpenContourLines {
	my( $aContour, $noElev, $aStream ) = @_;

	my $editor;
	if( $EDITOR ){
		$editor = $EDITOR;
		$EDITOR = undef;
	}

	my( $wd, $hg ) = getTileSize( $aContour );
	my $aEnvP = getTypeEnvPoints('E8');
	for( my $y = 1; $y < $hg-1; ++$y ){
		for( my $x = 1; $x < $wd-1; ++$x ){
			my $elev = $aContour->[$y][$x];
			next if $elev == $noElev;

#			my $strm = $aStream->[$y][$x];
#			next if $strm == $noElev;

			my( $aArea, $ct, $flag, $shape ) = ( [], 0, 0 );
			$aArea->[1][1] = $noElev;

			foreach my $dd ( @$aEnvP ){
				my( $yd, $xd ) = @$dd;
				my $val = $aContour->[$y+$yd][$x+$xd];
				$aArea->[$yd+1][$xd+1] = $val;
				++$ct if $val == $elev;
			}
			next if $ct <= 1;

			my $cSub = sub{ my($x,$y) = @_; return ($aArea->[$y][$x] == $elev); };
			foreach my $dd ( @$aEnvP ){
				my( $xd, $yd ) = ( $dd->[0]+1, $dd->[1]+1 );
				if( $aArea->[$yd][$xd] == $elev ){
					if( ! $shape ){
						$shape = connectedShape( $aArea, [$xd,$yd], 'E8', $cSub );
					}elsif( ! $shape->containsPoint([$xd,$yd]) ){
						$flag = 1;
						last;
					}
				}
			}
			next if $flag;

			$aContour->[$y][$x] = $noElev;
#			print STDERR "\$aContour->[$y][$x]\n";                      # _DEBUG_
			$editor->updatePhotoPixel( $x, $y, '#FFFFFF' ) if $editor;  # _DEBUG_
		}
	}

	if( $editor ){
		$EDITOR = $editor;
	}
}



#----------------------------------------------------------------------------------------------

#sub setDist {
#	my( $self, $ptStart, $envType ) = @_;
#	my $aEnvP  = getTypeEnvPoints( $envType );
#	my $hShape = $self->{_shape};
#	$self->setDist_R( $ptStart, $aEnvP, $hShape, 0 );
#}
#
#sub setDist_R {
#	my( $self, $pt, $aEnvP, $hShape, $dist ) = @_;
#	my( $x, $y ) = @$pt;
#	$pt->[2] = $dist;
#	foreach my $dd ( @$aEnvP ){
#		my( $xd, $yd ) = ( $x + $dd->[0], $y + $dd->[1] );
#		my $ptag = ptag( [$xd,$yd] );
#		if( exists $hShape->{$ptag} ){
#			my $pt2 = $hShape->{$ptag};
#			if( scalar(@$pt2) <= 2 ){
#				$self->setDist_R( $pt2, $aEnvP, $hShape, $dist+1 );
#			}
#		}
#	}
#}



1;

