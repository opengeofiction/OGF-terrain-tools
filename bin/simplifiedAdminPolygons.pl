#! /usr/bin/perl -w

use lib '/opt/opengeofiction/OGF-terrain-tools/lib';
use strict;
use warnings;
use JSON::XS;
use URI::Escape;
use Date::Format;
use OGF::Geo::Topology;
use OGF::Util::File;
use OGF::Util::Line;
use OGF::Data::Context;
use OGF::View::TileLayer;
use OGF::Util::Usage qw( usageInit usageError );

sub fileExport_Overpass($$$);
sub housekeeping($$);

my %opt;
usageInit( \%opt, qq/ h ogf ds=s od=s copyto=s /, << "*" );
[-ogf] [-ds <dataset>] [-od <output_directory>] [-copyto <publish_directory>]

-ogf    use ogfId as key
-ds     "Roantra", "test" or empty
-od     Location to output JSON files
-copyto Location to publish JSON files for wiki use
*

my( $osmFile ) = @ARGV;
usageError() if $opt{'h'};

my $OUTPUT_DIR = $opt{'od'} || '/tmp';
housekeeping $OUTPUT_DIR, time;
my( $aTerr, $COMPUTATION_ZOOM, $OUTFILE_NAME, $ADMIN_RELATION_QUERY );
our $URL_TERRITORIES = 'https://wiki.opengeofiction.net/index.php/OpenGeofiction:Territory_administration?action=raw';

if( ! $opt{'ds'} ){
    $aTerr = getTerritories();
    $COMPUTATION_ZOOM = 6;
    $OUTFILE_NAME = 'ogf_polygons';
	# query takes ~ 10s, returning ~ 50 MB; allow up to 60s, 80 MB
    $ADMIN_RELATION_QUERY = << '---EOF---';
[timeout:60][maxsize:80000000];
(
  (relation["boundary"="administrative"]["admin_level"="2"];
   relation["boundary"="administrative"]["admin_level"="3"]["ogf:id"~"^(UL08c|UL16)-[0-9]{2}$"];
   relation["boundary"="administrative"]["admin_level"="4"]["ogf:id"~"^(AR(045|047|060|120)|UL10|UL08c)-[0-9]{2}$"];
   relation["boundary"="timezone"]["timezone"];);
  >;
);
out;
---EOF---

}elsif( $opt{'ds'} eq 'test' ){
	$URL_TERRITORIES = 'https://wiki.opengeofiction.net/index.php/OpenGeofiction:Territory_administration/test?action=raw';
    $aTerr = getTerritories();
    $COMPUTATION_ZOOM = 6;
    $OUTFILE_NAME = 'test_polygons';
    $ADMIN_RELATION_QUERY = << '---EOF---';
[timeout:90][maxsize:80000000];
(
  (relation["boundary"="administrative"]["ogf:id"~"^AR120-0[1-9]$"];);
  >;
);
out;
---EOF---

}elsif( $opt{'ds'} eq 'Roantra' ){
    $aTerr = [];
    $COMPUTATION_ZOOM = 12;
    $OUTFILE_NAME = 'polygons';
    $ADMIN_RELATION_QUERY = << '---EOF---';
[timeout:90][maxsize:80000000];
(
  (relation["land_area"="administrative"]["ogf:area"~"^RO\\."];
   relation["boundary"="administrative"]["ogf:area"~"^RO\\."];);
  >;
);
out;
---EOF---

}else{
    die qq/Unknown dataset: "$opt{ds}"/;
}

# an .osm file can be specified as the last commandline argument, otherwise get from Overpass
if( ! $osmFile ){
	$osmFile = $OUTPUT_DIR . '/admin_polygons_'. time2str('%y%m%d_%H%M%S',time) .'.osm';
	fileExport_Overpass( $osmFile, $ADMIN_RELATION_QUERY, 10000000 ) if ! -f $osmFile;
}
exit if( ! -f $osmFile );

my $tl = OGF::View::TileLayer->new( "image:OGF:$COMPUTATION_ZOOM:all" );
my( $proj ) = $tl->{_proj};

