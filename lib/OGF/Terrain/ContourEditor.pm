package OGF::Terrain::ContourEditor;
use strict;
use warnings;
use Tk::Dialog;
use Tk::Canvas;
use Tk::JPEG;
use Tk::PNG;
use POSIX;
use File::Copy;
use OGF::Util qw( infoDialog );
use OGF::Util::File qw( writeToFile readFromFile );
use OGF::Geo::Measure;
use OGF::LayerInfo;
use OGF::Util::Shape;
use OGF::Terrain::ElevationTile qw( $NO_ELEV_VALUE $T_WIDTH $T_HEIGHT $BPP $TILE_ORDER_Y makeTileFromArray makeArrayFromTile makeArrayFromFile makeTileArray );

use base qw( Tk::Frame OGF::LayerInfo );


#my( $T_WIDTH, $T_HEIGHT, $BPP ) = ( 512, 512, 2 );
#OGF::Terrain::ElevationTile::setGlobalTileInfo( $T_WIDTH, $T_HEIGHT, $BPP );


Tk::Widget->Construct( 'ContourEditor' );

my @LBOX_ALT_VALUES = (
	[ -600, -500, -400, -300, -200, -150, -100, -50, -15,
	0, 1, 5, 15, 25, 50, 75, 100, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850,
	900, 950, 1000, 1050, 1100, 1200, 1250, 1300, 1350, 1400 ],
	[ -15, 0, 1, 5, 15, 25, 50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500, 525, 550,
	575, 600, 625, 750, 875, 1000, 1125, 1250, 1375, 1500, 1625, 1750, 1875, 2000, 2125, 2250 ],
	[ 0, 50, 100, 150, 200, 250, 300, 350, 400,
	450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 950, 1000, 1050, 1100, 1150, 1200, 1250, 1300, 1350, 1400, 1450,
	1500, 1550, 1600, 1650, 1700, 1750, 1800, 1850, 1900, 1950, 2000, 2050, 2100 ],
	[ 1200, 1250, 1300, 1350, 1400, 1450, 1500, 1550, 1600, 1650, 1700, 1750, 1800, 1850, 1900, 1950, 2000, 2050, 2100,
	2150, 2200, 2300, 2400, 2500, 2600, 2700, 2800, 2900, 3000, 3100, 3200, 3300, 3400, 3500, 3600, 3700,
	3800, 3900, 4000, 4100, 4200, 4300, 4400 ],
);

our %COLOR_CONF = (
	'Stream' => '#0044FF',
	'Water'  => '#99DDFF',
	'Shape'  => '#FF0000',
#	'Fill'   => '#DCFFFF',
	'Fill'   => '#FFFF88',
);

#my( $TILES_X, $TILES_Y ) = ( 1, 1 );
my( $TILES_X, $TILES_Y ) = ( 3, 3 );
my $CONTROL_WIDTH = 12;
my $EDITOR = undef;
my $SHAPE_PAINT_DELAY = 0.001;
my $SHAPE_PAINT_COLOR = $COLOR_CONF{'Shape'};
my $TILE_DIST = 1;


sub Populate {
	my( $self, $args ) = @_;
#	print join('--',@$aFiles), "\n";
	$self->{_OGF_scale} = (defined $args->{-scale})? (delete $args->{-scale}) : 1;
	$self->{_OGF_margin} = 20;
	( $TILES_X, $TILES_Y ) = @{ delete $args->{-layout} } if $args->{-layout};

	my $control = $self->{_OGF_control} = $self->Frame(
		-background => '#DDDDDD',
		-width      => 200,
	)->pack( -side => 'left', -fill => 'y', -expand => 'true' );

	my $scrWd = $self->{_OGF_scrWd} = $TILES_X * $self->{_OGF_scale} * $T_WIDTH  + 2 * $self->{_OGF_margin};
	my $scrHg = $self->{_OGF_scrHg} = $TILES_Y * $self->{_OGF_scale} * $T_HEIGHT + 2 * $self->{_OGF_margin};

#	my $cnv = $self->{_OGF_canvas} = $self->Canvas(
	my $scr = $self->Scrolled( 'Canvas',
		-scrollbars => '',
		-scrollregion => [0,0,$scrWd,$scrHg],
		-background => '#000066',
		-width      => 1400,
		-height     =>  830,
		-relief     => 'sunken',
		-borderwidth => 4,
	)->pack( -side => 'left', -fill => 'both', -expand => 'true' );
	my $cnv = $self->{_OGF_canvas} = $scr->Subwidget( 'scrolled' );

	$self->{_OGF_idx}   = 0;

	$self->{_OGF_step}  = 1;
	$self->{_OGF_intv}  = 1000;

	$self->{_OGF_imgtext} = $cnv->createText( 20, 20,
		-anchor => 'nw',
		-text   => '',
		-tags   => 'text',
		-fill   => '#FFFFFF',
	);

	( $self->{_OGF_valCheckboxContour}, $self->{_OGF_valCheckboxStream} ) = ( 1, 1 );

	my $frameCbContour = $control->Frame()->pack( -side => 'top', -fill => 'x' );
	my $cbContour = $self->{_OGF_checkboxContour} = $frameCbContour->Checkbutton(
		-variable => \($self->{_OGF_valCheckboxContour}),
		-command  => sub{ $self->redrawOverlays(); },
	)->pack( -side => 'left' );
	my $labelCbContour = $frameCbContour->Label( -text => 'Contour' )->pack( -side => 'left' );

	my $frameCbStream = $control->Frame()->pack( -side => 'top', -fill => 'x' );
	my $cbStream = $self->{_OGF_checkboxStream} = $frameCbStream->Checkbutton(
		-variable => \($self->{_OGF_valCheckboxStream}),
		-command => sub{ $self->redrawOverlays(); },
	)->pack( -side => 'left' );
	my $labelCbStream = $frameCbStream->Label( -text => 'Stream' )->pack( -side => 'left' );

#	my @lboxToolValues = ( 'Extract', 'Select', 'Stream', 'Contour' );
#	my @lboxToolValues = ( 'Repair', 'Fill', 'Select', 'Stream', 'Contour' );
	my @lboxToolValues = ( 'Test', 'Measure', 'Magnify', 'Fill', 'Select', 'Stream', 'Contour' );
	my $lboxT = $self->{_OGF_lbox_tool} = $control->Listbox(
		-relief     => 'sunken',
		-width      => $CONTROL_WIDTH,
		-height     => scalar(@lboxToolValues),
		-selectmode => 'single',
	)->pack( -side => 'top', -fill => 'x' );
	map { $lboxT->insert(0, $_) } @lboxToolValues;
#	$lboxT->{_OGF_function} = 'selectTool';
	$lboxT->bind( '<ButtonPress-1>', sub{$self->selectListbox_Tool()} );
	$lboxT->bind( '<Shift-ButtonPress-1>', sub{$self->selectListbox_Tool();$self->correctSelectedShapeLayer();} );

	my $lboxA = $self->{_OGF_lbox_elev} = $control->Scrolled( 'Listbox',
		-scrollbars => 'ow',
		-relief     => 'sunken',
		-width      => $CONTROL_WIDTH,
#		-height     => scalar(@{$LBOX_ALT_VALUES[0]}),
		-height     => 10,
		-selectmode => 'single',
	)->pack( -side => 'top', -fill => 'y', -expand => 1 );
	map { $lboxA->insert(0,$_) } @{$LBOX_ALT_VALUES[0]};
#	$lboxA->{_OGF_function} = 'setAltitude';
	$lboxA->bind( '<ButtonPress-1>', sub{$self->selectListbox_Elev()} );
	$lboxA->bind( '<ButtonPress-3>', sub{$self->switchAltList($lboxA)} );
	$lboxA->bind( '<Shift-ButtonPress-1>', sub{$self->selectListbox_Elev();$self->highlightElevation();} );

	my $entryIn = $self->{_OGF_altEntry} = $control->Entry(
		-relief     => 'sunken',
		-width      => $CONTROL_WIDTH,
		-validate   => 'key',
#		-validatecommand => sub{ $self->setAltitude($_[0]); return 1; },
		-validatecommand => sub{ $self->selectListbox_Elev('value' => $_[0]); return 1; },
	)->pack( -side => 'top' );
	$entryIn->bind( '<ButtonPress-1>', sub{$self->selectListbox_Elev('value' => $entryIn->get())} );

	my $entryAlt = $self->{_OGF_altDisplay} = $control->Entry(
		-relief     => 'sunken',
		-width      => $CONTROL_WIDTH,
		-state      => 'readonly',
	)->pack( -side => 'top' );

	my $btSave = $control->Button(
		-text    => 'Save Tile',
		-command => sub{$self->saveElevationTile()},
		-width   => $CONTROL_WIDTH,
	)->pack( -side => 'bottom' );

	my $entryPos = $self->{_OGF_posDisplay} = $control->Entry(
		-relief     => 'sunken',
		-width      => $CONTROL_WIDTH,
		-state      => 'readonly',
	)->pack( -side => 'top' );
	$self->{_OGF_posDisplayOption} = 1;
	$entryPos->bind( '<ButtonPress-3>', sub{$self->{_OGF_posDisplayOption} = 1 - $self->{_OGF_posDisplayOption}} );

	$self->selectListbox_Tool( 'value' => 'Contour' );
	$self->selectListbox_Elev( 'value' => 0 );

	$self->{_OGF_currentProcedure} = '';

	$self->OnDestroy( sub{ $self->writeTaskList(); } );
}

