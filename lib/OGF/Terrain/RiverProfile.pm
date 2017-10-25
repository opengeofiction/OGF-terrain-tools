package OGF::Terrain::RiverProfile;
use strict;
use warnings;
use OGF::Util qw( errorDialog );
use OGF::Geo::Measure;
use base qw( Tk::Frame );


Tk::Widget->Construct( 'RiverProfile' );



our $INITIAL_HEIGHT = 200;
our $MARGIN = 20;
our $POSITION_LINE_COLOR = '#990000';
our $VIEW_POINTER_COLOR  = '#FFFF66';
our $VIEW_POINTER_SIZE   = 10;
our $INVALID_INTV_COLOR  = '#FFCCAA';



sub Populate {
	my( $self, $args ) = @_;

	$self->{_OGF_view}    = delete $args->{-view};
	$self->{_OGF_tool}    = delete $args->{-tool};
	$self->{_OGF_context} = delete $args->{-context} if $args->{-context};

	$self->{_OGF_control} = $self->Frame()->pack( -side => 'bottom', -fill => 'x' );
	$self->{_OGF_btApply} = $self->{_OGF_control}->Button(
		-text    => 'Apply',
		-command => sub{ $self->applyRiverElevation(); },
	)->pack( -side => 'left' );
	$self->{_OGF_btAuto} = $self->{_OGF_control}->Button(
		-text    => 'Auto',
#		-command => sub{ $self->autoIntervalCorrection(); },
		-command => sub{ $self->autoIntervalCorrection( {'startMax' => 1} ); },
	)->pack( -side => 'left' );

	$self->{_OGF_lbElevWay_value} = 'T:0';
	$self->{_OGF_lbElevWay} = $self->{_OGF_control}->Label( -textvariable => \$self->{_OGF_lbElevWay_value}, -padx => 2 )->pack( -side => 'left' );
	$self->{_OGF_lbElevPtr_value} = 'P: 0';
	$self->{_OGF_lbElevPtr} = $self->{_OGF_control}->Label( -textvariable => \$self->{_OGF_lbElevPtr_value}, -padx => 2 )->pack( -side => 'left' );
	$self->{_OGF_lbKmSource_value} = 'km/S:0';
	$self->{_OGF_lbKmSource} = $self->{_OGF_control}->Label( -textvariable => \$self->{_OGF_lbKmSource_value}, -padx => 2 )->pack( -side => 'left' );
	$self->{_OGF_lbKmMouth_value} = 'km/M:0';
	$self->{_OGF_lbKmMouth} = $self->{_OGF_control}->Label( -textvariable => \$self->{_OGF_lbKmMouth_value}, -padx => 2 )->pack( -side => 'left' );

	$self->{_OGF_enElevEntry} = $self->{_OGF_control}->Entry(
	    -width           => 10,
#	    -validate        => 'key',
#	    -validatecommand => sub{ $self->elevationEntry(@_); },
	)->pack( -side => 'left' );

#	$self->{_OGF_canvas} = $self->Scrolled( 'Canvas',
	my $cnv = $self->{_OGF_canvas} = $self->Canvas(
		-background => '#FFFFFF',
	)->pack( -side => 'bottom', -fill => 'both', -expand => 'true' );

	$self->{_OGF_editMode} = 0;

	$self->bind( '<Configure>' => sub{ $self->redraw(); } );
	$cnv->Tk::bind( '<ButtonPress-1>'   => sub{ $self->mousePress();} );
	$cnv->Tk::bind( '<ButtonRelease-1>' => sub{ $self->mouseRelease();} );
	$cnv->Tk::bind( '<Motion>'          => sub{ $self->movePointers(); } );
	$self->bind( '<KeyPress-q>'      => sub{ $self->editMode(1);} );
	$self->bind( '<KeyRelease-q>'    => sub{ $self->editMode(0);} );
	$self->bind( '<KeyPress-a>'      => sub{ $self->editMode(2);} );
	$self->bind( '<KeyRelease-a>'    => sub{ $self->editMode(0);} );
#	$self->bind( '<KeyPress-Control_L>'   => sub{ $self->editMode(3);} );
#	$self->bind( '<KeyRelease-Control_L>' => sub{ $self->editMode(0);} );
	$self->bind( '<KeyPress-Down>'   => sub{ $self->modifyEditPoint(-10);} );
	$self->bind( '<KeyPress-Up>'     => sub{ $self->modifyEditPoint( 10);} );
	$self->bind( '<Control-KeyPress-Down>' => sub{ $self->modifyEditPoint(-1);} );
	$self->bind( '<Control-KeyPress-Up>'   => sub{ $self->modifyEditPoint( 1);} );
	$self->bind( '<KeyPress-Delete>' => sub{ $self->deleteEditPoint();} );
	$self->bind( '<KeyPress-#>'      => sub{ print STDERR "---------------\n";} );

	$self->{_OGF_enElevEntry}->bind( '<KeyRelease>'            => sub{ $self->elevationEntry(); } );
	$self->{_OGF_enElevEntry}->bind( '<KeyPress-Down>'         => sub{ $self->modifyEditPoint(-10);} );
	$self->{_OGF_enElevEntry}->bind( '<KeyPress-Up>'           => sub{ $self->modifyEditPoint( 10);} );
	$self->{_OGF_enElevEntry}->bind( '<Control-KeyPress-Down>' => sub{ $self->modifyEditPoint(-1);} );
	$self->{_OGF_enElevEntry}->bind( '<Control-KeyPress-Up>'   => sub{ $self->modifyEditPoint( 1);} );
	$self->{_OGF_enElevEntry}->bind( '<KeyPress-Delete>'       => sub{ $self->deleteEditPoint();} );

#	my $opt = delete $args->{-opt};
	$self->SUPER::Populate( $args );
	$self->OnDestroy( sub{ $self->onDestroy(); } );

	return $self;
}

