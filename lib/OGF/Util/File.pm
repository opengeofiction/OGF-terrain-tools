package OGF::Util::File;
use strict;
use File::Spec;
use File::Find;
use File::Copy;
use Exporter;
use OGF::Util qw( exception );
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( makeFilePath writeToFile readFromFile );

our $FSEP_REGEX = '[/\\\\]';


sub makeFilePath {
	my( $file ) = @_;
	if( $file =~ /^(.*)($FSEP_REGEX).*/ ){
		my( $dir, $fsep ) = ( $1, $2 );
		if( ! -d $dir ){
			my @dir = split /$FSEP_REGEX/, $dir, -1;
			foreach my $idx ( 0..$#dir ){
				my $d0 = join $fsep, @dir[0..$idx];
				mkdir $d0 if ! -d $d0;
			}
		}
	}
}


sub zipFileList {
    require Archive::Zip;
	my( $zipFile, $aFileList ) = @_;

    my $zip = Archive::Zip->new();
    foreach my $file ( @$aFileList ){
        (my $fname = $file) =~ s|^.*?/(\d+/)|$1|;
        print STDERR $file, " -> ", $fname, "\n";
        $zip->addFile( $file, $fname );
    }
    $zip->writeToFileNamed( $zipFile );
    print STDERR "Zip file: ", $zipFile, "\n";
}


sub writeToFile {
	my( $file, $text, $openOpt, $hOpt ) = @_;
#	print "writeToFile( $file, <$$text>, $openOpt )\n";  # _DEBUG_

	if( $hOpt->{-backup} && -e $file ){
		my( $backupFile, $backupPattern ) = ( $file, $hOpt->{-backup} );
		if( $backupPattern =~ /\%/ ){
			$backupPattern = timeFormat( $backupPattern, time() );
		}
		$backupFile .= $backupPattern;
		copy( $file, $backupFile	) or do {
			exception( qq{Cannot copy "$file" to "$backupFile": $!} );
			return;
		};
	}

	if( ! $openOpt ){
		my $defaultMode = $hOpt->{-bin} ? '>' : '>:encoding(UTF-8)';
		$openOpt = ($file =~ /^\s*\|/)? '' : $defaultMode;
	}
	makeFilePath( $file ) if $hOpt->{-mdir};

	local *FILE;
	my $ret;
	{   # extra brackets bc of "redo"
		$ret = open( FILE, $openOpt, $file );
		if( ! $ret ){
			if( $^O eq 'MSWin32' && $! eq 'Permission denied' ){
				if( handleWriteProtection($file) ){
					redo;
				}else{
					return 0;
				}
			}else{
				exception( qq/Cannot open "$file" for writing: $!/ );
				return $ret;
			}
		}
	}
	if( $hOpt->{-bin} ){
		$ret = binmode FILE;
		if( ! $ret ){
			exception( qq/Cannot set "$file" to binmode: $!/ );
			return $ret;
		}
	}

	if( ref($text) eq 'SCALAR' ){
		$text = $$text while ref($text) eq 'SCALAR';
	}
	if( ref($text) eq 'ARRAY' ){
		my $n = scalar( @$text );
		for( my $i = 0; $i < $n; ++ $i ){
			my $line = $text->[$i];
			$line .= "\n" unless $line =~ /\n$/;
			$ret = print FILE $line;
			last if ! $ret;
		}
	}else{
		$ret = print FILE $text;
	}

	if( ! $ret ){
		exception( qq/Error writing to "$file": $!/ );
		return $ret;
	}
	$ret = close FILE;
	if( ! $ret ){
		exception( qq/Error closing "$file": $!/ );
		return $ret;
	}
	return $ret;
}

sub readFromFile {
	my( $file, $opt1, $opt2 ) = @_;
	my $hOpt = {};

	my( $lineStart, $lineEnd, $matchingStart, %lineNrs );
	if( $opt1 && ref($opt1) ){
		$hOpt = $opt1;
		if( $hOpt->{-lines} ){
			( $lineStart, $lineEnd ) = @{$hOpt->{-lines}};
		}
		if( $hOpt->{-matchingStartBlock} ){
			$matchingStart =	$hOpt->{-matchingStartBlock};
			$lineStart = 1 if !defined $lineStart;
		}
		if( $hOpt->{-lineNrs} ){
			%lineNrs = map {$_ => []} @{$hOpt->{-lineNrs}};
		}
	}else{
		( $lineStart, $lineEnd ) = ( $opt1, $opt2 );
		$lineStart = 1 if !defined $lineStart;
	}
	my $openMode = $hOpt->{-bin} ? '<' : '<:encoding(UTF-8)';

	my $text = '';
    local *FILE;
    open( FILE, $openMode, $file ) or do {
        exception( qq/Cannot open "$file": $!"/ );
        return undef;
    };

	if( defined $lineStart ){
		$lineEnd = $lineStart+$1-1 if $lineEnd && $lineEnd =~ /^\+(\d+)$/;

		while( <FILE>	){
			last if $lineEnd && $. > $lineEnd;
			$text .= $_ if $. >= $lineStart;
			last if defined $matchingStart && $_ !~ /$matchingStart/;
		}
	}elsif( %lineNrs ){

		while( <FILE>	){
			$lineNrs{$.} = $_ if $lineNrs{$.};
		}
		$text = join( "", grep {!ref} map {$lineNrs{$_}} @{$hOpt->{-lineNrs}} );

	}elsif( $hOpt->{-fpos} ){
		my( $start, $end ) = @{$hOpt->{-fpos}};

		seek FILE, $start, 0;
		while( <FILE>	){
			$text .= $_;
			last if tell(FILE) >= $end;
		}
	}elsif( $hOpt->{-bin} ){
		local $/ = undef;

		my $ret = binmode FILE;
		if( ! $ret ){
			exception( qq/Cannot set "$file" to binmode: $!/ );
			return $ret;
		}
		$text = <FILE>;
	}else{
		exception( qq/readFromFile: Invalid options <$opt1> <$opt2>/ );
	}

	close FILE;
	return $text;
}




1;

