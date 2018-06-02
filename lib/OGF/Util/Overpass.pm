package OGF::Util::Overpass;
use strict;
use warnings;
use Exporter;
use LWP;
use OGF::Util;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw(
);


my $CMD_OSM3S_QUERY = '/opt/osm/osm3s/bin/osm3s_query';
my $CMD_OSMCONVERT  = 'osmconvert64';
my $URL_OVERPASS    = 'https://osm3s.opengeofiction.net/api/interpreter';



sub runQuery_local {
	my( $outFile, $queryText ) = @_;
	my $startTimeE = time();
	my( $osmFile, $pbfFile );
	if( $outFile =~ /\.pbf$/ ){
		($osmFile = $outFile) =~ s/\.pbf$//;
		$pbfFile = $outFile;
	}else{
		$osmFile = $outFile;
	}

	my @queries = ref($queryText) ? @$queryText : ($queryText);
    my @osmFiles;

    foreach my $query ( @queries ){
        push @osmFiles, $osmFile;
        my $cmd = qq|$CMD_OSM3S_QUERY > "$osmFile"|;
        print STDERR "CMD: $cmd\n";
        local *OSM3S_QUERY;
        open( OSM3S_QUERY, '|-', $cmd ) or die qq/Cannot open pipe "$cmd": $!\n/;
        print OSM3S_QUERY $query;
        close OSM3S_QUERY;
		$osmFile =~ s/\.osm/_1.osm/;
    }
	print STDERR 'Overpass export [1]: ', time() - $startTimeE, " seconds\n";

	if( $pbfFile ){
        my $osmFileList = join( ' ', map {"\"$_\""} @osmFiles );
        OGF::Util::runCommand( qq|$CMD_OSMCONVERT $osmFileList --out-pbf -o="$pbfFile"| );
        chmod 0644, $pbfFile; 
        print STDERR 'Overpass export [2]: ', time() - $startTimeE, " seconds\n";
        unlink @osmFiles;
	}
}

sub runQuery_remote {
	my( $outFile, $queryText ) = @_;
	my $startTimeE = time();

	my $userAgent = LWP::UserAgent->new(
		keep_alive => 20,
	);
	if( $outFile ){
        my( $ogfFile, $osmFile ) = ( $outFile );
        if( $outFile =~ /\.ogf$/ ){
            ($osmFile = $outFile) =~ s/\.ogf$/.osm/;
            $ogfFile = $outFile;
        }else{
            $osmFile = $outFile;
        }

        my $resp = $userAgent->post( $URL_OVERPASS, 'Content' => $queryText, ':content_file' => $osmFile );
        print STDERR 'Overpass export [1]: ', time() - $startTimeE, " seconds\n";
        
        if( $ogfFile ){
            my $ctx = OGF::Data::Context->new();
            $ctx->loadFromXml( $osmFile );
            $ctx->writeToXml( $ogfFile );
        }
	}else{
        my $resp = $userAgent->post( $URL_OVERPASS, 'Content' => $queryText );
        my $data = $resp->content();
        print STDERR 'Overpass export [1]: ', time() - $startTimeE, " seconds\n";
        return $data;
	}
}





1;

