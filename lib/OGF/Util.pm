package OGF::Util;
use strict;
use warnings;
use Date::Format;
use File::Copy;
use UTAN::Util qw( splitDelimited errorDialog );
use OGF::Const;
use Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw(
);


our %OBJECT_TYPE_MAP = (
	'N'        => 'Node',
	'W'        => 'Way',
	'R'        => 'Relation',
	'Node'     => 'Node',
	'Way'      => 'Way',
	'Relation' => 'Relation',
);
our %OSM_API_ACTION_MAP = ( 'c' => 'create', 'u' => 'update', 'd' => 'delete' );

our %ABBREV_KEY = (
	'admin_level' => 'al',
	'boundary'  => 'bd',
	'bridge'    => 'br',
	'electrified' => 'elc',
	'gauge'     => 'gg',
	'highway'   => 'hw',
	'layer'     => 'l',
	'land_area' => 'la',
	'landuse'   => 'lu',
	'license_plate_code' => 'lpc',
	'maxspeed'  => 'msp',
	'name'      => 'n',
	'natural'   => 'nt',
	'oneway'    => 'ow',
	'place'     => 'pl',
	'population'  => 'pp',
	'postal_code' => 'pc',
	'railway'   => 'rw',
	'tunnel'    => 'tu',
	'type'      => 't',
	'waterway'  => 'ww',
	'wood'      => 'wd',
);
our %ABBREV_VAL = (
	'administrative' => 'adm',
	'boundary'     => 'bnd',
	'coastline'    => 'coa',
	'contact_line' => 'ctl',
	'forest'       => 'for',
	'hamlet'       => 'ham',
	'industrial'   => 'ind',
	'locality'     => 'loc',
	'mixed'        => 'mix',
	'motorway'     => 'hm',
	'multipolygon' => 'mp',
	'residential'  => 'res',
	'river'        => 'riv',
	'riverbank'    => 'rib',
	'suburb'       => 'sub',
	'village'      => 'vil',
	'water'        => 'wtr',

	'primary'      => 'h1',
	'secondary'    => 'h2',
	'tertiary'     => 'h3',
	'unclassified' => 'hu',
	'yes'          => 'y',
	'no'           => 'n',
);
our %ABBREV_KEY_R = reverse %ABBREV_KEY;
our %ABBREV_VAL_R = reverse %ABBREV_VAL;



sub tagText {
	my( $hTags ) = @_;
	my $str = '';
	foreach my $key ( sort keys %$hTags ){
		my $val = $hTags->{$key};
		$key = $ABBREV_KEY{$key} if $ABBREV_KEY{$key};
		$val = $ABBREV_VAL{$val} if $ABBREV_VAL{$val};
		$str .= '|'. $key .'='. $val;
	}
	return $str;
}

sub tagParse {
	my( $hTags, $str ) = @_;
	my( $key, $val ) = split /=/, $str, 2;
	$key = $ABBREV_KEY_R{$key} if $ABBREV_KEY_R{$key};
	$val = $ABBREV_VAL_R{$val} if $ABBREV_VAL_R{$val};
	$hTags->{$key} = $val;
}

sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }

sub multiLineBreak {
	my( $line, $maxw ) = @_;
	$maxw = $OGF::DATA_FORMAT_MAXWIDTH if ! $maxw;
	return $line if length($line) <= $maxw;

	my( $i, $lhead, @lines ) = ( 0 );
	while( $line && length($line) > $maxw ){
		$lines[$i] = substr( $line, 0, $maxw );
		$line = substr( $line, $maxw );
		( $lhead, $line ) = split /\|/, $line, 2;
		if( $line ){
			$lines[$i] .= $lhead . " \\";
			$line = " |" . $line;
		}else{
			$lines[$i] .= $lhead;
		}
		++$i;
	}
	$lines[$i] = $line if $line;
	return join( "\n", @lines );
}

sub multiLineRead {
	my $fh = shift;

	my $line = <$fh>;
	return undef if !defined $line;
	chomp $line;
	while( $line =~ s/\s+\\$// ){
		my $nextLine = <$fh>;
		chomp $nextLine;
		$nextLine =~ s/^\s*//;
		$line .= $nextLine;
	}
	return $line;
}

