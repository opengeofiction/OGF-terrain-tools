package OGF::Util::PPM;
use strict;
use warnings;
use Exporter;
use FileHandle;
use OGF::Util::TileLevel;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw(
);



sub new {
	my( $pkg, $fileOrInfo, $hOpt ) = @_;

	my $self = {};	
	bless $self, $pkg;

	if( ref($fileOrInfo) ){
		$self->{'type'}     = $fileOrInfo->{'type'}     || 'P6';
		$self->{'maxColor'} = $fileOrInfo->{'maxColor'} || 255;
		my $wd = $self->{'width'}  = $fileOrInfo->{'width'};
		my $hg = $self->{'height'} = $fileOrInfo->{'height'};
		my $color = (defined $fileOrInfo->{'color'})? $fileOrInfo->{'color'} : [0,0,0];
		$self->{'data'} = [];
		for( my $y = 0; $y < $hg; ++$y ){
			push @{$self->{'data'}}, [($color) x $wd];		
		}
	}else{
		my $fh = $self->parseHeader( $fileOrInfo );
		if( $hOpt && $hOpt->{-loadData} ){
			$self->loadData( $fh );
			$fh->close();
		}else{
			$self->{'data'} = [];
			$self->{'fh'} = $fh;
			$self->{'startPos'} = $fh->tell();
			if( $hOpt && $hOpt->{-loadManager} ){
				$self->{'lineAcc'} = {};
			}
		}
	}

	return $self;
}

sub parseHeader {
	my( $self, $file ) = @_;
	print STDERR "parseHeader( $file )\n";  # _DEBUG_
#	local *FILE;  # return doesn't work in this case
	my $fh = FileHandle->new( $file, 'r' ) or die qq/Cannot open "$file": $!\n/;
	$fh->binmode();

	my $type = readNonCommentLine( $fh );
#	die qq/Unsupported type "$type"/ unless $type eq 'P6';
	die qq/Unsupported type "$type"/ unless $type eq 'P6' || $type eq 'P5';  # roa45.ppm = P5, warum ???
	my $size = readNonCommentLine( $fh );
	my( $wd, $hg ) = split /\s+/, $size;
	my $maxColor = readNonCommentLine( $fh );

	$self->{'type'}     = $type;
	$self->{'width'}    = $wd;
	$self->{'height'}   = $hg;
	$self->{'maxColor'} = $maxColor;

	return $fh;
}

sub readNonCommentLine {
	my( $fh ) = @_;
	my $line;
	do{  $line = <$fh>;  } until $line !~ /^#/;
	$line =~ s/\s*\n$//;
	return $line;
}

sub loadData {
	my( $self, $fh ) = @_;
#	print STDERR "\$self <", $self, ">  \$fh <", $fh, ">\n";  # _DEBUG_
	# TODO: cannot handle comment after maxColor
	my( $wd, $hg ) = ( $self->{'width'}, $self->{'height'} );

#	$fh->input_record_separator(undef);
	local $/ = undef;
	my $dataStr = <$fh>;
#	print STDERR "\$dataStr <", length($dataStr), ">\n"; exit;  # _DEBUG_

	$self->{'data'} = [];

	if( $self->{'type'} eq 'P6' && $self->{'maxColor'} == 255 ){
        my $rowSize = 3 * $wd;
        for( my $y = 0; $y < $hg; ++$y ){
            my $rowStr = substr( $dataStr, $y * $rowSize, $rowSize );
            push @{$self->{'data'}}, pixelLine( $rowStr );
        }
	}elsif( $self->{'type'} eq 'P5' && $self->{'maxColor'} == 65535 ){
        my $rowSize = 2 * $wd;
        for( my $y = 0; $y < $hg; ++$y ){
            my $rowStr = substr( $dataStr, $y * $rowSize, $rowSize );
            push @{$self->{'data'}}, [ unpack( 'n*', $rowStr ) ];
        }
	}else{
		die qq|Cannot load image data: invalid type/maxColor combination: $self->{type}/$self->{maxColor}|;
	}
}

sub pixelLine {
	my( $str, $y ) = @_;
	my @val = unpack( 'C*', $str );
	my $len = scalar( @val );
	my @pixels;
	for( my $x = 0; $x < $len; $x += 3 ){
		push @pixels, [ $val[$x], $val[$x+1], $val[$x+2] ];
#		print STDERR "\$x/3 <", ($x/3), ">  \$val[\$x] <", $val[$x], ">  \$val[\$x+1] <", $val[$x+1], ">  \$val[\$x+2] <", $val[$x+2], ">\n" if defined $y && $y == 10665;  # _DEBUG_
	}
	return \@pixels;
}


