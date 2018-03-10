package OGF::Util::Line;
use strict;
use warnings;
use OGF::Geo::Geometry;
use OGF::Data::Context;


sub finalizeLine {
	my( $cnv, $lineId, $hTags, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my $aPoints = linePoints( $cnv, $lineId );
	if( $#{$aPoints} < 1 || $#{$aPoints} == 1 && OGF::Geo::Geometry::dist($aPoints->[0],$aPoints->[1]) == 0 ){
		$cnv->delete( $lineId );
		return undef;
	}
#	$aPoints = algVisvalingamWhyatt( $aPoints, {'threshold' => 5, 'fitSegments' => 1} );
#	$cnv->ogfLinePoints( $lineId, $aPoints );

#	$aPoints = convertLine( $cnv, $lineId, [\&algVisvalingamWhyatt, {'threshold' => 5, 'fitSegments' => 1}] );
#	$aPoints = convertLine( $cnv, $lineId, [\&algVisvalingamWhyatt, {'threshold' => 5, 'randomDisplace' => 1}] );

	( $lineId, $aPoints, my @lines ) = lineConnect( $cnv, $lineId, $hTags, $aPoints, $hOpt );
	return wantarray ? ( $lineId, $aPoints, @lines ) : $lineId;
}

sub lineConnect {
	my( $cnv, $lineId, $hTags, $aPoints, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	$aPoints = linePoints( $cnv, $lineId ) if ! $aPoints;

	my @isctInfo = findIntersectLines( $cnv, $lineId, $hTags, $aPoints );
#	use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [\@isctInfo], ['*isctInfo'] ), "\n";  # _DEBUG_
#	my $aRules = intersectionRules( $cnv, $lineId );
	my @lines;
	if( $hOpt->{'cut'} ){
        ( $lineId, $aPoints, @lines ) = applyCut( $cnv, $lineId, $aPoints, \@isctInfo, $hOpt->{'cut'} ) if @isctInfo;
	}else{
	    my $aRules;
	    if( $hOpt->{'no_close'} ){
            $aRules = [
                [ 'extend_end' ],    # OK
                [ 'extend_start' ],  # OK
                [ 'connect' ],       # OK
                [ 'improve' ],       # OK (sporadic errors)
            ];
	    }else{
            $aRules = [
                [ 'close_self' ],    # OK
                [ 'close_other' ],   # OK
                [ 'extend_end' ],    # OK
                [ 'extend_start' ],  # OK
                [ 'connect' ],       # OK
                [ 'improve' ],       # OK (sporadic errors)
            ];
        }
        ( $lineId, $aPoints, @lines ) = applyIntersection( $cnv, $lineId, $aPoints, \@isctInfo, $aRules ) if @isctInfo;
	}
	return ( $lineId, $aPoints, @lines );
}

sub convertLine {
	my( $cnv, $lineId, @conv ) = @_;
	my $aPoints = linePoints( $cnv, $lineId );
	foreach my $rConv ( @conv ){
		my( $cSub, @args ) = (ref($rConv) eq 'ARRAY')? @$rConv : ($rConv);
		$cSub = \&$cSub if ! ref($cSub);
		$aPoints = $cSub->( $aPoints, @args );
	}
	linePoints( $cnv, $lineId, $aPoints );
	return $aPoints;
}



sub printLineInfo {
	my( $title, $cnv, $aLineIds ) = @_;
	my $str = "----- $title -----\n";
	foreach my $lineId ( @$aLineIds ){
		my $way;
		if( $cnv->UNIVERSAL::can('ogfWayObject') ){
			$way = $cnv->ogfWayObject( $lineId );
		}
		if( $way ){
			my $hTags = $way->{'tags'} || {};
			$str .= $lineId .' '. $way->{'id'} .' ('. join('|',%$hTags) .")\n";
		}else{
			$str .= $lineId ." ---\n";
		}
	}
	return $str;
}

sub printIntersectInfo {
	my( $aIntersectInfo ) = @_;
	my $str = '';
#	use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [$aIntersectInfo], ['*isctInfo'] ), "\n";  # _DEBUG_
	if( ref($aIntersectInfo->[0]) ){
        my $ct = 0;
        foreach my $ptInfo ( @$aIntersectInfo ){
            $str .= ''. ($ct++) .' ['. $ptInfo->[0][0] .','. $ptInfo->[0][1] .'] '. $ptInfo->[1] .' '. $ptInfo->[2] ."\n";
        }
	}else{
        foreach my $aInfo ( @$aIntersectInfo ){
            my( $cnvId, $isct, $aOther ) = @$aInfo;
            $str .= "isct --- $cnvId\n";
            $str .= printIntersectInfo( $isct );
		}
	}
	return $str;
}

sub printPoints {
	my( $aPoints ) = @_;
	my $str = join( '', map {'['. join(',',@$_) .']'} @$aPoints ) . "---\n";
	return $str;
}


sub findIntersectLines {
	my( $cnv, $lineId, $hTags, $aPoints ) = @_;
	print STDERR "findIntersectLines: ", $lineId, "  tags = <", ($hTags ? join('|',%$hTags) : 'undef'), ">\n";  # _DEBUG_

	my @ovlp = overlapObjects( $cnv, $lineId );
	@ovlp = grep {$cnv->type($_) eq 'line'} @ovlp;
	print STDERR printLineInfo( 'A', $cnv, \@ovlp );  # _DEBUG_
#	@ovlp = grep {$cnv->type($_) eq 'line' && $_ != $lineId && OGF::Data::Context::tagMatch($cnv->ogfWayObject($_),$lineObj->{'tags'})} @ovlp;  # way object for current line doesn't yet exist 
	if( $hTags ){
		my $hMatch = convertMatchTags( $hTags );
		# first remove $lineId, bc tags are unknown at this time, and ogfWayObject also doesn't work yet, then add it afterwards
		@ovlp = grep {$_ != $lineId && OGF::Data::Context::tagMatch($cnv->ogfWayObject($_),$hMatch)} @ovlp;
		unshift @ovlp, $lineId;
		print STDERR printLineInfo( 'B', $cnv, \@ovlp );  # _DEBUG_
	}
	
	my @isctInfo;
	foreach my $cnvId ( @ovlp ){	
		my $aOther = ($cnvId == $lineId)? $aPoints : linePoints($cnv,$cnvId);
		my @isct = OGF::Geo::Geometry::array_intersect( $aOther, $aPoints );
		push @isctInfo, [ $cnvId, \@isct, $aOther ] if @isct;
	}

#	use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [\@isctInfo], ['*isctInfo'] ), "\n";  # _DEBUG_
#	print STDERR printIntersectInfo(\@isctInfo);
	return @isctInfo;
}

sub convertMatchTags {
	my( $hTags ) = @_;
	my %match = %$hTags;
	foreach my $tag ( keys %match ){
		if( $tag =~ /^(highway|railway)$/ ){
			$match{$tag} = '*';
		}elsif( $tag eq 'waterway' ){
			if( $match{$tag} =~ /^(river|stream)$/ ){
				$match{$tag} = [ 'river', 'stream' ];
			}else{
				# do nothing
			}
		}elsif( $tag =~ /^(natural|landuse|boundary|ele)$/ || $tag =~ /^ogf:/ ){
			# do nothing
		}else{
			delete $match{$tag}
		}
	}
	return \%match;
}

sub applyIntersection {
 	my( $cnv, $lineId, $aNew, $aIsctInfo, $aRules, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my( $otherId, $isct, $aOther ) = @{$aIsctInfo->[0]};
	print STDERR "A \$lineId <", $lineId, ">  \$otherId <", $otherId, ">\n";  # _DEBUG_
	my( $retId, $aPoints, $isctPt ) = ( $otherId );
# 	my @err;

	my @sort2 = sort {$a->[2] <=> $b->[2] || $a->[1] <=> $b->[1]} @$isct;
	my $isctS = [ $isct, \@sort2 ];

	{
        no strict 'refs';
        foreach my $aRule ( @$aRules ){
            my( $func, @args ) = @$aRule;
#           print STDERR "\$func <", $func, ">  \@args <", join('|',@args), ">\n";  # _DEBUG_
            my( $funcMatch, $funcApply ) = ( 'match_'.$func, 'isct_'.$func );

            my $mtc = &$funcMatch( $isctS, $aOther, $aNew );
            next if ! $mtc;
			print STDERR "applyIntersection: $func\n";
#			print STDERR 'A ', printIntersectInfo($isctS->[0]);
	        $aNew = isct_reverse( $isctS, $aNew, 2 ) if $mtc < 0;
#			print STDERR 'B ', printIntersectInfo($isctS->[0]);

            ( $aPoints, $isctPt ) = &$funcApply( $isctS, $aOther, $aNew );
			$retId   = $lineId if $func eq 'connect';
			$otherId = undef   if $func eq 'close_self';
			last;
        }
	}

	my @ret;
	if( $aPoints ){
		my $drawId = $hOpt->{'retain'} ? {-fill => '#00FF00'} : $retId;
		linePoints( $cnv, $drawId, $aPoints );
		if( $retId != $lineId && ! $hOpt->{'retain'} ){
            $cnv->delete( $lineId );
        }
        print STDERR "B \$lineId <", $lineId, ">  \$otherId <", ($otherId || ''), ">  \$retId <", $retId, ">\n";  # _DEBUG_
        @ret = ( $retId, $aPoints );
        push @ret, $otherId if $otherId;
        push @ret, $isctPt  if $isctPt;
	}else{
        @ret = ( $lineId, $aNew );
	}

 	return @ret;
}

sub applyCut {
 	my( $cnv, $lineId, $aNew, $aIsctInfo, $type, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my( $otherId, $isct, $aOther ) = @{$aIsctInfo->[0]};
	print STDERR "A \$lineId <", $lineId, ">  \$otherId <", $otherId, ">\n";  # _DEBUG_
	my( $retId, $aPoints, $isctPt ) = ( $otherId );
# 	my @err;

	my @sort2 = sort {$a->[2] <=> $b->[2] || $a->[1] <=> $b->[1]} @$isct;
	my $isctS = [ $isct, \@sort2 ];

	{
        no strict 'refs';
#       print STDERR "\$func <", $func, ">  \@args <", join('|',@args), ">\n";  # _DEBUG_
        my $funcApply = 'isct_' . $type;
        ( $aPoints ) = &$funcApply( $isctS, $aOther, $aNew );
	}

	my @ret;
    my $drawId = $hOpt->{'retain'} ? {-fill => '#00FF00'} : $retId;
    linePoints( $cnv, $drawId, $aPoints );
    if( ! $hOpt->{'retain'} ){
        $cnv->delete( $lineId );
    }
    print STDERR "B \$lineId <", $lineId, ">  \$otherId <", ($otherId || ''), ">  \$retId <", $retId, ">\n";  # _DEBUG_
    @ret = ( $retId, $aPoints );
    push @ret, $otherId;

 	return @ret;
}




#-------------------------------------------------------------------------------


our $MAX_APPLY_DIST = 20;
our $MIN_END_DIST   = 3 * $MAX_APPLY_DIST;


sub match_close_self {
	my( $isctS, $aPoints, $aNew ) = @_;
    return 0 unless $aPoints == $aNew;

	my( $pt10, $pt11, $pt20, $pt21, $ptX10, $ptX11, $ptX20, $ptX21 ) = relevantPoints( $isctS, $aPoints, $aNew );
	my $ret = 0;

#   my( $pt10, $pt11, $ptX ) = ( $aPoints->[0], $aPoints->[-1], $sort1->[0][0] );
    $ret = (OGF::Geo::Geometry::dist($pt10,$pt11) <= $MAX_APPLY_DIST && OGF::Geo::Geometry::dist($pt10,$ptX10) <= $MAX_APPLY_DIST);
    return $ret ? 1 : 0;
}

sub match_close_other {
	my( $isctS, $aPoints, $aNew ) = @_;
    return 0 if $aPoints == $aNew;

	my( $pt10, $pt11, $pt20, $pt21, $ptX10, $ptX11, $ptX20, $ptX21 ) = relevantPoints( $isctS, $aPoints, $aNew );
	my $ret = 0;

#   my( $ret, $pt10, $pt11, $ptX0, $ptX1 ) = ( 0, $aPoints->[0], $aPoints->[-1], $sort1->[0][0], $sort1->[-1][0] );
	if( OGF::Geo::Geometry::dist($pt10,$ptX21) <= $MAX_APPLY_DIST && OGF::Geo::Geometry::dist($pt11,$ptX20) <= $MAX_APPLY_DIST ){
		$ret = 1;
	}elsif( OGF::Geo::Geometry::dist($pt10,$ptX20) <= $MAX_APPLY_DIST && OGF::Geo::Geometry::dist($pt11,$ptX21) <= $MAX_APPLY_DIST ){
		$ret = -1;
	}
    return $ret;
}

sub match_extend_end {
	my( $isctS, $aPoints, $aNew ) = @_;
    return 0 if $aPoints == $aNew;

	my( $pt10, $pt11, $pt20, $pt21, $ptX10, $ptX11, $ptX20, $ptX21 ) = relevantPoints( $isctS, $aPoints, $aNew );
	my $ret = 0;

#   my( $ret, $pt10, $pt11, $ptX0, $ptX1, $pt20, $pt ) = ( 0, $aPoints->[0], $aPoints->[-1], $sort1->[0][0], $sort1->[-1][0] );
	if( OGF::Geo::Geometry::dist($pt11,$pt20) <= $MAX_APPLY_DIST && OGF::Geo::Geometry::dist($ptX10,$ptX11) <= $MAX_APPLY_DIST ){
		$ret = 1;
	}elsif( OGF::Geo::Geometry::dist($pt11,$pt21) <= $MAX_APPLY_DIST && OGF::Geo::Geometry::dist($ptX10,$ptX11) <= $MAX_APPLY_DIST ){
		$ret = -1;
	}
    return $ret;
}

sub match_extend_start {
	my( $isctS, $aPoints, $aNew ) = @_;
    return 0 if $aPoints == $aNew;

	my( $pt10, $pt11, $pt20, $pt21, $ptX10, $ptX11, $ptX20, $ptX21 ) = relevantPoints( $isctS, $aPoints, $aNew );
	my $ret = 0;

	if( OGF::Geo::Geometry::dist($pt10,$pt21) <= $MAX_APPLY_DIST && OGF::Geo::Geometry::dist($ptX10,$ptX11) <= $MAX_APPLY_DIST ){
		$ret = 1;
	}elsif( OGF::Geo::Geometry::dist($pt10,$pt20) <= $MAX_APPLY_DIST && OGF::Geo::Geometry::dist($ptX10,$ptX11) <= $MAX_APPLY_DIST ){
		$ret = -1;
	}
    return $ret;
}

sub match_connect {
	my( $isctS, $aPoints, $aNew ) = @_;
    return 0 if $aPoints == $aNew;

	my( $pt10, $pt11, $pt20, $pt21, $ptX10, $ptX11, $ptX20, $ptX21 ) = relevantPoints( $isctS, $aPoints, $aNew );
	my $ret = 0;

#   my( $ret, $ptX0, $ptX1, $pt20, $pt21 ) = ( 0, $sort1->[0][0], $sort1->[0][-1], $aNew->[0], $aNew->[-1] );
	if( OGF::Geo::Geometry::linePointDist($aPoints,$pt21) <= $MAX_APPLY_DIST && OGF::Geo::Geometry::dist($ptX10,$ptX11) <= $MAX_APPLY_DIST ){
		$ret = 1;
	}elsif( OGF::Geo::Geometry::linePointDist($aPoints,$pt20) <= $MAX_APPLY_DIST && OGF::Geo::Geometry::dist($ptX10,$ptX11) <= $MAX_APPLY_DIST ){
		$ret = -1;
	}
    return $ret;
}

sub match_improve {
	my( $isctS, $aPoints, $aNew ) = @_;
    return 0 if $aPoints == $aNew;

	my( $pt10, $pt11, $pt20, $pt21, $ptX10, $ptX11, $ptX20, $ptX21 ) = relevantPoints( $isctS, $aPoints, $aNew );
	my $ret = 0;

	if( OGF::Geo::Geometry::dist($pt10,$pt20) > $MIN_END_DIST && OGF::Geo::Geometry::dist($pt10,$pt21) > $MIN_END_DIST 
	&& OGF::Geo::Geometry::dist($pt11,$pt20) > $MIN_END_DIST && OGF::Geo::Geometry::dist($pt11,$pt21) > $MIN_END_DIST
	&& OGF::Geo::Geometry::linePointDist($aPoints,$pt21) <= $MAX_APPLY_DIST && OGF::Geo::Geometry::linePointDist($aPoints,$pt20) <= $MAX_APPLY_DIST ){
		my( $sort1, $sort2 ) = @$isctS;
		if( $sort1->[-1][2] > $sort1->[0][2] ){
			return 1;
		}elsif( $sort1->[-1][2] < $sort1->[0][2] ){
			return -1;
		}
	}
    return $ret;
}



sub relevantPoints {
	my( $isctS, $aPoints, $aNew ) = @_;
	my( $sort1, $sort2 ) = @$isctS;
    my( $pt10, $pt11, $pt20, $pt21, $ptX10, $ptX11, $ptX20, $ptX21 ) = ( $aPoints->[0], $aPoints->[-1], $aNew->[0], $aNew->[-1], $sort1->[0][0], $sort1->[-1][0], $sort2->[0][0], $sort2->[-1][0] );
	return ( $pt10, $pt11, $pt20, $pt21, $ptX10, $ptX11, $ptX20, $ptX21 );
}





sub isct_reverse {
	my( $isctS, $aPoints, $objIdx ) = @_;
	$objIdx = 2 if ! defined $objIdx;

	my( $n, @points ) = ( $#{$aPoints} );
	for( my $i = 0; $i <= $n; ++$i ){
		my $j = $n - $i;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}

	my( $sort1, $sort2 ) = @$isctS;
	for( my $i = 0; $i <= $#{$isctS->[0]}; ++$i ){
		$sort1->[$i][$objIdx] = $n-1 - $sort1->[$i][$objIdx];
		# sort1 only, because sort2 points to the same values 
	}
	@$sort1 = sort {$a->[1] <=> $b->[1] || $a->[2] <=> $b->[2]} @$sort1 if $objIdx == 1;
	@$sort2 = sort {$a->[2] <=> $b->[2] || $a->[1] <=> $b->[1]} @$sort2 if $objIdx == 2;
	return \@points;
}

sub isct_close_self {
	my( $isctS, $aPoints ) = @_;
	my( $sort1, $sort2 ) = @$isctS;

#	my( $n, @points ) = ( scalar(@$aPoints) );
	my $ic2 = (scalar @$sort1) / 2;
	my @points;
	print STDERR "\$ic2 <", $ic2, ">\n";  # _DEBUG_

	my( $i0, $i1 ) = ( $sort1->[$ic2-1][1]+1, $sort1->[$ic2][1] );
	print STDERR "\$i0 <", $i0, ">  \$i1 <", $i1, ">\n";  # _DEBUG_
	for( my $i = 0; $i <= $i1-$i0; ++$i ){
		my $j = $i + $i0;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}
	@points = ( $sort1->[$ic2-1][0], @points, $sort1->[$ic2][0] );
#	print STDERR printPoints(\@points);

	return \@points;
}

sub isct_close_other {
	my( $isctS, $aPoints, $aNew ) = @_;

#	my( $n, @points ) = ( scalar(@$aPoints) );
#	my $iN = scalar(@$isct);

#	my @sort1 = @$isct;  # sort {$a->[1] <=> $b->[1] || $a->[2] <=> $b->[2]} @$isct;
#	my @sort2 = sort {$a->[2] <=> $b->[2] || $a->[1] <=> $b->[1]} @$isct;
	my( $sort1, $sort2 ) = @$isctS;
	my @points;

#	my( $i11, $i20 ) = ( $sort1->[-1][1], $sort1->[-1][2]+1 );
#	my( $i21, $i10 ) = ( $sort2->[-1][2], $sort2->[-1][1]+1 );
	my( $i10, $i11 ) = ( $sort1->[0][1], $sort1->[-1][1] );
	my( $i20, $i21 ) = ( $sort1->[-1][2], $sort1->[0][2] );
	print STDERR "\$i10 <", $i10, ">  \$i11 <", $i11, ">  \$i20 <", $i20, ">  \$i21 <", $i21, ">\n";  # _DEBUG_

	@points = ( $sort1->[0][0] );
	for( my $i = 0; $i < $i11-$i10; ++$i ){
		my $j = $i + $i10 + 1;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}
	push @points, $sort1->[-1][0];
	
	for( my $i = 0; $i < $i21-$i20; ++$i ){
		my $j = $i + $i20 + 1;
		push @points, [ $aNew->[$j][0], $aNew->[$j][1], [1,$j] ];
	}
	push @points, $sort1->[0][0];

	return \@points;
}

sub isct_extend_end {
	my( $isctS, $aPoints, $aNew ) = @_;

#	my( $n, @points ) = ( scalar(@$aPoints) );
#	my $iN = scalar(@$isct);

#	my @sort1 = @$isct;  # sort {$a->[1] <=> $b->[1] || $a->[2] <=> $b->[2]} @$isct;
	my( $sort1, $sort2 ) = @$isctS;
	my @points;

#	my( $i11, $i20 ) = ( $sort1->[-1][1], $sort1->[-1][2]+1 );
#	my( $i21, $i10 ) = ( $#{$aNew}, 0 );
	my( $i10, $i11 ) = ( 0, $sort1->[-1][1] );
	my( $i20, $i21 ) = ( $sort1->[-1][2]+1, $#{$aNew} );

	for( my $i = 0; $i <= $i11; ++$i ){
		my $j = $i;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}
	push @points, $sort1->[-1][0];

	for( my $i = 0; $i <= $i21-$i20; ++$i ){
		my $j = $i + $i20;
		push @points, [ $aNew->[$j][0], $aNew->[$j][1], [1,$j] ];
	}

	return \@points;
}

sub isct_extend_start {
	my( $isctS, $aPoints, $aNew ) = @_;

#	my( $n, @points ) = ( scalar(@$aPoints) );
#	my $iN = scalar(@$isct);

#	my @sort1 = @$isct;  # sort {$a->[1] <=> $b->[1] || $a->[2] <=> $b->[2]} @$isct;
#	my @sort2 = sort {$a->[2] <=> $b->[2] || $a->[1] <=> $b->[1]} @$isct;
	my( $sort1, $sort2 ) = @$isctS;
	my @points;

	my( $i10, $i11 ) = ( $sort2->[0][1]+1, $#{$aPoints} );
	my( $i20, $i21 ) = ( 0, $sort2->[0][2] );

	for( my $i = 0; $i <= $i21; ++$i ){
		my $j = $i;
		push @points, [ $aNew->[$j][0], $aNew->[$j][1], [1,$j] ];
	}
	push @points, $sort2->[0][0];

	for( my $i = 0; $i <= $i11-$i10; ++$i ){
		my $j = $i + $i10;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}

	return \@points;
}

sub isct_connect {
	my( $isctS, $aPoints, $aNew ) = @_;

#	my @sort1 = @$isct;
	my( $sort1, $sort2 ) = @$isctS;
	my $i21 = $sort1->[0][2];
	my @points;

	for( my $i = 0; $i <= $i21; ++$i ){
		my $j = $i;
		push @points, [ $aNew->[$j][0], $aNew->[$j][1], [1,$j] ];
	}
	push @points, $sort1->[0][0];

	return \@points, $sort1->[0];
}

sub isct_improve {
	my( $isctS, $aPoints, $aNew ) = @_;

#	my( $n, @points ) = ( scalar(@$aPoints) );
#	my $iN = scalar(@$isct);

#	my @sort1 = @$isct;  # sort {$a->[1] <=> $b->[1] || $a->[2] <=> $b->[2]} @$isct;
#	my @sort2 = sort {$a->[2] <=> $b->[2] || $a->[1] <=> $b->[1]} @$isct;
	my( $sort1, $sort2 ) = @$isctS;
	my @points;

	my( $diffMax, $ii0, $ii1 ) = ( 0 );
	for( my $i = 0; $i < $#{$sort1}; ++$i ){
		my $diff = $sort1->[$i+1][1] - $sort1->[$i][1];
		( $diffMax, $ii0, $ii1 ) = ( $diff, $i, $i+1 ) if $diff > $diffMax;
	}
	print STDERR "\$diffMax <", $diffMax, ">  \$ii0 <", $ii0, ">  \$ii1 <", $ii1, ">\n";  # _DEBUG_
	my( $i10, $i11 ) = ( $sort1->[$ii0][1], $sort1->[$ii1][1] );
	my( $i20, $i21 ) = ( $sort2->[$ii0][2], $sort2->[$ii1][2] );
	print STDERR "\$i10 <", $i10, ">  \$i11 <", $i11, ">  \$i20 <", $i20, ">  \$i21 <", $i21, ">\n";  # _DEBUG_

	for( my $i = 0; $i <= $i10; ++$i ){
		my $j = $i;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}
	push @points, $sort1->[$ii0][0];

	for( my $i = 0; $i < $i21-$i20; ++$i ){
		my $j = $i + $i20 + 1;
		push @points, [ $aNew->[$j][0], $aNew->[$j][1], [1,$j] ];
	}
	push @points, $sort1->[$ii1][0];

	for( my $i = 0; $i < $#{$aPoints}-$i11; ++$i ){
		my $j = $i + $i11 + 1;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}

	return \@points;
}

sub isct_cut_end {
	my( $isctS, $aPoints, $aNew ) = @_;

	my( $sort1, $sort2 ) = @$isctS;
	my @points;

	my( $i10, $i11 ) = ( 0, $sort1->[-1][1] );
#	my( $i20, $i21 ) = ( $sort1->[-1][2]+1, $#{$aNew} );

	for( my $i = 0; $i <= $i11; ++$i ){
		my $j = $i;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}
	push @points, $sort1->[-1][0];

	return \@points;
}

sub isct_cut_start {
	my( $isctS, $aPoints, $aNew ) = @_;

	my( $sort1, $sort2 ) = @$isctS;
	my @points;

	my( $i10, $i11 ) = ( $sort2->[0][1]+1, $#{$aPoints} );
#	my( $i20, $i21 ) = ( 0, $sort2->[0][2] );

	push @points, $sort2->[0][0];
	for( my $i = 0; $i <= $i11-$i10; ++$i ){
		my $j = $i + $i10;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}

	return \@points;
}

sub isct_insert_point {
	my( $isctS, $aPoints, $aNew ) = @_;

	my( $sort1, $sort2 ) = @$isctS;
	my @points;

	my( $i10, $i11 ) = ( 0, $sort1->[-1][1] );

	for( my $i = 0; $i <= $i11; ++$i ){
		my $j = $i;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}
	push @points, $sort1->[-1][0];

	for( my $i = 1; $i <= $#{$aPoints}-$i11; ++$i ){
		my $j = $i + $i11;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}
#	print STDERR "\@points ", scalar(@{$aPoints}), " -> ", scalar(@points), "\n";  # _DEBUG_

	return \@points;
}


sub line_rotate {
	my( $aPoints, $iNew ) = @_;
	my( $n, @points ) = ( scalar(@$aPoints) );
	for( my $i = 0; $i < $n; ++$i ){
		my $j = ($i < $n - $iNew)? $i + $iNew : $i + $iNew - $n;
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}
	return \@points;
}

sub isct_rotate {
	my( $isctS, $aPoints, $aNew ) = @_;

	my( $sort1, $sort2 ) = @$isctS;
	my @points;

	my( $i10, $i11 ) = ( 0, $sort1->[-1][1] );
#	print STDERR "\$i10 <", $i10, ">  \$i11 <", $i11, ">\n";  # _DEBUG_

	push @points, $sort1->[-1][0];
	for( my $i = 1; $i <= $#{$aPoints}-$i11; ++$i ){
		my $j = $i + $i11;
#		print STDERR "A \$j <", $j, ">\n";  # _DEBUG_
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}

	for( my $i = 1; $i <= $i11; ++$i ){   # start at 1 bc closed way
		my $j = $i;
#		print STDERR "B \$j <", $j, ">\n";  # _DEBUG_
		push @points, [ $aPoints->[$j][0], $aPoints->[$j][1], [0,$j] ];
	}
	push @points, $sort1->[-1][0];
#	print STDERR "\@points ", scalar(@{$aPoints}), " -> ", scalar(@points), "\n";  # _DEBUG_

	return \@points;
}





#-------------------------------------------------------------------------------

sub linePoints {
	my( $cnv, $lineId, $aPoints ) = @_;
	my @coord;
	if( $aPoints ){
		@coord = map {$_->[0],$_->[1]} @$aPoints;
		if( ref($lineId) ){
			$cnv->createLine( @coord, %$lineId );
		}else{
			$cnv->coords( $lineId, @coord );
		}
	}else{
		@coord = $cnv->coords( $lineId );
		$aPoints = [ map {[$coord[2*$_], $coord[2*$_+1]]} (0 .. ($#coord / 2)) ] if @coord;
	}
	return $aPoints;
}

sub overlapObjects {
	my( $cnv, $rectOrId ) = @_;
	$rectOrId = boundingRect($cnv,$rectOrId) if ! ref($rectOrId);
	my @objList = $cnv->find( 'overlapping', @$rectOrId );
	return @objList;
}

sub boundingRect {
	my( $cnv, $lineId, $margin ) = @_;
	my $mg = $margin || 0;
	my @coord = $cnv->coords( $lineId );

	my( $xMin, $yMin, $xMax, $yMax ) = ( $coord[0],$coord[1], $coord[0],$coord[1] );
	for( my $i = 2; $i < $#coord; $i += 2 ){
		my( $x, $y ) = ( $coord[$i], $coord[$i+1] );
		$xMin = $x if $x < $xMin;
		$xMax = $x if $x > $xMax;
		$yMin = $y if $y < $yMin;
		$yMax = $y if $y > $yMax;
	}
	return [ $xMin-$mg, $yMin-$mg, $xMax+$mg, $yMax+$mg ];
}



#-------------------------------------------------------------------------------

sub algVisvalingamWhyatt {
	my( $aPoints, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;

	my $areaMax = 999999;
	my( $n, @area ) = ( $#{$aPoints} );
#	print STDERR "\$n <", $n, ">  \@area <", join('|',@area), ">\n";  # _DEBUG_
	$area[0]  = { _idx =>  0, _pt => $aPoints->[0],  _size => $areaMax };
	$area[$n] = { _idx => $n, _pt => $aPoints->[$n], _size => $areaMax };

	for( my $i = 1; $i < $n; ++$i ){
		$area[$i] = { _idx => $i, _pt => $aPoints->[$i], _size => triangleArea($aPoints->[$i-1], $aPoints->[$i], $aPoints->[$i+1]) };
#		print STDERR "\$area[$i] <", $area[$i]{_size}, ">\n";  # _DEBUG_
	}

#	my( $ct, $limit ) = ( 0, $n * .85 );
	my $thres = $hOpt->{'threshold'} || 4.5;
	while( 1 ){
		my( $minArea, $i ) = minimumSizeIndex( \@area, $areaMax );
		print STDERR "  \$minArea <", $minArea, ">  \$i <", $i, ">  ", $#area, "\n" if $#area % 1000 == 0;  # _DEBUG_
		last if $minArea > $thres || $#area <= 1;
		$area[$i-1]{_size} = triangleArea( $area[$i-2]{_pt}, $area[$i-1]{_pt}, $area[$i+1]{_pt} ) unless $area[$i-1]{_size} == $areaMax;
		$area[$i+1]{_size} = triangleArea( $area[$i-1]{_pt}, $area[$i+1]{_pt}, $area[$i+2]{_pt} ) unless $area[$i+1]{_size} == $areaMax;
		splice @area, $i, 1;
	}		

#	my @points = map {$_->{_pt}} @area;
	my @points;
	if( $hOpt->{'fitSegments'} ){
		@points = fitSegments( $aPoints, \@area );
	}elsif( $hOpt->{'randomDisplace'} ){
		@points = @{ randomDisplace( $hOpt->{'randomDisplace'}, $aPoints ) };
	}elsif( $hOpt->{'indexOnly'} ){
		@points = map {$_->{_idx}} @area;
	}else{
		@points = map {$_->{_pt}} @area;
	}
	return \@points;
}

sub randomDisplace {
	my( $dist, $aPoints ) = @_;
	my @points;

	for( my $i = 1; $i < $#{$aPoints}; ++$i ){
		my $pt = randomNormalDisplace( $dist, $aPoints->[$i-1], $aPoints->[$i], $aPoints->[$i+1] );
		push @points, $pt;
	}
	if( $aPoints->[0][0] == $aPoints->[1][0] && $aPoints->[0][1] == $aPoints->[1][1] ){
		my $pt = randomNormalDisplace( $dist, $aPoints->[-1], $aPoints->[0], $aPoints->[1] );
		push    @points, $pt;
		unshift @points, $pt;
	}else{
		my $pt0 = randomNormalDisplace( $dist, $aPoints->[0] );
		my $pt1 = randomNormalDisplace( $dist, $aPoints->[-1] );
		push    @points, $pt1;
		unshift @points, $pt0;
	}

	return \@points;
}

sub randomNormalDisplace {
	my( $dist, $ptA, $pt, $ptB ) = @_;
	my( $x, $y );
	if( $pt ){
		( $x, $y ) = ( $pt->[0], $pt->[1] );
		my( $xA, $yA, $xB, $yB ) = ( $ptA->[0], $ptA->[1], $ptB->[0], $ptB->[1] );
		my( $vA, $vB ) = ( OGF::Geo::Geometry::vecToLength([$x-$xA,$y-$yA],1), OGF::Geo::Geometry::vecToLength([$xB-$x,$yB-$y],1) );
		my $len2 = min( $dist, OGF::Geo::Geometry::dist([0,0], [$xB - $xA, $yB - $yA]) / 2 );
		my $vN = OGF::Geo::Geometry::vecToLength( [$vB->[0] - $vA->[0], $vB->[1] - $vA->[1]], rand($len2) );
		$x += $vN->[0];
		$y += $vN->[1];
	}else{
		( $x, $y ) = ( $ptA->[0], $ptA->[1] );
		$x += rand($dist) - $dist/2;
		$y += rand($dist) - $dist/2;
	}
	return [ $x, $y ];
}

sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }


sub fitSegments {
	my( $aPoints, $aArea ) = @_;
	my @points;
	for( my $i = 0; $i < $#{$aArea}; ++$i ){
		my( $pt0, $pt1, $i0, $i1 ) = ( $aArea->[$i]{_pt}, $aArea->[$i+1]{_pt}, $aArea->[$i]{_idx}, $aArea->[$i+1]{_idx} );
		my( $ptA, $ptB ) = fitSingleSegment( $pt0,$pt1, [map {$aPoints->[$_]} ($i0..$i1)] );
		push @points, $ptA, $ptB;
	}
#	use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [\@points], ['*points'] ), "\n";  # _DEBUG_

	my @points2 = ( $points[0] );
	for( my $i = 0; $i < $#points-2; $i += 2 ){
		my $lineA = [ $points[$i],   $points[$i+1] ];
		my $lineB = [ $points[$i+2], $points[$i+3] ];
		my $ptInt = OGF::Geo::Geometry::lineIntersect( @$lineA, @$lineB );
		push @points2, [$ptInt->[0],$ptInt->[1]];
	}
	push @points2, $points[-1];
#	use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [\@points2], ['*points2'] ), "\n";  # _DEBUG_

	return @points2;
}

sub fitSingleSegment {
	my( $pt0, $pt1, $aPoints ) = @_;
	my( $x0, $y0, $x1, $y1 ) = ( $pt0->[0], $pt0->[1], $pt1->[0], $pt1->[1] );
#	my( $xN, $yN ) = ( $x1 - $x0, $y1 - $y0 );
	my( $xN, $yN ) = ( $y0 - $y1, $x1 - $x0 );
	my $dN = sqrt( $xN*$xN + $yN*$yN );
#	return ( $pt0, $pt1 ) if $dN == 0;
	( $xN, $yN ) = ( $xN/$dN, $yN/$dN );
	my( $limit, $minDist, $dp ) = ( 3, 999999 );
	for( my $d = -$limit; $d <= $limit; $d += .01 ){
		my $di = segmentDist( [$x0+$d*$xN,$y0+$d*$yN], [$x1+$d*$xN,$y1+$d*$yN], $aPoints );
		( $minDist, $dp ) = ( $di, $d ) if $di < $minDist;
	}
	return ( [$x0+$dp*$xN,$y0+$dp*$yN], [$x1+$dp*$xN,$y1+$dp*$yN] );
}

sub segmentDist {
	my( $pt0, $pt1, $aPoints ) = @_;
	my $sum = 0;
	for( my $i = 0; $i < $#{$aPoints}; ++$i ){
		my $dd = OGF::Geo::Geometry::segmentDistance( $pt0, $pt1, $aPoints->[$i] );
#		$sum += $dd;
		$sum += $dd * $dd;
	}
	return $sum;	
}



sub minimumSizeIndex {
	my( $aArea, $areaMax ) = @_;
	my( $minArea, $idx ) = ( $areaMax );
	for( my $i = 1; $i <= $#{$aArea}; ++$i ){
#		print STDERR "\$i <", $i, ">  \$aArea->[\$i] <", $aArea->[$i], ">  \$aArea->[\$i]{_size} <", $aArea->[$i]{_size}, ">  \$minArea <", $minArea, ">\n";  # _DEBUG_
		( $minArea, $idx ) = ( $aArea->[$i]{_size}, $i ) if $aArea->[$i]{_size} < $minArea;
	}
	return ( $minArea, $idx );	
}

sub triangleArea {
	my( $pt0, $pt1, $pt2 ) = @_;
	my( $x0,$y0, $x1,$y1, $x2,$y2 ) = ( $pt0->[0],$pt0->[1], $pt1->[0],$pt1->[1], $pt2->[0],$pt2->[1] );
	my $area = abs( OGF::Geo::Geometry::vectorProduct( [$x0-$x1,$y0-$y1], [$x2-$x1,$y2-$y1] ) );
	return $area;
}




1;