sub title {
	my( $self ) = @_;
	my $title = 'River profile';
	if( $self->{_OGF_river_way} && $self->{_OGF_river_way}{'tags'}{'name'} ){
		$title .= ': ' . $self->{_OGF_river_way}{'tags'}{'name'};
	}
	return $title;
}

sub setWayPoints {
	my( $self, $way, $aPoints ) = @_;
	$self->clear();
	$self->{_OGF_river_way}   = $way;
	$self->{_OGF_river_name}  = $way->{'tags'}{'name'};
	$self->{_OGF_river_way_length} = OGF::Geo::Measure::geoLength( $way );
	$self->{_OGF_way_points}  = $aPoints;
	$self->{_OGF_edit_points} = [ 0, $#{$aPoints} ];
	$self->configure( -width => scalar(@$aPoints) );
	$self->setScrollRegion();

	$self->{_OGF_terrain_item} = $self->{_OGF_canvas}->createLine( 0,0, 1,1, -fill => '#CCCC88' );
	$self->{_OGF_river_item}   = $self->{_OGF_canvas}->createLine( 0,0, 1,1 );
	$self->initPointers();

	$self->after( 200, sub{ $self->redraw(); } );
}

sub redraw {
	my( $self ) = @_;
	my $cnv = $self->{_OGF_canvas};
	my $aCoord_T = $self->getCanvasCoord( 2 );
	my $aCoord_R = $self->getCanvasCoord( 3 );
	$cnv->coords( $self->{_OGF_terrain_item}, @$aCoord_T );
	$cnv->coords( $self->{_OGF_river_item},   @$aCoord_R );
	$self->markInvalidIntervals();

	$cnv->delete( 'editpoint' );
	my $hg = $cnv->height;
#	print STDERR "\@{\$self->{_OGF_edit_points}} <", join('|',@{$self->{_OGF_edit_points}}), ">\n";  # _DEBUG_
	foreach my $idx ( @{$self->{_OGF_edit_points}} ){
		my( $xE, $yE ) = $self->terr2cnv( $idx, 0 );
		my $color = (defined $self->{_OGF_current_edit_point} && $idx == $self->{_OGF_current_edit_point})? '#55FF00' : '#00AA00';
		$cnv->createLine( $xE,0,$xE,$hg, -fill => $color, -tags => ['editpoint'] );
	}

	$cnv->raise( $self->{_OGF_position_line} );
}

sub getInvalidIntervals {
	my( $self, $aPoints ) = @_;
	$aPoints = $self->{_OGF_way_points} if ! $aPoints;

	my $maxValid = $aPoints->[0][3];
	my $n = scalar( @$aPoints );

	my( $intv, @intv );
	for( my $i = 0; $i < $n; ++$i ){
		my $elev = $aPoints->[$i][3];
#		print STDERR "[", $i, "]  maxValid ", $maxValid, "  elev ", $elev, "\n";  # _DEBUG_
		if( $elev <= $maxValid ){
			if( $intv ){
				$intv->[1] = $i - 1;
				push @intv, $intv;
				$intv = undef;
			}
			$maxValid = $elev;
		}else{
			if( ! $intv ){
				$intv = [ $i ];
			}
		}		
	}
	if( $intv ){
		$intv->[1] = $n - 1;
		push @intv, $intv;
	}
	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [\@intv], ['*intv'] ), "\n";  # _DEBUG_
	return @intv;
}