my $ctx = OGF::Data::Context->new();
$ctx->loadFromFile( $osmFile );
$ctx->setReverseInfo();

our %VERIFY_IGNORE = (
# all know errors cleared, add issues using format:
#   481   => 'UL130',   # 
);

my $hSharedBorders = {};

foreach my $way ( values %{$ctx->{_Way}} ){
	my @rel = sort keys %{$ctx->{_rev_info}{$way->uid}};
	my $key = join( ':', @rel );
	
	my $num = scalar( @rel );
	if( !($num == 1 || $num == 2) ){
		print STDERR "\$key <", $key, ">\n";  # _DEBUG_
		warn qq/Error: way $way->{id} is element of $num relations\n/;
	}

	$hSharedBorders->{$key} = [] if ! $hSharedBorders->{$key};
	push @{$hSharedBorders->{$key}}, $way->{'id'};
}


#                        ( 50, 100, 200, 400, 800, 1600, 3200 ){
foreach my $avwThreshold ( 100 ){

    my $ctx3 = OGF::Data::Context->new();
    $ctx3->{_Node} = $ctx->{_Node};
    my $ct = 0;

    foreach my $key ( keys %$hSharedBorders ){
        my @relIds = map {substr($_,2)} split( /:/, $key );
        my $aSegments = $hSharedBorders->{$key};

        my $ctx2 = OGF::Data::Context->new( $proj );
        map {$ctx2->{_Way}{$_} = $ctx->{_Way}{$_}} @$aSegments;

        my $aConnected = OGF::Geo::Topology::buildWaySequence( $ctx2, undef, undef, {'copy' => 1} );
#    	  use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 4; print STDERR Data::Dumper->Dump( [$aConnected], ['aConnected'] ), "\n";  # _DEBUG_

        foreach my $way ( @$aConnected ){
#    		    my @points = map {[$_->{'lon'},$_->{'lat'}]} map {$ctx->{_Node}{$_}} @{$way->{'nodes'}};
            my @points = map {$proj->geo2cnv($_)} map {[$_->{'lon'},$_->{'lat'}]} map {$ctx->{_Node}{$_}} @{$way->{'nodes'}};
            print STDERR "way: ", $way->{'id'}, "  ogfId: ", ($way->{'tags'}{'ogf:id'} || ''), "  size: ", $#points, "\n";  # _DEBUG_
#    		    use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [\@points], ['*points'] ), "\n";  # _DEBUG_
            my $aIndex = OGF::Util::Line::algVisvalingamWhyatt( \@points, {'indexOnly' => 1, 'threshold' => $avwThreshold} );
            @{$way->{'nodes'}} = map {$way->{'nodes'}[$_]} @$aIndex;

            my $wayId = --$ct;
            $way->{'id'} = $wayId;
            $ctx3->{_Way}{$wayId} = $way;

            foreach my $relId ( @relIds ){
                addWayToRelation( $ctx3, $relId, $way );
            }
        }
    }

    my $hPolygons = {};
    foreach my $rel ( values %{$ctx3->{_Relation}} ){
        print STDERR "* rel ", $rel->{'id'}, " ", scalar(@{$rel->{'members'}}) ,"\n";  # _DEBUG_
        my $aRelOuter = $rel->closedWayComponents( 'outer' );
        my @polygon;
        foreach my $way ( @$aRelOuter ){
            print STDERR "  * way ", $way->{'id'}, "\n";  # _DEBUG_
            my $aRect = $way->boundingRectangle( $ctx3, $proj );
            my $rectArea = abs($aRect->[2] - $aRect->[0]) * abs($aRect->[3] - $aRect->[1]);
#           next if $rectArea < $avwThreshold;
#           my @points = map {[0+$_->{'lat'},0+$_->{'lon'}]} map {$ctx3->{_Node}{$_}} @{$way->{'nodes'}};
            my @points;
            foreach my $nodeId ( @{$way->{'nodes'}} ){
                my $node = $ctx3->{_Node}{$nodeId};
                if( ! $node ){
                    print STDERR "  invalid node $nodeId (possible Overpass problem)\n";
                    next;
                }
                push @points, [ 0+$node->{'lat'}, 0+$node->{'lon'} ];
            }
#    		    use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [\@points], ['*points'] ), "\n";  # _DEBUG_
            push @polygon, {_rectArea => $rectArea, _points => \@points};
        }

        # make sure the largest way is always preserved, however small
        @polygon = sort {$b->{_rectArea} <=> $a->{_rectArea}} @polygon;
        for( my $i = 1; $i <= $#polygon; ++$i ){
            $polygon[$i] = undef if $polygon[$i]->{_rectArea} < $avwThreshold;
        }
        @polygon = map {$_->{_points}} grep {defined} @polygon;
        @polygon = @{$polygon[0]} if scalar(@polygon) == 1;

		my $relKey = $rel->{'id'};
		if( $opt{'ogf'} ){
			$relKey = $ctx->{_Relation}{$relKey}{'tags'}{'ogf:id'};
		}
#		die qq/Unexpected error: no relation key (rel=$rel->{id})\n/ if ! $relKey;
		if( ! $relKey ){
			warn qq/Unexpected error: no relation key (rel=$rel->{id})\n/;
			next;
		}
        $hPolygons->{$relKey} = \@polygon;
    };

    if( $avwThreshold == 100 ){
		my $outFile = "$OUTPUT_DIR/${OUTFILE_NAME}_errors.json";
		my $exit = 0;
        my $aErrors = verifyTerritories( $hPolygons, $aTerr );
        if( @$aErrors ){
            use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$aErrors], ['aErrors'] ), "\n";  # _DEBUG_
			
			my $json = JSON::XS->new->indent(2)->space_after;
			my $text = $json->encode( \@$aErrors );
			OGF::Util::File::writeToFile( $outFile, $text, '>:encoding(UTF-8)' );
            $exit = 1;
        }
		else
		{
			my $text = '[]';
			OGF::Util::File::writeToFile( $outFile, $text, '>:encoding(UTF-8)' );
		}
		
		if( $opt{'copyto'} and -d $opt{'copyto'} ) {
			my $publishFile = $opt{'copyto'} . "/territory_errors.json";
			system "cp \"$outFile\" \"$publishFile\"";
		}
		
		exit if( $exit == 1 );
    }

    my $json = JSON::XS->new->indent(2)->space_after;
	my $outFile = "$OUTPUT_DIR/${OUTFILE_NAME}_${avwThreshold}.json";
    writePolygonJson( $outFile, $hPolygons );
	if( $opt{'copyto'} and -d $opt{'copyto'} ) {
		my $publishFile = $opt{'copyto'} . "/territory.json";
		system "cp \"$outFile\" \"$publishFile\"";
	}
}

