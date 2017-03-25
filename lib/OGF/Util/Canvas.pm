package OGF::Util::Canvas;
use strict;
use warnings;
use OGF::Util;
use OGF::Geo::Geometry;
use OGF::Data::Context;


my %TYPE_OPTS = (
    'text'    => [ 'anchor', 'text', 'font' ],
    'polygon' => [ 'outline', 'fill' ],
    'oval'    => [ 'outline', 'fill' ],
);


sub bindSimpleDraw {
	my( $cnv, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my( $curLine, @coords );

    $cnv->Tk::bind( '<ButtonPress-1>' => sub{
        my( $x, $y ) = canvasEventPos( $cnv );
        @coords = ( $x, $y );
        $curLine = $cnv->createLine( $x,$y, $x,$y, -fill => '#000000' );
    } );

    $cnv->Tk::bind( '<Button1-Motion>' => sub{
        my( $x, $y ) = canvasEventPos( $cnv );
        push @coords, $x, $y;
        $cnv->coords( $curLine, @coords );
    } );

    $cnv->Tk::bind( '<ButtonRelease-1>' => sub{
        my( $x, $y ) = canvasEventPos( $cnv );
		$hOpt->{'finalize'}->( $curLine ) if $hOpt->{'finalize'};
        ( $curLine, @coords ) = ( undef );
    } );

    $cnv->toplevel->bind( '<Control-s>' => sub{
        my $file = 'C:/Map/OGF/save/line-' . Date::Format::time2str( '%Y%m%d-%H%M%S', time() ) .'.txt';
        print STDERR "save: ", $file, "\n";  # _DEBUG_
        saveDrawStruct( $cnv, $file );
    } );

    $cnv->toplevel->bind( '<Control-i>' => sub{
        saveDrawStruct( $cnv, '-' );
    } );

	$cnv->toplevel->bind( '<KeyPress>'   => sub{ keyDown($cnv); } );
	$cnv->toplevel->bind( '<KeyRelease>' => sub{ keyRelease($cnv); } );
}

sub bindNodeDraw {
    my( $cnv, $hOpt ) = @_;
    $hOpt = {} if ! $hOpt;
    my( $curLine, $tmpLine, $endPoint, @coords );

    $cnv->Tk::bind( '<ButtonPress-1>' => sub{
        my( $x, $y ) = canvasEventPos( $cnv );
        if( $curLine ){
			push @coords, $x, $y;
            $cnv->coords( $curLine, @coords );
		}else{
	        @coords = ( $x, $y );
            $curLine = $cnv->createLine( $x,$y, $x,$y, -fill => '#000000' );
        }
		$endPoint = [ $x, $y ];
    } );

    $cnv->Tk::bind( '<Motion>' => sub{
        my( $x, $y ) = canvasEventPos( $cnv );
        return if ! $curLine;

        if( $tmpLine ){
            $cnv->coords( $tmpLine, @$endPoint, $x,$y );
		}else{
            $tmpLine = $cnv->createLine( @$endPoint, $x,$y, -fill => '#FF0000' );
        }
    } );

    $cnv->Tk::bind( '<Double-ButtonPress-1>' => sub{
        my( $x, $y ) = canvasEventPos( $cnv );
        return if ! $curLine;

        if( $tmpLine ){
            $cnv->delete( $tmpLine );
            $tmpLine = undef;
        }

        $hOpt->{'finalize'}->( $curLine ) if $hOpt->{'finalize'};
        ( $curLine, @coords ) = ( undef, undef );
    } );

    $cnv->toplevel->bind( '<Control-s>' => sub{
        my $file = 'C:/Map/OGF/save/line-' . Date::Format::time2str( '%Y%m%d-%H%M%S', time() ) .'.txt';
        print STDERR "save: ", $file, "\n";  # _DEBUG_
        saveDrawStruct( $cnv, $file );
    } );

    $cnv->toplevel->bind( '<Control-i>' => sub{
        saveDrawStruct( $cnv, '-' );
    } );

	$cnv->toplevel->bind( '<KeyPress>'   => sub{ keyDown($cnv); } );
	$cnv->toplevel->bind( '<KeyRelease>' => sub{ keyRelease($cnv); } );
}


sub canvasEventPos {
	my( $cnv ) = @_;
	my $ev = $cnv->XEvent();
	my( $xE, $yE ) = ( $cnv->canvasx($ev->x), $cnv->canvasy($ev->y) );
	return ( $xE, $yE );
}



our %KEY_DOWN;

sub keyDown {
	my( $cnv, $ch ) = @_;
	$ch = $cnv->toplevel->XEvent()->K if !defined $ch;
	print STDERR "keyDown <", $ch, ">\n" unless $KEY_DOWN{$ch};  # _DEBUG_
	$ch =~ s/_[LR]$//;    # don't differentiate between Shift_L, Shift_R etc
	$KEY_DOWN{$ch} = 1;
}

sub keyRelease {
	my( $cnv, $ch ) = @_;
	$ch = $cnv->toplevel->XEvent()->K if !defined $ch;
	print STDERR "keyRelease <", $ch, ">\n";  # _DEBUG_
	$ch =~ s/_[LR]$//;
	delete $KEY_DOWN{$ch};
	%KEY_DOWN = {} if $ch eq 'all';
}

sub isKeyDown {
	my( $ch ) = @_;
	return $KEY_DOWN{$ch};
}

sub keyDownList {
	return ( keys %KEY_DOWN );
}



sub drawNodeIndexes {
	my( $cnv, $id ) = @_;
	my @coord = $cnv->coords( $id );
	for( my $i = 0; $i < $#coord; $i+=2 ){
		my( $x, $y ) = ( $coord[$i], $coord[$i+1] );
		drawPointMark( $cnv, $x, $y );
		$cnv->createText( $x+4,$y, -text => $i/2, -fill => '#FF5500', -anchor => 'w' );
	}
}

sub drawPointMark {
	my( $cnv, $x, $y ) = @_;
	my $dd = 1;
	$cnv->createRectangle( $x-$dd,$y-$dd, $x+$dd+1,$y+$dd+1, -outline => '#FF5500' );
}


sub saveDrawStruct {
	require URI::Escape;
	my( $cnv, $file, $hMatch ) = @_;

	my $fh = OGF::Util::fileHandle( $file, '>:encoding(UTF-8)' );
#	open( OUTFILE, '>:encoding(UTF-8)', STDOUT ) or die qq/Cannot open "$file" for writing: $!\n/;
	my @items = $hMatch->{'tag'} ? $cnv->find('withtag',$hMatch->{'tag'}) : $cnv->find('all');
	foreach my $item ( @items ){		
		my $type = $cnv->type( $item );
		next if $hMatch->{'type'} && $type ne $hMatch->{'type'};
		my @coord = $cnv->coords( $item );
		my @opts;
		foreach my $key ( 'tags', @{$TYPE_OPTS{$type}} ){
			my $val = $cnv->itemcget( $item, '-'.$key );
#			print STDERR "\$key <", $key, ">  \$val <", $val, ">\n";  # _DEBUG_
#			if( $key eq 'tags' ){
#				@$val = grep {$_ ne $tag} @$val;
#				next if ! @$val;
#			}
			$val = join( ',', @$val ) if ref($val) eq 'ARRAY';
			next if ! $val;
			$val = URI::Escape::uri_escape( $val, "\n|%" );
			push @opts, "$key=$val";
		}
		$fh->print( $type, "|", join('|',@opts), "|", join("|",@coord) , "\n" );
	}
	$fh->close();
}

sub loadDrawStruct {
	require URI::Escape;
	my( $cnv, $file, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;

#	local *FILE;
#	open( FILE, '<:encoding(UTF-8)', $file ) or die qq/Cannot open "$file": $!\n/;
	my $fh = OGF::Util::fileHandle( $file );
	while( my $line = <$fh> ){
		chomp $line;
		next if $line =~ /^(#|\s*$)/;
		my( $type, @param ) = split /\|/, $line;
		my @optsP = grep {/=/}  @param;
		my @coord = grep {/^[-.\d]+$/} @param;
		@coord = map {$_ * $hOpt->{_zoom}} @coord if $hOpt->{_zoom};

		my %opts;
		foreach my $opt ( @optsP ){
			my( $key, $val ) = split /=/, $opt, 2;
			$opts{'-'.$key} = $val;
		}
#		print STDERR "\$type <", $type, ">  \@opts <", join('|',@opts), ">  \@coord <", join('|',@coord), ">\n";  # _DEBUG_
		if( $hOpt->{_tags} ){
			$hOpt->{_tags} = [ $hOpt->{_tags} ] if ! ref($hOpt->{_tags});
			$opts{'-tags'} = [] if ! $opts{'-tags'};
			push @{$opts{'-tags'}}, @{$hOpt->{_tags}};
		}
		my @opts = %opts;

		my $id = $cnv->create( $type, @coord, @opts );
		print STDERR "$type $id\n";
	}
	close $fh;
}






1;