sub bindInit {
	my( $self ) = @_;
	my $cnv = $self->{_OGF_canvas};

	$self->imageBind( '<ButtonPress-1>',   'dragStart' );
	$self->imageBind( '<Motion>',          'dragMove'  );
	$self->imageBind( '<ButtonRelease-1>', 'dragEnd'   );
	$self->imageBind( '<Control-ButtonPress-1>', 'printLocalElevInfo' );
	$self->imageBind( '<Shift-ButtonPress-1>',   'dragStart', 'InlandWater' );

	$self->imageBind( '<ButtonPress-3>',   'dragStart', 'Erase' );
	$self->imageBind( '<ButtonRelease-3>', 'dragEnd' );

	$cnv->Tk::bind( '<ButtonRelease-1>',  sub{ $self->dragEnd(); } );
	$cnv->Tk::bind( '<KeyPress-Down>',  sub{ $cnv->yviewScroll( 1,'units'); } );
	$cnv->Tk::bind( '<KeyPress-Up>',    sub{ $cnv->yviewScroll(-1,'units'); } );
	$cnv->Tk::bind( '<KeyPress-Right>', sub{ $cnv->xviewScroll( 1,'units'); } );
	$cnv->Tk::bind( '<KeyPress-Left>',  sub{ $cnv->xviewScroll(-1,'units'); } );
	$cnv->Tk::bind( '<KeyPress-M>',     sub{ $self->removeMagnifyTool(); } );
}

sub imageBind {
	my( $self, $event, $func, @param ) = @_;
	my $cnv = $self->{_OGF_canvas};
	$cnv->bind( 'img', $event, sub{
		my $ev = $cnv->XEvent();
		my( $hTile, $x, $y ) = $self->imageEventPos( $ev ); 
		return if ! $hTile;
		$self->$func( $hTile, $x,$y, @param );
	} );
	$cnv->bind( 'magnify', $event, sub{
		my $ev = $cnv->XEvent();
		my( $hTool, $x, $y ) = $self->imageEventPos( $ev ); 
		return if ! $hTool;
		my( $x0, $y0 ) = @{$hTool->{_area}};
		$self->$func( $hTool->{_tile}, $x0+$x,$y0+$y, @param );
	} );
}

sub imageEventPos {
	my( $self, $ev ) = @_;
	my $cnv = $self->{_OGF_canvas};

	my( $xE, $yE ) = ( $cnv->canvasx($ev->x), $cnv->canvasy($ev->y) );
#	foreach my $func ( split(//,'BDEKNTXYbcfhkmopstvwxy') ){  print "$func: ", $ev->$func(), "\n";  }

#	my( $img ) = $cnv->find( 'closest', $xE, $yE );
	my @img = $cnv->find( 'overlapping', $xE,$yE, $xE,$yE );
	return undef if ! @img;

	my $img = $img[-1];
#	print STDERR "\$img <", $img, ">  \$xE <", $xE, ">  \$yE <", $yE, ">\n";  # _DEBUG_
	my( $xp, $yp ) = $cnv->coords( $img );
#	print STDERR "  \$xp <", $xp, ">  \$yp <", $yp, ">\n";  # _DEBUG_
	my $hTile = $self->{_OGF_tiles}{$img}; 
	my $sc = $hTile->{_scale} ? $hTile->{_scale} : $self->{_OGF_scale};

	( $xE, $yE ) = ( int(($xE - $xp)/$sc), int(($yE - $yp)/$sc) );
#	print STDERR "\$xE <", $xE, ">  \$yE <", $yE, ">  \%{\$hTile->{_wwInfo}} <", join('|',%{$hTile->{_wwInfo}}), ">\n";  # _DEBUG_

	return $hTile ? ($hTile, $xE, $yE) : undef;
}


#sub DESTROY {
#	my( $self ) = @_;
#	my( $layer, $x, $y ) = ( $self->{_OGF_wwInfo}{'layer'}, $self->{_OGF_tx}, $self->{_OGF_ty} );
#	print "$layer $x $y\n";
#}