#-------------------------------------------------------------------------------

sub verifyTerritories {
	my( $hPolygons, $aTerritories ) = @_;
	my @errors;
	foreach my $hTerr ( @$aTerritories )
	{
		my($ogfId, $relId) = ($hTerr->{'ogfId'}, $hTerr->{'rel'});
		my $errText = 'Missing polygon';

		unless( exists $hTerr->{'ogfId'}   and exists $hTerr->{'name'}  and exists $hTerr->{'rel'}
		    and exists $hTerr->{'status'}  and exists $hTerr->{'owner'} and exists $hTerr->{'deadline'}
		    and exists $hTerr->{'comment'} and exists $hTerr->{'constraints'} )
		{
			$errText = 'Territory JSON missing ogfId, name, rel, status, owner, deadline, comment, or constraints';
		}
		elsif( $hPolygons->{$relId} )
		{
			$errText = verifyPolygon( $hPolygons->{$relId} );
		}

		print STDERR $ogfId;
		if( $errText )
		{
			print STDERR " ", $errText;
			unless( $VERIFY_IGNORE{$relId} )
			{
				my $err = {_ogfId => $ogfId, _rel => $relId, _text => $errText};
				push @errors, $err;
			}
		}
		print STDERR "\n";
	}
	return \@errors;
}