sub fileTag {
	my( $file ) = @_;
	$file =~ s|.*[\/\\]||;
	$file =~ s|\.\w+$||;
	return $file;
}

sub fileHandle {
	my( $file, $openOpt ) = @_;
	$openOpt = '<' if ! $openOpt;
	my $fh;

	if( ref($file) eq 'SCALAR' ){
		require IO::Scalar;
		$fh = IO::Scalar->new( $file );
	}elsif( $file =~ /\.gz$/ ){
		die qq/OGF::Util::fileHandle: open opt > not supported for .gz files\n/ if $openOpt eq '>';
		require IO::Uncompress::Gunzip;
		$fh = IO::Uncompress::Gunzip->new( $file );
	}elsif( $file eq '-' ){
		require FileHandle;
		$openOpt =~ s/:.*//;
		$fh = FileHandle->new( $openOpt . '-' );
	}else{
		require FileHandle;
		$fh = FileHandle->new( $file, $openOpt );
	}
	die qq/OGF::Util::fileHandle: Cannot open $openOpt "$file": $!\n/ if ! $fh;

	return $fh;
}

sub fileBackup {
	my( $file, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my $dtime = time2str( '%Y%m%d-%H%M%S', time() );
	(my $backupDir  = $file) =~ s|[^\\\/]+$|backup|;
	(my $backupFile = $file) =~ s|([^\\\/]+?)(\.\w+)?$|backup/$1-$dtime$2|;
	my $rv;
	if( ! -d $backupDir ){
		$rv = mkdir $backupDir;
        if( ! $rv ){
            errorDialog( qq/Cannot create backup directory\n$backupDir\n$!/ );
            return;
        }
	}
	if( $hOpt->{'move'} ){
		$rv = move( $file, $backupFile );
	}else{
		$rv = copy( $file, $backupFile );
	}
	if( ! $rv ){
		errorDialog( qq/Error creating backup file\n$backupFile\n$!/ );
		return;
	}
}

sub fileTemp {
	my( $file, $suffix ) = @_;
	my $dtime   = time2str( '%Y%m%d-%H%M%S', time() );
	my $tmpFile = $file;
	$file =~ s|.*[\\/]||;
	$file =~ s/(\.|$)/-$dtime$1/;
	$file .= ".$suffix" if defined $suffix;
	$file = $OGF::TASKSERVICE_DIR . '/tmp/' . $file;
	return $file;
}

sub convertOsmosis {
	my( $fileIn, $fileOut, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	$fileOut = OGF::Util::fileTemp( $fileIn, 'osm' ) if ! $fileOut;

    my $OSMOSIS_EXE = 'C:\Program_Files_01\Geography\osmosis-latest\bin\osmosis.bat';
    my %BBOX = (
#       'Roantra'   => [ 'OGF', 'bbox=26.25,43.34,31.34,46.91' ],
        'Roantra'   => [ 'OGF', 'bbox=25.97,43.14,31.34,47.10' ],
        'Sathria'   => [ 'OGF', 'bbox=29.80,29.47,56.61,49.49' ],
        'Sathria_E' => [ 'OGF', 'bbox=26.95,26.20,47,61.12,50.26' ],
        'KaSaBo'    => [ 'OGF', 'bbox=-16.49,45.6,-1.87,52.89' ],
        'Archanta'  => [ 'OGF', 'bbox=60,-60,130,34' ],
        'R_S'       => [ 'OGF', 'bbox=25.97,29.47,56.61,49.49' ],
        'Khaiwoon'  => [ 'OGF', 'bbox=89.10,18.31,90.93,18.85' ],
    );

	my $cmd = $OSMOSIS_EXE;
	$cmd .= ($fileIn =~ /\.pbf$/i)? qq| --read-pbf file="$fileIn"| : qq| --read-xml-0.6 file="$fileIn"|;
	if( $hOpt->{'bbox'} ){
		my $bbox = $BBOX{$hOpt->{'bbox'}}[1];
		die qq/Unknown bbox definition: "$hOpt->{bbox}"/ if ! $bbox;
		$bbox =~ s/^bbox=//;
		my( $minLon, $minLat, $maxLon, $maxLat ) = split /,/, $bbox;
		$cmd .= qq| --bounding-box left=$minLon bottom=$minLat right=$maxLon top=$maxLat completeWays=yes|;
	}
	my %outfileInfo;
	if( $hOpt->{'typeSplit'} ){
		(my $fileOut_R = $fileOut) =~ s/\.(\w+)$/.Relation.$1/;
		(my $fileOut_W = $fileOut) =~ s/\.(\w+)$/.Way.$1/;
		(my $fileOut_N = $fileOut) =~ s/\.(\w+)$/.Node.$1/;
		$cmd .= ' --tee 3'
            . qq| --tf reject-ways      --tf reject-nodes --write-xml file="$fileOut_R"|
            . qq| --tf reject-relations --tf reject-nodes --write-xml file="$fileOut_W"|
            . qq| --tf reject-relations --tf reject-ways  --write-xml file="$fileOut_N"|;
		%outfileInfo = ('Relation' => $fileOut_R, 'Way' => $fileOut_W, 'Node' => $fileOut_N);
	}else{
		$cmd .= qq| --write-xml file="$fileOut"|;
		%outfileInfo = ('Relation' => $fileOut, 'Way' => $fileOut, 'Node' => $fileOut);
	}

	print STDERR "CMD: ", $cmd, "\n";
	system $cmd;

	return \%outfileInfo;
}

sub extractValidLines {
	my( $file ) = @_;
	my $fh = fileHandle( $file );
	my @lines = grep {!/^(#|\s*$)/} <$fh>;
	$fh->close();
	map {chomp} @lines;
	return @lines;
}

sub extractFileBlocks {
	my( $file ) = @_;
	my %blocks = ( _default => '' );
	my $current = '_default';
	my $fh = fileHandle( $file );
	while( <$fh> ){
		if( /^---\s+(\w+)\s+---/ ){
			$current = $1;
			$blocks{$current} = '';
		}else{
			$blocks{$current} .= $_;
		}
	}
	$fh->close();
	return \%blocks;
}


#-------------------------------------------------------------------------------

sub parseConfig {
	my( $file, $hDsc ) = @_;
	print STDERR "parseConfig( $file )\n";  # _DEBUG_
#	print "parseConf(", join('|',%$fileObj), ")\n";  # _DEBUG_
#	if( ! ref($fileObj) ){
#		$fileObj = UTAN::UniTree::FileSystem::File::handleNonrefFile( $self, $self->{_UTAN_component}, $fileObj );
#	}

	my @cmds;
	my $perlBlock = undef;

	my $fh = fileHandle( $file );
	while( <$fh> ){
		if( $perlBlock ){
			if( /^\s*\}/ ){
				$perlBlock = undef;
			}else{
				$perlBlock->[1] .= $_;
			}
			next;
		}

		chomp;
		next if /^#/;
		next if /^\s*$/;
		s/^\s*//;
		my( $cmd, @param ) = splitDelimited( $_ );
#		print STDERR "\$cmd <", $cmd, ">  \@param <", join('|',@param), ">\n";  # _DEBUG_
		if( $cmd eq '{' ){
			$perlBlock = [ 'perlExec', '' ];
			push @cmds, $perlBlock;
		}else{
			push @cmds, [ $cmd, @param ];
			if( $hDsc->{$cmd} ){
				processParserInfo( $hDsc->{$cmd}, $cmd, \@param );
			}elsif( $hDsc->{'_'.$cmd} ){
				processParserInfo( $hDsc->{'_'.$cmd}, '_'.$cmd, \@param );
			}
		}
	}
	$fh->close();

	my $hInit = {
		_file   => $file,
		_cmds   => \@cmds,
	};

	return $hInit;
}

sub processParserInfo {
	my( $rProc, $cmd, $aParam ) = @_;
	my( $hRef, @dsc ) = @$rProc;

	for( my $i = 0; $i < $#dsc; $i+=2 ){
		my( $key, $val ) = ( $dsc[$i], $dsc[$i+1] );
		$val = parserParam( $val, $cmd, $aParam );
		my @path = ref($key) ? @$key : ($key);
		my $ppL = pop @path;
		foreach my $pp ( @path ){
			$pp = parserParam( $pp, $cmd, $aParam );
			$hRef->{$pp} = {} if ! exists $hRef->{$pp};
			$hRef = $hRef->{$pp};
		}
		$ppL = parserParam( $ppL, $cmd, $aParam );
		$hRef->{$ppL} = $val;
	}
}

sub parserParam {
	my( $vdsc, $cmd, $aParam ) = @_;
	my $val;
	$vdsc =~ /^(c|p|P)([-\d]+)?(,)?/;
	my( $base, $idx, $splt ) = ( $1, $2, $3 );

	if( $base eq 'c' ){
		$val = $cmd;
	}elsif( $base eq 'P' ){
		$val = join ' ', @$aParam;
	}elsif( $base eq 'p' ){
		$val = $aParam;
	}else{
		die qq/OGF::Util::parserParam: Invalid base specifier '$base'\n/;
	}

	if( defined $idx ){
		if( $idx =~ /^(\d+)-(\d+)$/ ){
			$val = [ map {$val->[$_]} ($1..$2) ];
		}else{
			$val = $val->[$idx];
		}
	}

	$val = (ref($val) ? [map {[split /,/, $_]} @$val] : [split /,/, $val]) if $splt;
	return $val;
}

#-------------------------------------------------------------------------------

sub treeOverlay {
	my( $hDst, $hSrc ) = @_;
	foreach my $key ( keys %$hSrc ){
		if( exists($hDst->{$key}) && ref($hDst->{$key}) ){
			treeOverlay( $hDst->{$key}, $hSrc->{$key} );
		}else{
			$hDst->{$key} = $hSrc->{$key};
		}
	}
}


#-------------------------------------------------------------------------------

sub colorRgb {
	my( $color ) = @_;
	my( $r, $g, $b );
	if( ref($color) eq 'ARRAY' ){
		( $r, $g, $b ) = @$color;
	}elsif( $color =~ /^#?([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})/ ){
		( $r, $g, $b ) = eval "( 0x$1, 0x$2, 0x$3 )";
	}elsif( $color eq 'black' ){
		( $r, $g, $b ) = ( 0, 0, 0 );
	}
	return ( $r, $g, $b );
}

sub colorHex {
	my( $r, $g, $b ) = @_;
	my $color;
	if( ref($r) eq 'ARRAY' ){
		( $r, $g, $b ) = @$r;
		$color = sprintf('#%02X%02X%02X',$r,$g,$b);
	}elsif( defined $b ){
		$color = sprintf('#%02X%02X%02X',$r,$g,$b);
	}elsif( $r =~ /^#/ ){
		$color = $r;
	}
	return $color;
}





#-------------------------------------------------------------------------------


our $CMD_ERROR_HANDLER = undef;


sub runCommand {
	my( $cmd, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	$hOpt = {'tag' => $hOpt} if ! ref($hOpt);
	my $tag = $hOpt->{'tag'} || '';
	print STDERR $tag, " " if $tag;
	print STDERR "CMD: $cmd\n";
	my $start = time();
	my $rv = system $cmd;
	if( $rv != 0 && ! $hOpt->{'ignore_errors'} ){
		if( $CMD_ERROR_HANDLER ){
			$CMD_ERROR_HANDLER->( 'OGF::Util::Command', $cmd ."\n----------\n". $! );
		}
		die qq/ERROR: $!\n/;
	}
	my $duration = time - $start;
	print STDERR "duration ($tag): ", $duration, " sec\n" if $duration > 1;
}



sub stackTrace {
	my( $num, @clr ) = ( 1 );
	my $str = "";
	while( 1 ){
		@clr = caller( $num );
		last if ! @clr;
		$str .= sprintf( "  subroutine %s at %s line %d.\n", $clr[3], $clr[1], $clr[2] );  # subroutine, filename, line
		++$num;
	}
	return $str;
}

sub printStackTrace {
	print STDERR stackTrace(), "\n";
}




1;