sub writeToFile {
	my( $self, $file ) = @_;

	local *OUTFILE;
	open( OUTFILE, '>', $file ) or die qq/Cannot open "$file" for writing: $!\n/;
	binmode OUTFILE;
	print OUTFILE qq/$self->{type}\n$self->{width} $self->{height}\n$self->{maxColor}\n/;

	if( $self->{'type'} eq 'P6' && $self->{'maxColor'} == 255 ){
        foreach my $aLine ( @{$self->{'data'}} ){
            my @line = map {@$_} @$aLine;
            print OUTFILE pack( 'C*', @line );
        }
	}elsif( $self->{'type'} eq 'P5' && $self->{'maxColor'} == 65535 ){
        foreach my $aLine ( @{$self->{'data'}} ){
            print OUTFILE pack( 'n*', @$aLine );
        }
	}else{
		die qq|Cannot write image data: invalid type/maxColor combination: $self->{type}/$self->{maxColor}|;
		close OUTFILE;
	}
	close OUTFILE;
}

sub unloadUnusedLines {
	my( $self, $opt ) = @_;
	$opt = '' if ! $opt;
	my( $hg, $aData ) = ( $self->{'height'}, $self->{'data'} );
	for( my $y = 0; $y < $hg; ++$y ){
		if( $self->{'data'}[$y] && ($opt eq 'all' || ! $self->{'lineAcc'}{$y}) ){
			$self->{'data'}[$y] = undef;
		}
	}
	$self->{'lineAcc'} = undef;
}

sub getPixel {
	my( $self, $x, $y ) = @_;
#	print STDERR "\$self->{'data'}[$y][$x] <", $self->{'data'}[$y][$x], ">\n";  # _DEBUG_
	my $aColor;
	if(	! $self->{'data'}[$y] ){
		my $fh = $self->{'fh'};
		die qq/PPM: Invalid file handle\n/ if ! $fh;
		my( $rowSize, $rowStr ) = 3 * $self->{'width'};
		$fh->seek( $self->{'startPos'} + $y * $rowSize, 0 );
		$fh->read( $rowStr, $rowSize );
#		print STDERR "[$y] \$rowSize <", $rowSize, ">  \$rowStr <", length($rowStr), ">\n";  # _DEBUG_
		$self->{'data'}[$y] = pixelLine( $rowStr, $y );	
	}
	$self->{'lineAcc'}{$y} = 1 if $self->{'lineAcc'};
	$aColor = $self->{'data'}[$y][$x];
	return $aColor;
}

sub setPixel {
	my( $self, $x, $y, $aColor ) = @_;
	if( ! $self->{'data'}[$y] ){
		die qq/PPM: Cannot write to read only PPM\n/;
	}
	$self->{'data'}[$y][$x] = $aColor;
}

sub convertColors {
	my( $self, $hConv ) = @_;
	my( $wd, $hg, $aData ) = ( $self->{'width'}, $self->{'height'}, $self->{'data'} );
	my $aV = $hConv->{_conv}{'mult_value'};
	my $aR = $hConv->{_conv}{'mult_red'};
	my $aG = $hConv->{_conv}{'mult_green'};
	my $aB = $hConv->{_conv}{'mult_blue'};

	for( my $y = 0; $y < $hg; ++$y ){
		for( my $x = 0; $x < $wd; ++$x ){
			my $aPixel = $aData->[$y][$x];
#			print STDERR "R <", $aPixel->[0], ">  G <", $aPixel->[1], ">  B <", $aPixel->[2], ">\n";  # _DEBUG_
			my( $R, $G, $B, $R0, $G0, $B0 ) = ( @$aPixel, @$aPixel );

			$R *= $aR->[$R0];
			$G *= $aG->[$G0];
			$B *= $aB->[$B0];

			$R *= $aV->[$R0];
			$G *= $aV->[$G0];
			$B *= $aV->[$B0];

			$R = int($R);
			$G = int($G);
			$B = int($B);

			$R = 255 if $R > 255;
			$G = 255 if $G > 255;
			$B = 255 if $B > 255;

			$aData->[$y][$x] = [ $R, $G, $B ]; 
		}
	}
}

sub imageSize {
	my( $self, $file ) = @_;
	if( defined $file ){
		$self = OGF::Util::PPM->new( $file );
		$self->{'fh'}->close();
	}
	return [ $self->{'width'}, $self->{'height'} ];
}





1;