sub verifyPolygon {
    my( $aPol ) = @_;
    my $errText = '';
    my $p0 = $aPol->[0][0];
    return 'Empty Polygon' if ! $p0;
    if( ref($p0) ){
        foreach my $aP ( @$aPol ){
            my $err2 = verifyPolygon( $aP );
            $errText .= $err2 . "\n" if $err2;
        }
    }else{
        my( $x0, $y0, $x1, $y1 ) = ( $aPol->[0][0], $aPol->[0][1], $aPol->[-1][0], $aPol->[-1][1] );
        #$errText = ($x0 == $x1 && $y0 == $y1)? '' : "Polygon not closed (gap between $x0,$y0 and $x1,$y1)";
        $errText = ($x0 == $x1 && $y0 == $y1)? '' : "Polygon not closed (gap between [https://opengeofiction.net/#map=16/$x0/$y0 A] and [https://opengeofiction.net/#map=16/$x1/$y1 B])";
    }
    return $errText;
}

sub addWayToRelation {
	my( $ctx3, $relId, $way ) = @_;
	if( ! $ctx3->{_Relation}{$relId} ){
		OGF::Data::Relation->new( $ctx3, {'id' => $relId} );
	}
	$ctx3->{_Relation}{$relId}->add_member( 'outer', $way );
}

sub fileExport_Overpass($$$)
{
	require OGF::Util::Overpass;
	my($outFile, $query, $minSize) = @_;
	my $data = OGF::Util::Overpass::runQuery_remoteRetry(undef, $query, $minSize);
	OGF::Util::File::writeToFile( $outFile, $data, '>:encoding(UTF-8)' ) if( defined $data );
}

sub getTerritories {
    require LWP;

    my $json = JSON::XS->new();
	my $userAgent = LWP::UserAgent->new(
		keep_alive => 20,
	);

	my $resp = $userAgent->get( $URL_TERRITORIES );
	my $x = $resp->content();
    my $aTerr = $json->decode( $resp->content() );
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 3; print STDERR Data::Dumper->Dump( [$aTerr], ['aTerr'] ), "\n";  # _DEBUG_

    return $aTerr;
}


sub writePolygonJson {
	my( $filePoly, $hPolygons ) = @_;
    local *OUTFILE;
    open( OUTFILE, '>:encoding(UTF-8)', $filePoly ) or die qq/Cannot open "$filePoly" for writing: $!\n/;
    my $jsonP = JSON::XS->new;
    print OUTFILE "{\n";
    my @keyList = sort keys %$hPolygons;
    my $ccP = lastLoop( \@keyList, ',', '' );
    foreach my $key ( @keyList ){
        if( ref($hPolygons->{$key}[0][0]) ){
            my $ccPP = lastLoop( $hPolygons->{$key}, ',', '' );
            print OUTFILE qq/"$key": [\n/;
            foreach my $aP ( @{$hPolygons->{$key}} ){
                print OUTFILE "  ", $jsonP->encode($aP), $ccPP->(), "\n";
            }
            print OUTFILE "]", $ccP->(), "\n";
        }else{
            print OUTFILE qq/"$key": /, $jsonP->encode($hPolygons->{$key}), $ccP->(), "\n";
        }
    }
    print OUTFILE "}\n";
    close OUTFILE;
}

sub lastLoop {
	my( $aList, $str, $strLast ) = @_;
	my $num = scalar( @$aList );
	my $cSub = sub {
		return --$num ? $str : $strLast;
	};
	return $cSub;
}


sub housekeeping($$)
{
	my($dir, $now) = @_;
	my $KEEP_FOR = 60 * 60 * 24 ; # 1 day
	my $dh;
	
	opendir $dh, $dir;
	while( my $file = readdir $dh )
	{
		next unless( $file =~ /^admin_polygons_\d{6}_\d{6}\.osm/ );
		if( $now - (stat "$dir/$file")[9] > $KEEP_FOR )
		{
			print "deleting: $dir/$file\n";
			unlink "$dir/$file";
		}
	}
	closedir $dh;
}