sub switchAltList {
	my( $self, $lbox ) = @_;
	my $val = $lbox->get( 'end' );
#	print STDERR "\$val <", $val, ">\n";  # _DEBUG_
	my( $curList ) = grep {$LBOX_ALT_VALUES[$_][0] == $val} (0..$#LBOX_ALT_VALUES);
#	print STDERR "\$curList <", $curList, ">\n";  # _DEBUG_
	$curList = ($curList + 1) % scalar(@LBOX_ALT_VALUES);
	$lbox->delete( 0, 'end' );
	map { $lbox->insert(0, $_) } @{$LBOX_ALT_VALUES[$curList]};
}

#sub selectTool {
#	my( $self, $tool ) = @_;
##	print STDERR "\$tool <", $tool, ">\n";  # _DEBUG_
#	$self->{_OGF_tool} = $tool;
#	if( $tool eq 'Stream' ){
#		$self->selectListbox( $self->{_OGF_lbox_elev}, 'value' => 0, 'lbox' => 1 );
#	}
#}
#
#sub setAltitude {
#	my( $self, $elev ) = @_;
#	$self->{_OGF_altitude} = $elev;
##	print STDERR "\$self->{_OGF_altitude} <", $self->{_OGF_altitude}, ">\n";  # _DEBUG_
##	$self->{_OGF_altDisplay}->configure( -state => 'normal' );
##	$self->{_OGF_altDisplay}->delete( 0, 'end' );
##	$self->{_OGF_altDisplay}->insert( 0, $elev );
##	$self->{_OGF_altDisplay}->configure( -state => 'readonly' );
#	$self->setEntryText( 'altDisplay', $elev );
#}

sub selectListbox {
	my( $self, $lbox, %opts ) = @_;
	my( $idx, $val, $onClick );
	my @list = $lbox->get( 0, 'end' );
	if( ! %opts ){
		$onClick = 1;
		$opts{'index'} = $lbox->curselection();
	}
	if( defined $opts{'index'} ){
		$idx = $opts{'index'};
		$val = $lbox->get( $idx );
	}elsif( defined $opts{'change'} ){
		my $dd = $opts{'change'};
		($idx) = $lbox->curselection();
#		print STDERR "\$idx <", join('|',@$idx), ">\n";  # _DEBUG_
		return if ! defined $idx;
		if( $idx + $dd >= 0 && $idx + $dd <= $#list ){
			$idx += $dd;
		}
		$val = $lbox->get( $idx );
	}elsif( defined $opts{'value'} ){
		$val = $opts{'value'};
#		print STDERR "\@list <", join('|',@list), ">\n";  # _DEBUG_
		( $idx ) = grep {$list[$_] eq $val} (0..$#list);
	}else{
		return;
	}

	if( defined $idx ){
		if( ! $onClick ){
			$lbox->selectionClear( 0, 'end' );
			$lbox->selectionSet( $idx );
		}
		for( my $i = 0; $i <= $#list; ++$i ){
			$lbox->itemconfigure( $i, -background => '#FFFFFF' );
		}
		$lbox->itemconfigure( $idx, -background => '#AAFF99' );
	}

	return ( $idx, $val );
}


sub selectListbox_Tool {
	my( $self, %opts ) = @_;
	my $lbox = $self->{_OGF_lbox_tool};
	my( $idx, $tool ) = $self->selectListbox( $lbox, %opts );

	$self->{_OGF_tool} = $tool;

	if( $self->{_OGF_tool} eq 'Contour' ){
		if( ! $self->{_OGF_valCheckboxContour} ){
			$self->{_OGF_valCheckboxContour} = 1;
			$self->redrawOverlays();
		}
	}elsif( $self->{_OGF_tool} eq 'Stream' ){
		if( ! $self->{_OGF_valCheckboxStream} ){
			$self->{_OGF_valCheckboxStream} = 1;
			$self->redrawOverlays();
		}
	}elsif( $self->{_OGF_tool} eq 'Fill' ){
		$self->{_OGF_currentProcedure} = '' if $self->{_OGF_currentProcedure} eq 'Fill';
	}
}

sub selectListbox_Elev {
	my( $self, %opts ) = @_;
	my $lbox = $self->{_OGF_lbox_elev};
	my( $idx, $elev ) = $self->selectListbox( $lbox, %opts );

	$self->{_OGF_altitude} = $elev;
	$self->setEntryText( 'altDisplay', $elev );

	my $hTile = $self->{_OGF_activeTile};
	if( $self->{_OGF_tool} eq 'Select' && $hTile->{_selectedShape} ){
		$self->setSelectedShapeValue( $hTile, $elev );
	}else{
		$self->selectListbox_Tool( 'value' => 'Contour' );
	}
}

sub highlightElevation {
	my( $self ) = @_;
	my $elev = $self->{_OGF_altitude};
#	print STDERR "B \$elev <", $elev, ">\n"; exit; # _DEBUG_
	my( $aLayer, $photo ) = ( $self->{_OGF_activeTile}{_contour}, $self->{_OGF_activeTile}{_photo} );
	OGF::Util::Shape::pointIterator( $aLayer, sub{
		my( $x, $y ) = @_;
		$self->setPhotoPixel( $photo, $x, $y, '#FFBB00' ) if $aLayer->[$y][$x] == $elev; 
	});
}



sub setBgColor {
	my( $self ) = @_;
	my $color = '#000000';
	$self->configure( -background => $color );
}

sub title {
	my( $self ) = @_;
	return $self->currentFile();
}



#-------------------------------------------------------------------------------


sub dragStart {
	my( $self, $hTile, $xE,$yE, $action ) = @_;
	$action = '' if !defined $action;
	$self->{_OGF_canvas}->Tk::focus();

	$self->{_OGF_activeTile} = $hTile;
	my $tool = $self->{_OGF_tool};
	if( $tool eq 'Contour' || $tool eq 'Stream' ){
		$self->{_OGF_drag} = { _tile => $hTile, _x => $xE, _y => $yE, _action => $action, _elev => undef };
	}elsif( $self->{_OGF_tool} eq 'Select' ){
		$self->selectConnectedShape( $hTile, $xE, $yE );
	}elsif( $self->{_OGF_tool} eq 'Repair' ){
		$self->repairConnectedShape( $hTile, $xE, $yE );
	}elsif( $self->{_OGF_tool} eq 'Fill' ){
		my $shape = $self->fillConnectedArea( $hTile, $xE, $yE, $action );
		if( $action eq 'InlandWater' ){
			$hTile->{_modified} = 1;
			$hTile->{_inlandWaters} = [] if ! $hTile->{_inlandWaters};
			push @{$hTile->{_inlandWaters}}, $shape;
		}
	}elsif( $self->{_OGF_tool} eq 'Magnify' ){
		$self->displayMagnifyTool( $hTile, $xE, $yE, 30, 30, 10 );
	}elsif( $self->{_OGF_tool} eq 'Measure' ){
		my $elev = $hTile->{_elev}->[$yE][$xE];
		my $proj = $self->ogfProjection( $self->{_OGF_projDsc}, $hTile );
		my( $lon, $lat ) = $proj->cnv2geo( $xE, $yE );
		$self->{_OGF_measurePoint} = { _lon => $lon, _lat => $lat, _elev => $elev };

		my( $cnv, $sc ) = ( $self->{_OGF_canvas}, $self->{_OGF_scale} );
		my( $xL, $yL ) = $cnv->coords( $hTile->{_img} );
		$self->{_OGF_measureLine} = $cnv->createLine( $xL+$sc*$xE,$yL+$sc*$yE, $xL+$sc*$xE+1,$yL+$sc*$yE, -fill => '#FF0000' );
	}elsif( $self->{_OGF_tool} eq 'Test' ){
		$self->testFunction( $hTile, $xE, $yE );
#	}elsif( $self->{_OGF_tool} eq 'Extract' ){
#		$self->extractConnectedShape( $hTile, $xE, $yE );
	}
}

sub dragMove {
	my( $self, $hTile, $xE,$yE, $action ) = @_;

	if( $self->{_OGF_drag} ){
		return if $hTile->{_img} ne $self->{_OGF_drag}{_tile}{_img};
		$self->setPositionValue( $hTile, $xE, $yE, {'line' => 1} );
		$self->{_OGF_drag}{_x} = $xE;
		$self->{_OGF_drag}{_y} = $yE;
	}else{
		if( $self->{_OGF_measurePoint} ){
			my $elev = $hTile->{_elev}->[$yE][$xE];
			my $proj = $self->ogfProjection( $self->{_OGF_projDsc}, $hTile );
			my( $lon, $lat ) = $proj->cnv2geo( $xE, $yE );
			my $ptM = $self->{_OGF_measurePoint};
			my $dist = OGF::Geo::Measure::geoDist( {'lon' => $ptM->{_lon}, 'lat' => $ptM->{_lat}}, {'lon' => $lon, 'lat' => $lat} );
			my $ascend = sprintf '%.2f %%', ($elev - $ptM->{_elev}) / $dist;
			$dist = ($dist >= 10000)? sprintf( '%.1f km', $dist / 1000 ) : $dist . ' m';
			$self->setEntryText( 'posDisplay', $dist .' '. $ascend );

			my( $cnv, $sc ) = ( $self->{_OGF_canvas}, $self->{_OGF_scale} );
			my( $xL, $yL ) = $cnv->coords( $hTile->{_img} );
			my( $x0, $y0, $x1, $y1 ) = $cnv->coords( $self->{_OGF_measureLine} );
			$cnv->coords( $self->{_OGF_measureLine}, $x0,$y0, $xL+$sc*$xE,$yL+$sc*$yE );
		}else{
			my $aLayer = ($hTile->{_elev} && $self->{_OGF_tool} ne 'Select')? $hTile->{_elev} : $hTile->{_contour};
#			print "[$yE,$xE] --> ", $self->{_OGF_elevationLayer}[$yE][$xE], "\n";
			my $elev = $aLayer->[$yE][$xE];
			$elev = '--' if $elev == $NO_ELEV_VALUE;
			my $posInfo = "[$xE,$yE] $elev";
			$self->setEntryText( 'posDisplay', $posInfo );
		}
	}
}

sub dragEnd {
	my( $self ) = @_;
	$self->{_OGF_canvas}->delete( $self->{_OGF_measureLine} ) if $self->{_OGF_measureLine};
	$self->{_OGF_drag} = undef;
#	$self->{_OGF_tool} = undef;
	$self->{_OGF_tool} = $self->{_OGF_toolPrev} if $self->{_OGF_tool} eq 'Erase';
}

sub printLocalElevInfo {
	my( $self, $hTile, $xE,$yE, $action ) = @_;
#	my $ev = $self->{_OGF_canvas}->XEvent();
#	my( $hTile, $xE, $yE ) = $self->imageEventPos( $ev );
	my( $aElev, $aCnr ) = ( $hTile->{_elev}, $hTile->{_contour} );
	for( my $y = $yE-5; $y <= $yE+5; ++$y ){
		for( my $x = $xE-5; $x <= $xE+5; ++$x ){
			next unless $x >= 0 && $x < $T_WIDTH && $y >= 0 && $y < $T_HEIGHT;
			if( $aCnr->[$y][$x] != $NO_ELEV_VALUE ){
				printf ' *%4d', $aCnr->[$y][$x];
			}else{
				printf '  %4d', $aElev->[$y][$x];
			}
		}
		print "\n";
	}
	print "----------\n";
}




sub setEntryText {
	my( $self, $entry, $text ) = @_;
	$entry = $self->{'_OGF_'.$entry} if !ref $entry;
	$entry->configure( -state => 'normal' );
	$entry->delete( 0, 'end' );
	$entry->insert( 0, $text );
	$entry->configure( -state => 'readonly' );
}



sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub inRange {
	my( $min, $max, $val ) = @_;
	return $min if $val < $min;
	return $max if $val > $max;
	return $val;
}

sub setPositionValue {
	my( $self, $hTile, $x, $y, $hOpt ) = @_;
	$hTile->{_modified} = 1;
	my( $sc, $tool, $elev ) = ( $self->{_OGF_scale}, $self->{_OGF_tool}, $self->{_OGF_altitude} );
	my( $aContour, $aStream ) = ( $hTile->{_contour}, $hTile->{_stream} );
	$tool = $hOpt->{'tool'} if $hOpt && $hOpt->{'tool'}; 

#	print STDERR "\$elev <", $elev, ">\n";  # _DEBUG_
	if( $self->{_OGF_drag} && $self->{_OGF_drag}{_action} eq 'Erase' ){
		my $elevErase	=	$NO_ELEV_VALUE;
		my $sz = 2;
#		$self->{_OGF_photo}->put( '#FFFFFF', -to => $x-$sz,$y-$sz, $x+$sz,$y+$sz );
#		$self->{_OGF_photo}->put( '#FFFFFF', -to => $sc*$x-$sz,$sc*$y-$sz, $sc*$x+$sz,$sc*$y+$sz );
		for( my $yy = $y-$sz; $yy <= $y+$sz; ++$yy ){
			for( my $xx = $x-$sz; $xx <= $x+$sz; ++$xx ){
				if( $xx >= 0 && $xx < $T_WIDTH && $yy >= 0 && $yy < $T_HEIGHT ){
					if( $tool eq 'Stream' ){
						$aStream->[$yy][$xx]  = $NO_ELEV_VALUE;
					}elsif( $tool eq 'Contour' ){
						$elevErase = $aContour->[$yy][$xx] if $aContour->[$yy][$xx] != $NO_ELEV_VALUE && !defined $self->{_OGF_drag}{_elev};
						$aContour->[$yy][$xx] = $NO_ELEV_VALUE if $aContour->[$yy][$xx] == $elev;
					}
				}
			}
		}
		if( $elevErase != $NO_ELEV_VALUE ){
#			$self->setAltitude( $elevErase, 1 );
			$self->selectListbox_Elev( 'value' => $elevErase );
			$self->{_OGF_drag}{_elev} = $elevErase;
		}

#		my @regionFrom = ( $x-$sz, $y-$sz, $x+$sz, $y+$sz );
		my @regionFrom = map {$sc * $_} map {inRange(0,$T_WIDTH,$_)} ( $x-$sz, $y-$sz, $x+$sz, $y+$sz );
#		my @regionTo = map {$sc * $_} @regionFrom;
		my @regionTo = @regionFrom;
		$hTile->{_photo}->copy( $hTile->{_erase}, -from => @regionFrom, -to => @regionTo );
		$self->makeDataOverlay( $hTile, $aContour, [$x-$sz,$y-$sz,$x+$sz,$y+$sz], 'Contour' );
		$self->makeDataOverlay( $hTile, $aStream,  [$x-$sz,$y-$sz,$x+$sz,$y+$sz], 'Stream' );
		return;
	}

	if( $x >= 0 && $x < $T_WIDTH && $y >= 0 && $y < $T_HEIGHT ){
		my( $aCache, $elev ) = ($tool eq 'Stream')? ($aStream,0) : ($aContour,$elev);
		$aCache->[$y][$x] = $elev;
#		$self->{_OGF_photo}->put( $self->getElevationColor(), -to => $x,$y );
		$self->setPhotoPixel( $hTile->{_photo}, $x, $y, $self->getElevationColor($elev,$tool) );
	}
	if( $self->{_OGF_drag} && $hOpt && $hOpt->{'line'} ){
		my( $hTile, $xD, $yD ) = map {$self->{_OGF_drag}{$_}} qw/_tile _x _y/;
		my @linePts = $self->getLinePoints( [$xD,$yD], [$x,$y] );
		foreach my $pt ( @linePts ){
			$self->setPositionValue( $hTile, $pt->[0], $pt->[1] );
		}
	}
}

sub getLayerValue {
	my( $self, $hTile, $x, $y ) = @_;
	my( $layerType, $aLayer, $elev );
	if( $self->{_OGF_valCheckboxContour} && $hTile->{_contour}[$y][$x] != $NO_ELEV_VALUE ){
		( $layerType, $aLayer, $elev ) = ( 'Contour', $hTile->{_contour}, $hTile->{_contour}->[$y][$x] );
	}elsif( $self->{_OGF_valCheckboxStream} && $hTile->{_stream}[$y][$x] != $NO_ELEV_VALUE ){
		( $layerType, $aLayer, $elev ) = ( 'Stream', $hTile->{_stream}, $hTile->{_stream}[$y][$x] );
	}
	return ( $layerType, $aLayer, $elev );
}


sub selectConnectedShape {
	my( $self, $hTile, $x, $y ) = @_;
	$self->clearSelectedShape( $hTile ) if $hTile->{_selectedShape};

	my( $layerType, $aLayer, $elev ) = $self->getLayerValue( $hTile, $x, $y );
	return if ! $layerType;

	OGF::Util::Shape::setEditor( $self, 0 );
	my $shape = OGF::Util::Shape::connectedShape( $aLayer, [$x,$y], 'E8', sub{
		my( $x, $y ) = @_;
		return ($aLayer->[$y][$x] == $elev);
	} );
	OGF::Util::Shape::setEditor( undef );

	$shape->{_layer} = $layerType;
	$shape->{_elev}  = $elev;
	$hTile->{_selectedShape} = $shape;

	return $shape;
}

sub setSelectedShapeValue {
	my( $self, $hTile, $val ) = @_;
	return if ! $hTile->{_selectedShape};

	my $aLayer = $hTile->{_contour};
	my @coord = values %{$hTile->{_selectedShape}{_shape}};
	foreach my $aPt ( @coord ){
		my( $x, $y ) = @$aPt;
		$aLayer->[$y][$x] = $val;
	}
	$hTile->{_modified} = 1;
	$self->clearSelectedShape( $hTile );
}

sub clearSelectedShape {
	my( $self, $hTile, $val ) = @_;
	return if ! $hTile->{_selectedShape};

	my $shape = $hTile->{_selectedShape};
	my $color;
	my $aLayer = $shape->{_tile};
	my @coord = values %{$shape->{_shape}};

	OGF::Util::Shape::setEditor( $self );
	foreach my $aPt ( @coord ){
		my( $x, $y ) = @$aPt;
		$color = $self->getElevationColor( $aLayer->[$y][$x], $shape->{_layer} ) if ! $color; 
		$self->setPhotoPixel( $hTile->{_photo}, $x, $y, $color );
	}
	OGF::Util::Shape::setEditor( undef );

	$hTile->{_selectedShape} = undef;
}

sub repairConnectedShape {
	my( $self, $hTile, $x, $y ) = @_;
	$self->repairConnectedShape_R( $hTile, $x, $y );
	delete $hTile->{_return};
}

sub repairConnectedShape_R {
	my( $self, $hTile, $x, $y ) = @_;
	my $shape = $self->selectConnectedShape( $hTile, $x, $y );
	my $border = $shape->getBorder( 'outer', 'E8' );
	my $border2 = $border->getBorder( 'outer', 'E8' )->subtract( $shape );

	my( $aLayer, $elev ) = ( $shape->{_tile}, $shape->{_elev} );
	foreach my $pt ( $border2->points() ){ 
		return if $hTile->{_return};
		my( $xA, $yA ) = @$pt;
		if( $aLayer->[$yA][$xA] == $elev ){
			my( $ptBorder ) = grep {OGF::Util::Shape::pxDist($pt,$_) == 1} $border->points();
			if( $ptBorder ){
				my( $xB, $yB ) = @$ptBorder;
				$self->setPhotoPixel( $hTile->{_photo}, $xB, $yB, '#FFFF00' );
				my $ret = $self->showDialog( 'repairConnectedShape', "Repair at: ($xB,$yB)", ['Yes','No','Cancel'] );
				if( $ret eq 'Cancel' ){
					$hTile->{_return} = 1;
					return;
				}else{
					if( $ret eq 'Yes' ){
						$aLayer->[$ptBorder->[$xB]][$yB] = $elev;
						$self->setPositionValue( $hTile, $xB, $yB, {'tool' => $shape->{_layer}} );
					}else{
						$self->setPhotoPixel( $hTile->{_photo}, $xB, $yB, '#000000' );
					}
					$self->repairConnectedShape_R( $hTile, $xA, $yA );
				}
			}
		}
	}
}

sub correctSelectedShapeLayer {
	my( $self ) = @_;
	my $hTile = $self->{_OGF_activeTile};
	return if ! ($hTile && $hTile->{_selectedShape}); 

	my( $tool, $shape ) = ( $self->{_OGF_tool}, $hTile->{_selectedShape} ); 
	my( $layerSrc, $layerDst ) = ( $shape->{_layer}, $tool );
	return if $layerSrc eq $layerDst;
	
	my( $aLayerSrc ) = ($layerSrc eq 'Stream')? $hTile->{_stream} : $hTile->{_contour};
	my( $aLayerDst ) = ($layerDst eq 'Stream')? $hTile->{_stream} : $hTile->{_contour};

	foreach my $pt ( $shape->points() ){
		my( $x, $y ) = @$pt;
		$aLayerDst->[$y][$x] = 0;
		$aLayerSrc->[$y][$x] = $NO_ELEV_VALUE;
	}
}


sub fillConnectedArea {
	my( $self, $hTile, $x, $y, $action ) = @_;
	$self->clearSelectedShape( $hTile ) if $hTile->{_selectedShape};

	print STDERR "\$x <", $x, ">  \$y <", $y, ">  \%{\$hTile->{_wwInfo}} <", join('|',%{$hTile->{_wwInfo}}), ">\n";  # _DEBUG_
	my( $layerType, $aLayer, $elev ) = $self->{_OGF_valCheckboxContour}
		? ( 'Contour', $hTile->{_contour}, $hTile->{_contour}->[$y][$x] )
		: ( 'Contour', $hTile->{_stream},  $hTile->{_layer}->[$y][$x] );
	return if $aLayer->[$y][$x] != $NO_ELEV_VALUE;

	my $shape;
	OGF::Util::Shape::setEditor( $self, 0, ($action eq 'InlandWater')? $COLOR_CONF{'Water'} : $COLOR_CONF{'Fill'} );
	eval{
		my $borderElev = undef;
		$self->{_OGF_currentProcedure} = 'Fill';
		$shape = OGF::Util::Shape::connectedShape( $aLayer, [$x,$y], 'E4', sub{
			die qq/PROCEDURE_STOPPED/ if $self->{_OGF_currentProcedure} eq '';
			my( $x, $y ) = @_;
#			return ($aLayer->[$y][$x] == $NO_ELEV_VALUE);
			if( defined $borderElev ){
				return ($aLayer->[$y][$x] != $borderElev);
			}else{
				if( $aLayer->[$y][$x] == $NO_ELEV_VALUE ){
					return 1;
				}else{
					$borderElev = $aLayer->[$y][$x];
					return 0;
				}
			}
		} );
	};
	$self->{_OGF_currentProcedure} = '';
	OGF::Util::Shape::setEditor( undef );

	return $shape;
}


sub displayMagnifyTool {
	my( $self, $hTile, $xE, $yE, $wd, $hg, $sc ) = @_;
	$self->removeMagnifyTool();

	my( $wd2, $hg2, $scTile ) = ( int($wd/2), int($hg/2), $self->{_OGF_scale} );
	( $wd, $hg ) = ( 2*$wd2+1, 2*$hg2+1 );
	my $photo = $self->Photo( -width => $wd*$sc, height => $hg*$sc );

	for( my $y = 0; $y < $hg; ++$y ){
		for( my $x = 0; $x < $wd; ++$x ){
			my( $xs, $ys ) = ( $xE - $wd2 + $x, $yE - $hg2 + $y );
			if( OGF::Util::Shape::inArea([$T_WIDTH,$T_HEIGHT],[$xs,$ys]) ){
				my @color = $hTile->{_photo}->get( $xs * $scTile, $ys * $scTile );
				$photo->put( sprintf('#%02X%02X%02X',@color), -to => $x*$sc,$y*$sc, ($x+1)*$sc,($y+1)*$sc );
			}
		}
	}

	my $cnv = $self->{_OGF_canvas};
	my( $x0, $y0 ) = ( $self->{_OGF_scrWd} * ($cnv->xview())[1] - $wd*$sc - 10, $self->{_OGF_scrHg} * ($cnv->yview())[0] + 10 );
	my $img = $cnv->createImage( $x0, $y0, -image => $photo, -anchor => 'nw', -tag => 'magnify' );
	$self->{_OGF_magnifyTool} = $self->{_OGF_tiles}{$img} = {
		_photo => $photo,
		_img   => $img,
		_tile  => $hTile,
		_area  => [ $xE-$wd2, $yE-$hg2, $wd, $hg ],
		_scale => $sc, 
	};
}

sub removeMagnifyTool {
	my( $self ) = @_;
	return if ! $self->{_OGF_magnifyTool};

	$self->{_OGF_canvas}->delete( $self->{_OGF_magnifyTool}{_img} );
	$self->{_OGF_magnifyTool}{_photo}->destroy();
	$self->{_OGF_magnifyTool}{_photo}->delete();
	
	$self->{_OGF_magnifyTool} = undef;
}



sub testFunction {
	my( $self, $hTile, $xE, $yE ) = @_;
	$self->radiusInterpolation( $hTile, $xE, $yE );

#	OGF::Util::Shape::setEditor( $self );
#	OGF::Util::Shape::sharpenContourLines( $hTile->{_contour}, $NO_ELEV_VALUE, $hTile->{_stream} );
}

sub radiusInterpolation {
	my( $self, $hTile, $xE, $yE ) = @_;
	OGF::Terrain::ElevationTile::mergeStreamArrayIntoContourLayer( $hTile->{_contour}, $hTile->{_stream} ) if ! $hTile->{_streamMerge};
	$self->{_OGF_streamMerge} = 1;
	OGF::Terrain::ElevationTile::setEditor( $self, 0 );
	my $aLineMatrix = OGF::Terrain::ElevationTile::makeLineMatrix( 20 );
	my $val = OGF::Terrain::ElevationTile::windowValue( $hTile->{_contour}, 20, $yE, $xE, $aLineMatrix );
	print STDERR "[$yE,$xE] -> $val\n";  # _DEBUG_
}


sub getLinePoints {
	my( $self, $ptA, $ptB ) = @_;
	my @linePts;
	my( $xA, $yA, $xB, $yB ) = ( @$ptA, @$ptB );
	my( $dx, $dy ) = ( $xB - $xA, $yB - $yA );
	return @linePts if $dx == 0 && $dy == 0;

	if( abs($dx) >= abs($dy) ){
		my $d = ($xB > $xA)? 1 : -1;
		for( my $x = $xA+$d; $x != $xB; $x+=$d ){
			my $y = int($yA + ($x-$xA) * $dy/$dx);
			push @linePts, [$x,$y];
		}
	}else{
		my $d = ($yB > $yA)? 1 : -1;
		for( my $y = $yA+$d; $y != $yB; $y+=$d ){
			my $x = int($xA + ($y-$yA) * $dx/$dy);
			push @linePts, [$x,$y];
		}
	}
	return @linePts;
}

sub autoGenerateContour {
	my( $self, $hTile ) = @_;
	my( $aContour ) = $hTile->{_contour};
	my( $photo, $photoE ) = ( $hTile->{_photo}, $hTile->{_erase} );

#	my $cContourColor = sub{
#		my( $red, $green, $blue ) = @_;
##		print STDERR "r:", $red, "  g:", $green, "  b:", $blue;  # _DEBUG_
#		my $val = ( $red >= 200 && $green >= 128 && $blue < 128 );
##		print STDERR " --> ", $val, "\n";  # _DEBUG_
#		return $val;
#	};

	my $funcText = readFromFile( 'C:/usr/MapView/contourByColor.pl' );
	my $cContourColor = eval $funcText;

	for( my $y = 0; $y < $T_HEIGHT; ++$y ){
		for( my $x = 0; $x < $T_WIDTH; ++$x ){
#			print STDERR "[", $y, "] [", $x, "]  ";  # _DEBUG_
			my @color = $photoE->get( $x, $y );
			$aContour->[$y][$x] = $cContourColor->(@color) ? 200 : $NO_ELEV_VALUE;
#			print STDERR "\$aContour->[$y][$x] <", $aContour->[$y][$x], ">\n";  # _DEBUG_
		}
	}

	my $sc = $self->{_OGF_scale};
	$photo->copy( $photoE, -zoom => $sc,$sc, -from => 0,0,$T_WIDTH,$T_HEIGHT, -to => 0,0 );
	$self->makeDataOverlay( $photo, $aContour );
}

sub writeTaskList {
	my( $self ) = @_;
	local *OUTFILE;
	open( OUTFILE, '>>', $OGF::LayerInfo::TASK_PROCESSING_LIST ) or die qq/Cannot open "$OGF::LayerInfo::TASK_PROCESSING_LIST" for writing: $!\n/;
	foreach my $key ( keys %{$self->{_OGF_savedTiles}} ){
		print OUTFILE time(), " 10 elev,phys ", $key, "\n";
	}
	close OUTFILE;
}

sub saveElevationTile {
	my( $self ) = @_;

	my @tiles = values %{$self->{_OGF_tiles}};
	foreach my $hTile ( @tiles ){
		next unless $hTile->{_modified} && $hTile->{_photo};
		my( $layer, $level, $y, $x ) = $hTile->{_wwInfo}->getAttr(qw/layer level y x/);
		print STDERR "Save tile: $layer ($level) $y $x\n";

		my $dataCnr = makeTileFromArray( $hTile->{_contour}, $BPP );
		my $outFileCnr = $hTile->{_wwInfo}->copy('type' => 'contour')->tileName();
		print STDERR "\$outFileCnr <", $outFileCnr, ">\n";  # _DEBUG_
		makeBackupCopy( $outFileCnr );
		writeToFile( $outFileCnr, $dataCnr, undef, {-bin => 1, -mdir => 1} );

		my $dataStm = makeTileFromArray( $hTile->{_stream}, $BPP );
		my $outFileStm = $hTile->{_wwInfo}->copy('type' => 'stream')->tileName();
		print STDERR "\$outFileStm <", $outFileStm, ">\n";  # _DEBUG_
		makeBackupCopy( $outFileStm );
		writeToFile( $outFileStm, $dataStm, undef, {-bin => 1, -mdir => 1} );

		if( $hTile->{_inlandWaters} ){
			my $wwInfo = $hTile->{_wwInfo}->copy('type' => 'water');
			my( $outFileWat, $aWater ) = ( $wwInfo->tileName(), $wwInfo->tileArray() );
			makeBackupCopy( $outFileWat );
			setInlandWaterPoints( $aWater, $hTile->{_inlandWaters} );
			my $dataWat = makeTileFromArray( $aWater, $BPP );
			writeToFile( $outFileWat, $dataWat, undef, {-bin => 1, -mdir => 1} );
		}

		$hTile->{_modified} = 0;
		$self->{_OGF_savedTiles}{$hTile->{_wwInfo}->toString()} = 1;
	}
}

sub makeBackupCopy {
	my( $file ) = @_;
	my $BACKUP_DIR = 'C:/Map/Common/Backup';
	my $backupFile = $file;
	$backupFile =~ s|^[A-Z]:/Map/||;
	$backupFile =~ s|/|-|g;
	$backupFile =~ s|\.(\w+)$|-001.$1|g;
	$backupFile = $BACKUP_DIR .'/'. $backupFile;
	while( -e $backupFile ){
		$backupFile =~ s/-(\d+)(?=\.\w+$)/sprintf('-%03d',$1+1)/e;
	}
	copy( $file, $backupFile ); 
}

sub setInlandWaterPoints {
	my( $aLayer, $aShapes ) = @_;
	foreach my $shape ( @$aShapes ){
		foreach my $pt ( $shape->points() ){
			my( $x, $y ) = @$pt;
			$aLayer->[$y][$x] = 0;
		}
	}
}


#-------------------------------------------------------------------------------



sub loadTiles {
#	my( $self, $layer, $tx, $ty, $level ) = @_;
	my( $self, $wwInfo ) = @_;

	my( $wwType, $layer, $level, $ty, $tx )
		= ( $self->{_OGF_wwType}, $self->{_OGF_layer}, $self->{_OGF_level}, $self->{_OGF_ty}, $self->{_OGF_tx} )
		= map {$wwInfo->{$_}} qw/ type layer level y x /;

	print STDERR "\$wwType <", $wwType, ">  \$layer <", $layer, ">  \$level <", $level, ">  \$ty <", $ty, ">  \$tx <", $tx, ">\n";  # _DEBUG_
	$self->toplevel()->configure( -title => "TILE  " . $wwInfo->toString() );
	$self->selectListbox_Elev( 'value' => 0 );

	my( $centerY, $centerX ) = ( int($TILES_Y/2), int($TILES_X/2) );
	if( ref($tx) eq 'ARRAY' ){
		$TILES_X = $tx->[1] - $tx->[0] + 1;
		$tx = $tx->[0];
	}else{
		$tx = $tx - $centerX;
	}
	if( ref($ty) eq 'ARRAY' ){
		$TILES_Y = $ty->[1] - $ty->[0] + 1;
		$ty = $ty->[0];
	}else{
		$ty = $ty - $centerY;
	}
	my $scrWd = $self->{_OGF_scrWd} = $TILES_X * $self->{_OGF_scale} * $T_WIDTH  + 2 * $self->{_OGF_margin};
	my $scrHg = $self->{_OGF_scrHg} = $TILES_Y * $self->{_OGF_scale} * $T_HEIGHT + 2 * $self->{_OGF_margin};
	$self->{_OGF_canvas}->configure( -scrollregion => [0,0,$scrWd,$scrHg] );

	for( my $y = 0; $y < $TILES_Y; ++$y ){
		for( my $x = 0; $x < $TILES_X; ++$x ){
			my $info = $wwInfo->copy( 'x' => $tx+$x, 'y' => $ty+$y );
			my $hTile = $self->loadTile( $info, $x, $y );
#			$self->{_OGF_photo} = $photo if $x == 0 && $y == 0;
			if( $hTile ){
				$self->scrollImgToCenter( $hTile->{_img} );
				$hTile->{_elev} = $info->copy('type' => 'elev')->tileArray();
				( $hTile->{_contour}, $hTile->{_stream} ) = $self->redrawOverlays( $hTile );
			}
		}
	}

	( $centerY, $centerX ) = ( int($TILES_Y/2), int($TILES_X/2) );
	$self->scrollImgToCenter( $self->{_OGF_tile_grid}[$centerY][$centerX]{_img} );
	$self->{_OGF_activeTile} = $self->{_OGF_tile_grid}[$centerY][$centerX];
	$self->showDialog( 'loadTiles', 'Tiles loaded completely.' );
}

sub showDialog { 
	my( $self, $title, $text, $aButtons ) = @_;
	$aButtons = ['OK'] if ! $aButtons;
	my $dialog = $self->Dialog(
		-title   => $title, 
		-text    => $text, 
		-buttons => $aButtons,
		-default_button => $aButtons->[0],
	);
	my $ret = $dialog->Show();
	return $ret;
}


sub loadTile {
	my( $self, $wwInfo, $x, $y ) = @_;
	my $sc = $self->{_OGF_scale};
	my $file = $wwInfo->tileNameGenerated();
#	print STDERR "loadTile( $file, $x, $x )\n";  # _DEBUG_
	$file =~ s|\\|/|g;
#	print "loadFile( $file )\n";  # _DEBUG_

	if( $file =~ /\.bmp$/i ){
		return unless checkBMP( $file );
	}

	$self->update();  # necessary to get correct width/height
	my( $wdV, $hgV, $wdP, $hgP ) = ( $self->{_OGF_canvas}->width(), $self->{_OGF_canvas}->height(), $sc*$T_WIDTH, $sc*$T_HEIGHT );

	my $hTile = $self->{_OGF_tile_grid}[$y][$x] = { _wwInfo => $wwInfo, };
	my $photo;
	if( -f $file ){
		my $photoE = $self->Photo( -width => $wdP, -height => $hgP );
		my( $type, $level, $tx, $ty ) = $wwInfo->getAttr( 'type', 'level', 'x', 'y' );
		if( $type eq 'image' && ($sc == 2 || $sc == 4) ){
			my $upLevel = $level + (($sc == 4)? 2 : 1); 
			for( my $yp = 0; $yp < $sc; ++$yp ){
				for( my $xp = 0; $xp < $sc; ++$xp ){
					my $upLevelFile = $wwInfo->copy('level' => $upLevel, 'x' => $sc*$tx+$xp, 'y' => $sc*$ty+$yp)->tileName();
					if( $upLevelFile =~ m|http://| ){
						$upLevelFile = OGF::LayerInfo::cachedUrlTile( $upLevelFile );
					}
					if( -f $upLevelFile ){
						my $ypp = ($TILE_ORDER_Y > 0)? $yp : ($sc-$yp-1);
						my $photoX = $self->Photo( -file => $upLevelFile, -gamma => 0.75 );
						$photoE->copy( $photoX, -to => $xp*$T_WIDTH,$ypp*$T_HEIGHT );
					}
				}
			}
		}else{
			my $photoX = $self->Photo( -file => $file, -gamma => 0.75 );
			$photoE->copy( $photoX, -zoom => $sc,$sc );
		}
		$hTile->{_erase} = $photoE; #  if $x == 0 && $y == 0;
		$photo = $hTile->{_photo} = $self->Photo( -width => $wdP, height => $hgP );
		$photo->copy( $photoE );
	}else{
#		$photo = ...
		return undef;
	}

	my $X =                      $self->{_OGF_margin} + $x * $wdP + $TILE_DIST * $x;
	my $Y = ($TILE_ORDER_Y > 0)? $self->{_OGF_margin} + $y * $hgP + $TILE_DIST * $y : $self->{_OGF_margin} + ($TILES_Y - 1 - $y) * $hgP - $TILE_DIST * $y;
#	print STDERR "\$X <", $X, ">  \$Y <", $Y, ">\n";  # _DEBUG_

	my $img = $hTile->{_img} = $self->{_OGF_canvas}->createImage( $X, $Y, -image => $photo, -anchor => 'nw', -tag => 'img' );
	$self->{_OGF_tiles}{$img} = $hTile;

	return $hTile;
}

sub scrollImgToCenter {
	my( $self, $img ) = @_;
#	print STDERR "\$img <", $img, ">\n";  # _DEBUG_
	return if ! $img;
	my( $cnv, $sc ) = ( $self->{_OGF_canvas}, $self->{_OGF_scale} );
	my( $xp, $yp ) = $cnv->coords( $img );
#	print STDERR "\$cnv <", $cnv, ">  \$sc <", $sc, ">  \$xp <", $xp, ">  \$yp <", $yp, ">\n";  # _DEBUG_
	( $xp, $yp ) = ( $xp + $T_WIDTH * $sc / 2, $yp + $T_HEIGHT * $sc / 2 );
	my $aScr = $cnv->cget( '-scrollregion' );
	my( $wd, $hg, $wdScr, $hgScr ) = ( $cnv->width, $cnv->height, $aScr->[2], $aScr->[3] );
#	print STDERR "\$wd <", $wd, ">  \$hg <", $hg, ">  \$wdScr <", $wdScr, ">  \$hgScr <", $hgScr, ">\n";  # _DEBUG_
	my( $xLeft, $yTop )  = ( $xp - $wd/2, $yp - $hg/2 );
#	print STDERR "  \$xLeft <", $xLeft, ">  \$yTop <", $yTop, ">\n";  # _DEBUG_
	my( $xFrac, $yFrac ) = ( max(0,$xLeft/$wdScr), max(0,$yTop/$hgScr) );
#	print STDERR "  \$xFrac <", $xFrac, ">  \$yFrac <", $yFrac, ">\n";  # _DEBUG_
	$cnv->xviewMoveto( $xFrac );
	$cnv->yviewMoveto( $yFrac );
	$cnv->update();
}




sub makeDataOverlay {
	my( $self, $hTile, $aRows, $aArea, $colorMode ) = @_;
	$colorMode = 'Contour' if ! $colorMode;	
	my $sc = $self->{_OGF_scale};
	my( $twd, $thg ) = OGF::Util::Shape::getTileSize( $aRows );
#	print STDERR "\$twd <", $twd, ">  \$thg <", $thg, ">\n";  # _DEBUG_
	my( $x0, $y0, $x1, $y1 ) = $aArea ? @$aArea : (0,0, scalar(@{$aRows->[0]})-1,scalar(@$aRows)-1);
	for( my $y = $y0; $y <= $y1; ++$y ){
		for( my $x = $x0; $x <= $x1; ++$x ){
#			print STDERR "\$x <", $x, ">  \$y <", $y, ">\n";  # _DEBUG_
			next if ! OGF::Util::Shape::inArea([$twd,$thg],[$x,$y]);
 			my $elev = $aRows->[$y][$x];
			if( $elev != $NO_ELEV_VALUE ){
				my $color = $self->getElevationColor( $elev, $colorMode );
				$self->setPhotoPixel( $hTile->{_photo}, $x, $y, $color );
			}
		}
	}
}

sub redrawOverlays {
#	my( $self, $layer, $x, $y, $photo ) = @_;
	my( $self, $hTile ) = @_;
	if( !defined $hTile ){
#		( $layer, $x, $y, $photo, my $sc ) = ( $self->{_OGF_layer}, $self->{_OGF_tx}, $self->{_OGF_ty}, $self->{_OGF_photo}, $self->{_OGF_scale} );
		my $sc = $self->{_OGF_scale};
		$hTile = $self->{_OGF_activeTile};
		return if !defined $hTile;
		$hTile->{_photo}->copy( $hTile->{_erase}, -from => 0,0,$sc*$T_WIDTH,$sc*$T_HEIGHT, -to => 0,0 ) if $hTile->{_photo};
	}
#	my( $x, $y ) = $hTile->{_wwInfo}->getAttr( 'x', 'y' );

	my( $aContour, $aStream, $aWater );
	if( 1 ){ 
		if( $hTile->{_water} ){
			$aWater = $hTile->{_water};
		}else{
			$aWater = $hTile->{_wwInfo}->copy('type' => 'water')->tileArray();
		}
		$self->makeDataOverlay( $hTile, $aWater, undef, 'Water' ) if $aWater;
	}
	if( $self->{_OGF_valCheckboxStream} ){
		if( $hTile->{_stream} ){
			$aStream = $hTile->{_stream};
		}else{
			$aStream = $hTile->{_wwInfo}->copy('type' => 'stream')->tileArray();
		}
		$self->makeDataOverlay( $hTile, $aStream, undef, 'Stream' ) if $aStream;
	}
	if( $self->{_OGF_valCheckboxContour} ){
		if( $hTile->{_contour} ){
			$aContour = $hTile->{_contour};
		}else{
			$aContour = $hTile->{_wwInfo}->copy('type' => 'contour')->tileArray();
		}
		$self->makeDataOverlay( $hTile, $aContour, undef, 'Contour' ) if $aContour;
	}
	return ( $aContour, $aStream );
}


sub getElevationColor {
	my( $self, $elev, $colorMode ) = @_;
	$elev = $self->{_OGF_altitude} if !defined $elev;
#	return '#0044FF' if $elev == 0 && $colorMode && $colorMode eq 'Stream';
	return $COLOR_CONF{$colorMode} if $elev == 0 && $colorMode && $colorMode ne 'Contour';
	return '#000088' if $elev == 0;
	return '#880000' if $elev % 200 == 0;
	return '#008800' if $elev %  50 == 0;
#	return '#BBBBBB' if $elev %  50 == 0;
	return '#888800';
}




sub showRGB {
	my( $self, $hTile, $xE,$yE, $action ) = @_;
#	my $ev = $self->{_OGF_canvas}->Subwidget('scrolled')->XEvent();
#	my $ev = $self->{_OGF_canvas}->XEvent();
#	my( $hTile, $xE, $yE ) = $self->imageEventPos( $ev );
#	my( $ph, $xP, $yP ) = ( $self->{_OGF_photo}, $self->{_OGF_xpos}, $self->{_OGF_ypos} );
#	my( $xE, $yE ) = ( int($ev->x + $ph->width()/2 - $xP), int($ev->y + $ph->height()/2 - $yP) );
#	print STDERR "\$xE <", $xE, ">  \$yE <", $yE, ">\n";  # _DEBUG_
	my( $cR, $cG, $cB ) = $hTile->{_photo}->get( $xE, $yE );
#	my $text = "R $cR   G $cG   B $cB";
	my $text = sprintf "Position ($xE,$yE)   --   R:%d   G:%d   B:%d   --   %02X %02X %02X", $cR, $cG, $cB, $cR, $cG, $cB;

	$OGF::Util::TK_APP = $self;
	infoDialog( $text );
}


sub setPhotoPixel {
	my( $self, $photo, $x, $y, $color ) = @_;
#	$photo = $self->{_OGF_photo} if !defined $photo;
	my $sc = $self->{_OGF_scale};
	$photo->put( $color, -to => $x*$sc,$y*$sc, ($x+1)*$sc,($y+1)*$sc );

	if( $self->{_OGF_magnifyTool} ){
		my $mt = $self->{_OGF_magnifyTool};
		my( $sc, $x0, $y0, $wd, $hg ) = ( $mt->{_scale}, @{$mt->{_area}} );
		if( $x >= $x0 && $x < $x0+$wd && $y >= $y0 && $y < $y0+$hg ){
			$mt->{_photo}->put( $color, -to => ($x-$x0)*$sc,($y-$y0)*$sc, ($x-$x0+1)*$sc,($y-$y0+1)*$sc );
		}
	}
}

sub updatePhotoPixel {
	require Time::HiRes;
	my( $self, $x, $y, $color ) = @_;
#	$x -= 128;
#	$y -= 128;
	return if $x < 0 || $y < 0 || $x >= $T_WIDTH || $y >= $T_HEIGHT;
	$color = $SHAPE_PAINT_COLOR if !defined $color;
	Time::HiRes::sleep( $SHAPE_PAINT_DELAY ) if $SHAPE_PAINT_DELAY;
	if( $self->{_OGF_activeTile} ){
		if( $color eq 'erase' ){
			my $erase = $self->{_OGF_activeTile}{_erase};
			my @c = $erase->get($x,$y);
			$color = sprintf( '#%02X%02X%02X', @c );
		}
		my $photo = $self->{_OGF_activeTile}{_photo};
		$self->setPhotoPixel( $photo, $x, $y, $color );
		$photo->update();
	}
}

sub setPixelPaintDelay {
	my( $self, $delay ) = @_;
	$SHAPE_PAINT_DELAY = (defined $delay)? $delay : 0.001;
}

sub setPixelPaintColor {
	my( $self, $color ) = @_;
	$SHAPE_PAINT_COLOR = (defined $color)? $color : '#FF0000';
}



#--- utility functions ------------------------------------------------------------------------

sub getNonCoveredTiles {
	require File::Find;
	my( $layer, $startDir, $regex, $targetFileFunc, $mtime ) = @_;
	my( $numTotal, $numNon, @list ) = ( 0, 0 );
	File::Find::find(	{ wanted => sub {
		if( $File::Find::name =~ /$regex/ ){
			++$numTotal;
			my( $tx, $ty ) = ( int($2), int($1) );
			my $targetFile = OGF::LayerInfo->$targetFileFunc( $layer, $tx, $ty );
#			if( ! -f $targetFile ){
			if( ! -f $targetFile || (defined $mtime && (stat $targetFile)[9] < $mtime) ){
				++$numNon;
				push @list, [$layer,$tx,$ty];
			}
		}
	}, no_chdir => 1 }, $startDir	);
	print "$layer: $numNon/$numTotal\n";
	return @list;
}


#--- ogf files --------------------------------------------------------------------------------

sub ogfLoadFile {
	require OGF::Data::Context;
	my( $self, $file, $projDsc ) = @_;

	my $ctx = OGF::Data::Context->new();
	$ctx->loadFromFile( $file );

	my @tiles = values %{$self->{_OGF_tiles}};
	foreach my $hTile ( @tiles ){
		$self->ogfPaintContext( $hTile, $ctx, $projDsc );
	}
}

sub ogfPaintContext {
	my( $self, $hTile, $ctx, $projDsc ) = @_;

	my $proj = $self->ogfProjection( $projDsc, $hTile );
	$ctx->{_proj} = $proj;
	$self->{_OGF_altitude} = 0;
	$self->{_OGF_projDsc}  = $projDsc;

	foreach my $way ( values %{$ctx->{_Way}} ){
		my( $hTags, $tool ) = ( $way->{'tags'} );
		if( $hTags->{'natural'} && $hTags->{'natural'} eq 'coastline' ){
			$tool = 'Contour';
		}elsif( $hTags->{'natural'} && $hTags->{'natural'} eq 'water' ){
			$tool = 'Water';
		}elsif( $hTags->{'waterway'} && $hTags->{'waterway'} =~ /^(river|riverbank|stream)$/ ){
			$tool = 'Stream';
		}
		next if ! $tool;
		$self->{_OGF_tool} = $tool;
		print STDERR "draw $way->{id} \$tool <", $tool, ">\n";  # _DEBUG_
		foreach my $node ( map {$ctx->{_Node}{$_}} @{$way->{'nodes'}} ){
			my( $x, $y ) = $proj->geo2cnv( $node->{'lon'}, $node->{'lat'} );
			( $x, $y ) = ( POSIX::floor($x + .5), POSIX::floor($y + .5) );
#			print STDERR "  \$x <", $x, ">  \$y <", $y, ">\n";  # _DEBUG_
			$self->setPositionValue( $hTile, $x, $y, {'line' => 1} );
			$self->{_OGF_drag} = { _tile => $hTile, _x => $x, _y => $y, _action => '' };
		}
		$self->{_OGF_drag} = undef;
	}
	foreach my $node ( values %{$ctx->{_Node}} ){
		my( $hTags, $tool, $elev ) = ( $node->{'tags'} );
		if( $hTags->{'natural'} && $hTags->{'natural'} eq 'peak' ){
			$tool = 'Contour';
			$elev = $hTags->{'ele'};
		}
		next if ! $tool;
		$self->{_OGF_tool}     = $tool;
		$self->{_OGF_altitude}	= $elev;
		print STDERR "draw node elevation $node->{id} -> $elev\n";  # _DEBUG_
		my( $x, $y ) = $proj->geo2cnv( $node->{'lon'}, $node->{'lat'} );
		( $x, $y ) = ( POSIX::floor($x + .5), POSIX::floor($y + .5) );
		$self->setPositionValue( $hTile, $x, $y );
	}
}

sub ogfProjection {
	require OGF::View::TileLayer;
	my( $self, $projDsc, $hTile ) = @_;

	my( $wwInfo, $sc ) = ( $hTile->{_wwInfo}, $self->{_OGF_scale} );
#	use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [$wwInfo], ['wwInfo'] ), "\n";  # _DEBUG_
#	my( $X0, $Y0 ) = $self->{_OGF_canvas}->coords( $hTile->{_img} );
	my( $X0, $Y0 ) = ( 0, 0 );
	my( $X1, $Y1 ) = ( $X0 + $T_WIDTH, $Y0 + $T_HEIGHT );
#	print STDERR "\$X0 <", $X0, ">  \$Y0 <", $Y0, ">  \$X1 <", $X1, ">  \$Y1 <", $Y1, ">\n";  # _DEBUG_

	my $wsz = 20037508.3427892;
	my $lv = $wwInfo->{'level'};
	my( $sizeX, $sizeY ) = ( 2*$wsz / (2**$lv), 2*$wsz / (2**$lv) );
	my $x0 = -$wsz + $wwInfo->{'x'} * $sizeX;
	my $x1 = $x0 + $sizeX;
	my $y0 = $wsz - $wwInfo->{'y'} * $sizeY;
	my $y1 = $y0 - $sizeY;

	my $hTransf = { 'X' => [ $x0 => $X0, $x1 => $X1 ], 'Y' => [ $y0 => $Y0, $y1 => $Y1 ] };
	my $proj = OGF::View::Projection->new( '+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs', $hTransf );

	return $proj;
}



#-------------------------------------------------------------------------------
package Tk::Canvas;

# necessary to disable predefined scrolling actions
sub ClassInit {
	my( $class, $mw ) = @_;
	$class->SUPER::ClassInit( $mw );
}



1;