sub markInvalidIntervals {
	my( $self ) = @_;
	my $cnv = $self->{_OGF_canvas};
	$cnv->delete( 'invalid' );

	my @intv = $self->getInvalidIntervals();
	my $aCoord = $self->getCanvasCoord();
	my $hg = $cnv->height;
	$hg = $cnv->reqheight if $hg == 1;

	foreach my $intv ( @intv ){
		my( $i0, $i1 ) = @$intv;		
		my @coord = map {$aCoord->[$_]} ( 2*$i0 .. 2*$i1+1 );
		push @coord, $aCoord->[2*$i1],$hg, $aCoord->[2*$i0],$hg;
		$cnv->createPolygon( @coord, -fill => $INVALID_INTV_COLOR, -outline => $INVALID_INTV_COLOR, -tags => ['invalid'] );
	}
}

sub autoIntervalCorrection {
	my( $self, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;

	my $aPoints = $self->{_OGF_way_points};
	if( $hOpt->{'startMax'} ){
		my( $iMin, $elevMin, $iMax, $elevMax ) = $self->{_OGF_tool}->findMinMax( $aPoints );
		print STDERR "\$iMin <", $iMin, ">  \$elevMin <", $elevMin, ">  \$iMax <", $iMax, ">  \$elevMax <", $elevMax, ">\n";  # _DEBUG_
#		my( $iMin, $elevMin, $iMax, $elevMax ) = $self->{_OGF_tool}->findMinMax( $aPoints, undef, sub { $aPoints->[$_[0]][3] } );
		map {$aPoints->[$_][3] = $elevMax} (0 .. $iMax);
		print STDERR "\$aPoints->[0][3] <", $aPoints->[0][3], ">\n";  # _DEBUG_
	}

	my @intv = $self->getInvalidIntervals();

	foreach my $intv ( @intv ){
		my( $idxP, $idx )   = @$intv;
		$idxP -= 1 if $idxP > 0;
		if( $idx < $#{$aPoints} ){
			$idx  += 1;
		}else{
			my $elev = $aPoints->[$idx][3];
			my @idxP = grep {$aPoints->[$_][3] > $elev} (0 .. $#{$aPoints});
			$idxP = $idxP[-1];
		}
		my( $elevP, $elev ) = ( $aPoints->[$idxP][3], $aPoints->[$idx][3] );
#		print STDERR "\$idxP <", $idxP, ">  \$idx <", $idx, ">  \$elevP <", $elevP, ">  \$elev <", $elev, ">\n";  # _DEBUG_
		$self->setLinearElev( $idx, $elev, $idxP, $elevP );
	}
	$self->redraw();
}

sub applyRiverElevation {
	my( $self ) = @_;
	my @intv = $self->getInvalidIntervals();
	if( @intv ){
		errorDialog( "Cannot apply river elevation:\nInvalid intervals." );
		use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [\@intv], ['*intv'] ), "\n";  # _DEBUG_
		return;
	}
	$self->{_OGF_tool}->drawElevationPath( $self->{_OGF_way_points}, {'river' => $self->{_OGF_river_name}} );
}

sub clear {
	my( $self ) = @_;
	$self->{_OGF_river_way}  = undef;
	$self->{_OGF_way_points} = undef;
	if( $self->{_OGF_river_item} ){
		$self->delete( $self->{_OGF_river_item} );
		$self->{_OGF_river_item} = undef;
	}
}

sub setScrollRegion {
	my( $self ) = @_;
	my $num = scalar( @{$self->{_OGF_way_points}} );
	$self->{_OGF_canvas}->configure( -scrollregion => [0,0,$num,200] );
}

sub getCanvasCoord {
	my( $self, $ptIndex ) = @_;
	$ptIndex = 3 if ! defined $ptIndex;
	my $cnv = $self->{_OGF_canvas};

	my( $num, $wd, $hg ) = ( scalar(@{$self->{_OGF_way_points}}), $cnv->width, $cnv->height );
	( $wd, $hg ) = ( $cnv->reqwidth, $cnv->reqheight ) if $wd == 1;
#	my( $wd, $hg ) = ( scalar(@{$self->{_OGF_way_points}}), $INITIAL_HEIGHT );
	my( $elevMin, $elevMax ) = $self->elevationRange();

	my( $x, $step, $hg2 ) = ( 0, $wd / $num, $hg - 2 * $MARGIN );
	my @coord;

	for( my $i = 0; $i < $num; ++$i ){
#		my $y = $MARGIN + $hg2 * (1 - ($pt->[3] - $elevMin) / ($elevMax - $elevMin));
#		push @coord, $x, $y;
#		$x += $step;

		my $pt = $self->{_OGF_way_points}[$i];
		push @coord, $self->terr2cnv( $i, $pt->[$ptIndex] );
	}

	return \@coord;
}

sub initPointers {
	my( $self ) = @_;
	my( $cnv, $cnvP ) = ( $self->{_OGF_canvas}, $self->{_OGF_view}{_OGF_canvas} );
	my( $num, $wd, $hg ) = ( scalar(@{$self->{_OGF_way_points}}), $cnv->width, $cnv->height );
	( $wd, $hg ) = ( $cnv->reqwidth, $cnv->reqheight ) if $wd == 1;

	$self->{_OGF_position_line} = $cnv->createLine( 0,0, 0,$hg, -fill => $POSITION_LINE_COLOR );

	my( $sz, $x, $y ) = ( $VIEW_POINTER_SIZE, @{$self->{_OGF_way_points}[0]} );
	my $vpH = $cnvP->createLine( $x-$sz,$y, $x+$sz,$y, -fill => $VIEW_POINTER_COLOR );
	my $vpV = $cnvP->createLine( $x,$y-$sz, $x,$y+$sz, -fill => $VIEW_POINTER_COLOR );
	$self->{_OGF_view_pointer}  = [ $vpH, $vpV ];
}

sub editMode {
	my( $self, $mode ) = @_;
#	print STDERR "editMode( $mode )\n";  # _DEBUG_
	if( $mode == 0 && $self->{_OGF_editMode} == 1 ){
		$self->editEnd();
	}
	$self->{_OGF_editMode} = $mode;
}

# Prüfung auf Modifier-Keys muss anders gehandhabt werden evtl mittels cnv->XEvent;

sub mousePress {
	my( $self ) = @_;
#	$self->{_OGF_canvas}->focus;
	if( $self->{_OGF_editMode} == 1 ){
		$self->editStart() if ! $self->{_OGF_editLine};
		$self->addEditCoord();		
	}elsif( $self->{_OGF_editMode} == 2 ){
		$self->editStart();
	}elsif( $self->{_OGF_canvas}->XEvent()->s() =~ /Control/ ){
		$self->selectEditPoint();
	}else{
		$self->setEditPoint();
	}	
}

sub mouseRelease {
	my( $self ) = @_;
	if( $self->{_OGF_editMode} == 1 ){
		# do nothing		
	}elsif( $self->{_OGF_editMode} == 2 ){
		$self->editEnd();
	}	
}

sub editStart {
	my( $self ) = @_;
	my $cnv = $self->{_OGF_canvas};
	my $ev = $cnv->XEvent();
	$self->{_OGF_editLine} =	$cnv->createLine( $ev->x,$ev->y, $ev->x,$ev->y, -fill => '#008800' );
}

sub addEditCoord {
	my( $self, $x, $y ) = @_;
	my $cnv = $self->{_OGF_canvas};
	if( ! defined $x ){
		my $ev = $cnv->XEvent();
		( $x, $y ) = ( $ev->x, $ev->y );
	}
    my @coord = $cnv->coords( $self->{_OGF_editLine} );
    push @coord, $x, $y;
    $cnv->coords( $self->{_OGF_editLine}, @coord );
}

sub editEnd {
	my( $self ) = @_;
	my $cnv = $self->{_OGF_canvas};
	my @coord = $cnv->coords( $self->{_OGF_editLine} );
	my( $idx, $elev, $idxP, $elevP );
	for( my $i = 2; $i < $#coord; $i += 2 ){ 
		( $idx, $elev ) = $self->cnv2terr( $coord[$i], $coord[$i+1] );
#		$self->{_OGF_way_points}[$idx][3] = $elev;
		$self->setLinearElev( $idx, $elev, $idxP, $elevP );
		( $idxP, $elevP ) = ( $idx, $elev );
	}
	$cnv->delete( $self->{_OGF_editLine} );
	$self->{_OGF_editLine} = undef;
	$self->redraw();
}

sub setLinearElev {
	my( $self, $idx, $elev, $idxP, $elevP ) = @_;
	print STDERR "setLinearElev( $idx, $elev, $idxP, $elevP )\n";  # _DEBUG_
	if( ! defined $elevP ){
		$self->{_OGF_way_points}[$idx][3] = $elev;
		return;
	}
	my $n = $#{$self->{_OGF_way_points}};
	for( my $i = $idxP+1; $i <= $idx; ++$i ){
		my $elevNew = ($elev * ($i - $idxP) + $elevP * ($idx - $i)) / ($idx - $idxP);
		last if $i == $n && $elevNew < $self->{_OGF_way_points}[$i][3];   # don't lower elevation at river mouth
		$self->{_OGF_way_points}[$i][3] = $elevNew;
	}
}

sub movePointers {
	my( $self, $idx ) = @_;
	my( $cnv, $cnvP ) = ( $self->{_OGF_canvas}, $self->{_OGF_view}{_OGF_canvas} );
	my( $num, $wd, $hg ) = ( scalar(@{$self->{_OGF_way_points}}), $cnv->width, $cnv->height );

	my( $xE, $yE, $elev );
	if( defined($idx) ){
		$xE = $idx * $wd / $num;
	}else{
#		my $ev = $cnv->XEvent();
#		$xE  = $ev->x;
#		$idx = $xE * $num / $wd;
		my $ev = $cnv->XEvent();
		( $xE, $yE ) = ( $ev->x, $ev->y );
		( $idx, $elev ) = $self->cnv2terr();
	}
	$cnv->coords( $self->{_OGF_position_line}, $xE,0, $xE,$hg );

	my $pt = $self->{_OGF_way_points}[int($idx)];
	$self->{_OGF_lbElevWay_value} = 'R:' . int( $pt->[3] + .5 );
	$self->{_OGF_lbElevPtr_value} = 'P:' . int( $elev    + .5 );

	my $waySource = OGF::Data::Context->cloneObject( $self->{_OGF_river_way} );
	@{$waySource->{'nodes'}} = @{$waySource->{'nodes'}}[0..$pt->[5]];
	my $lenSource = OGF::Geo::Measure::geoLength( $waySource, $self->{_OGF_river_way}{_context} );
	my $lenMouth  = $self->{_OGF_river_way_length} - $lenSource;
	$self->{_OGF_lbKmSource_value} = sprintf 'km/S:%.1f', $lenSource/1000;
	$self->{_OGF_lbKmMouth_value}  = sprintf 'km/M:%.1f', $lenMouth /1000;

	my( $sz, $x, $y ) = ( $VIEW_POINTER_SIZE, @$pt );
	my( $vpH, $vpV ) = @{$self->{_OGF_view_pointer}};
	$cnvP->coords( $vpH, $x-$sz,$y, $x+$sz,$y );
	$cnvP->coords( $vpV, $x,$y-$sz, $x,$y+$sz );

	$self->addEditCoord( $xE, $yE ) if $self->{_OGF_editMode} == 2 && $self->{_OGF_editLine};
}


sub terr2cnv {
	my( $self, $idx, $elev ) = @_;
	my $cnv = $self->{_OGF_canvas};
	my( $num, $wd, $hg ) = ( scalar(@{$self->{_OGF_way_points}}), $cnv->width, $cnv->height );
	my( $elevMin, $elevMax ) = $self->elevationRange();

	my( $step, $hg2 ) = ( $wd / $num, $hg - 2 * $MARGIN );
	my $xC = $idx * $step;
	my $yC = $MARGIN + $hg2 * (1 - ($elev - $elevMin) / ($elevMax - $elevMin));
#	print STDERR "\$xC <", $xC, ">  \$yC <", $yC, ">\n";  # _DEBUG_
	return ( $xC, $yC );
}

sub cnv2terr {
	my( $self, $xC, $yC ) = @_;
	my $cnv = $self->{_OGF_canvas};
	if( ! defined $xC ){
		my $ev = $cnv->XEvent();
		( $xC, $yC ) = ( $ev->x, $ev->y );
	}

	my( $num, $wd, $hg ) = ( scalar(@{$self->{_OGF_way_points}}), $cnv->width, $cnv->height );
	my( $elevMin, $elevMax ) = $self->elevationRange();

	my $idx  = int( $xC * $num / $wd + .5 );
	my $elev = $elevMin + ($hg - $yC - $MARGIN) / ($hg - 2 * $MARGIN) * ($elevMax - $elevMin);
	return ( $idx, $elev );
}

sub setEditPoint {
	my( $self, $idx, $elev, $noEntry ) = @_;
	( $idx, $elev ) = $self->cnv2terr() if ! defined $idx;
#	print STDERR "\$idx <", $idx, ">  \$elev <", $elev, ">\n";  # _DEBUG_
	$self->{_OGF_current_edit_point} = $idx;
#	print STDERR "\@{\$self->{_OGF_edit_points}} <", join('|',@{$self->{_OGF_edit_points}}), ">\n";  # _DEBUG_
	my $n = $#{$self->{_OGF_edit_points}};
	my $iE;
	for( my $i = 0; $i <= $n; ++$i ){
		my $i0 = $self->{_OGF_edit_points}[$i];
		if( $idx == $i0 ){
			$iE = $i;
			last;
		}elsif( $idx > $i0 && $i < $n && $idx < $self->{_OGF_edit_points}[$i+1] ){
			$iE = $i + 1;
			++$n;
            splice @{$self->{_OGF_edit_points}}, $iE, 0, $idx;
			last;
		}
	}
#	print STDERR "\$iE <", $iE, ">\n";  # _DEBUG_
	if( defined $iE ){
		my( $i0, $i1, $e0, $e1 );
        if( $iE > 0 ){
			$i0 = $self->{_OGF_edit_points}[$iE-1];
            $e0 = $self->{_OGF_way_points}[$i0][3];
            $self->setLinearElev( $idx, $elev, $i0, $e0 );
        }
        if( $iE < $n ){
			$i1 = $self->{_OGF_edit_points}[$iE+1];
            $e1 = $self->{_OGF_way_points}[$i1][3];
            $self->setLinearElev( $i1, $e1, $idx, $elev );
        }
        $self->redraw();
		$self->setElevEntry( $self->{_OGF_way_points}[$idx][3] ) unless $noEntry;
	}
}


sub selectEditPoint {
 	my( $self ) = @_;
 	my( $idx, $elev ) = $self->cnv2terr();
#	print STDERR "\$idx <", $idx, ">  \$elev <", $elev, ">\n";  # _DEBUG_
	my( $i0 ) = map {$_->[0]} sort {$a->[1] <=> $b->[1]} map {[$_,abs($idx - $_)]} @{$self->{_OGF_edit_points}};
	if( abs($i0 - $idx) <= 10 ){
        $self->{_OGF_current_edit_point} = $i0;
        $self->setElevEntry( $self->{_OGF_way_points}[$i0][3] );
	}else{
        $self->{_OGF_current_edit_point} = undef;
        $self->setElevEntry( '' );
	}
    $self->redraw();
}

sub deleteEditPoint {
	my( $self, $iE ) = @_;
	print STDERR "deleteEditPoint( $iE )\n";  # _DEBUG_
	( $iE ) = grep {$self->{_OGF_edit_points}[$_] == $self->{_OGF_current_edit_point}} (0 .. $#{$self->{_OGF_edit_points}}) if ! defined $iE;
#	print STDERR "deleteEditPoint \$iE <", $iE, ">\n";  # _DEBUG_
	return if ! $iE || $iE == 0 || $iE == $#{$self->{_OGF_edit_points}};
	my $i0 = $self->{_OGF_edit_points}[$iE-1];
    my $e0 = $self->{_OGF_way_points}[$i0][3];
    my $i1 = $self->{_OGF_edit_points}[$iE+1];
    my $e1 = $self->{_OGF_way_points}[$i1][3];
#   print STDERR "\$i0 <", $i0, ">  \$e0 <", $e0, ">  \$i1 <", $i1, ">  \$e1 <", $e1, ">\n";  # _DEBUG_
    $self->setLinearElev( $i1, $e1, $i0, $e0 );
	splice @{$self->{_OGF_edit_points}}, $iE, 1;
	$self->redraw();
}

sub modifyEditPoint {
	my( $self, $step, $idx ) = @_;
	print STDERR "modifyEditPoint( $step, $idx )\n";  # _DEBUG_
	$idx = $self->{_OGF_current_edit_point} if ! defined $idx;
	return if ! defined $idx;
    my $elev = $self->{_OGF_way_points}[$idx][3];
	$self->setEditPoint( $idx, $elev + $step );
}

sub setElevEntry {
	my( $self, $val ) = @_;
	$self->{_OGF_enElevEntry}->delete( 0, 'end' );
	$self->{_OGF_enElevEntry}->insert( 0, $val ? sprintf('%.1f',$val) : '' );
}

sub elevationEntry {
	my( $self ) = @_;
	my $val = $self->{_OGF_enElevEntry}->get();
#	print STDERR "elevationEntry( $val )\n";  # _DEBUG_
	return 0 unless $val =~ /^[.\d]*$/;

	my $iE = $self->{_OGF_current_edit_point};
	return 0 if ! defined $iE;
#	print STDERR "elevationEntry \$iE <", $iE, ">\n";  # _DEBUG_

	$self->setEditPoint( $iE, $val, 1 );
#	$self->{_OGF_enElevEntry}->configure( -validate => 'key' );
	return 1;
}

sub elevationRange {
	my( $self ) = @_;
	if( ! $self->{_OGF_elev_range} ){
		my( $iMin, $elevMin, $iMax, $elevMax ) = $self->{_OGF_tool}->findMinMax( $self->{_OGF_way_points} );
		$self->{_OGF_elev_range} = [ $elevMin, $elevMax ];
	}
	return @{$self->{_OGF_elev_range}};
}

sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }

sub onDestroy {
	my( $self ) = @_;
	if( $self->{_OGF_view_pointer} ){
		$self->{_OGF_view}{_OGF_canvas}->delete( @{$self->{_OGF_view_pointer}} );
	}	
}


1;


