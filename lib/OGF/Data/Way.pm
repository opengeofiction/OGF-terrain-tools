package OGF::Data::Way;
use strict;
use warnings;
use OGF::Util;


sub new {
	my( $pkg, $context, $attr ) = @_;

	my $self = { 'nodes' =>  [] };
	bless $self, $pkg;
	$self->parseAttr( $attr );
	$context->addObject( 'Way', $self );

	return $self;
}

sub class {  'Way';  }

sub uid {  'W|' . $_[0]->{'id'};  }

sub tagMatch {
	return OGF::Data::Context::tagMatch( @_ );
}

sub add_tag {
	my( $self, %args ) = @_;
	map {$self->{'tags'}{$_} = $args{$_}} keys %args;
}

#sub add_node {
#	my( $self, @nodes ) = @_;
#	push @{$self->{'nodes'}}, (map {ref($_) ? $_->{'id'} : $_} @nodes);
#	$self->{_context}->setReverseInfo_Way( $self ) if $self->{_context};
#}

sub add_node {
	my( $self, @nodes ) = @_;
	$self->insert_node( scalar(@{$self->{'nodes'}}), @nodes );
}

sub insert_node {
	my( $self, $idx, @nodes ) = @_;
	my @nodeIds = map {ref($_) ? $_->{'id'} : $_} @nodes;
	splice @{$self->{'nodes'}}, $idx, 0, @nodeIds;
#	push @{$self->{'nodes'}}, (map {ref($_) ? $_->{'id'} : $_} @nodes);
	$self->{_context}->setReverseInfo_Way( $self ) if $self->{_context};
}

sub toString {
	my( $self ) = @_;
	my $str = join( '|', 'W', $self->{'id'}, $self->{'version'} );
	if( $self->{'tags'} ){
		$str .= OGF::Util::tagText( $self->{'tags'} );
	}
	if( $self->{'nodes'} ){
		$str .= '|'. join( '|', @{$self->{'nodes'}} );  # used to write .ogf files
#		my $ctx = $self->{_context};
#		foreach my $nodeId ( @{$self->{'nodes'}} ){
#			my $node = $ctx->{_Node}{$nodeId};
#			$str .= '['. $node->{'lon'} .','. $node->{'lat'} .']';
#		}
	}
	return $str;
}

sub parseAttr {
	my( $self, $str ) = @_;
	if( ref($str) ){
		map {$self->{$_} = $str->{$_}} keys %$str;
		return;
	}

	chomp $str;
	my( $type, $id, $version, @list ) = split /\|/, $str;
	$self->{'id'}      = $id;
	$self->{'version'} = $version;
	my $hTags  = $self->{'tags'}  = {};
	my $aNodes = $self->{'nodes'} = [];

	foreach my $item ( @list ){
		if( $item !~ /^-?\d/ ){
			OGF::Util::tagParse( $hTags, $item );
		}else{
			push @$aNodes, $item;
		}
	}
}

sub splitAt {
	my( $self, $i, $ctx ) = @_;
	$ctx = $self->{_context} if ! $ctx;

	my $iE = $#{$self->{'nodes'}};
	my $aNodes = [ @{$self->{'nodes'}}[$i .. $iE] ];
	@{$self->{'nodes'}} = @{$self->{'nodes'}}[0 .. $i];

	my $newWay = OGF::Data::Way->new( $ctx, {'tags' => { %{$self->{'tags'}} }, 'nodes' => $aNodes} );
	return $newWay;
}

sub boundingRectangle {
	my( $self, $ctx, $proj, $len ) = @_;
	$proj = OGF::View::Projection->identity() if ! $proj;
	$ctx = $self->{_context} if ! $ctx;
#	OGF::Util::printStackTrace();

	my @nodes = @{$self->{'nodes'}};
	@nodes = ($len >= 0)? @nodes[0 .. $len] : @nodes[$len-1 .. -1] if defined $len;
	@nodes = grep {defined} @nodes;
#	print STDERR "\@nodes <", join('|',@nodes), ">\n";  # _DEBUG_

	my $node = $ctx->{_Node}{$nodes[0]};
	my( $xMin, $yMin, $xMax, $yMax ) = ( $proj->geo2cnv($node->{'lon'},$node->{'lat'}), $proj->geo2cnv($node->{'lon'},$node->{'lat'}) );
	foreach my $nodeId ( @nodes ){
		$node = $ctx->{_Node}{$nodeId};
		my( $x, $y ) = $proj->geo2cnv( $node->{'lon'}, $node->{'lat'} );
		$xMin = $x if $x < $xMin;
		$xMax = $x if $x > $xMax;
		$yMin = $y if $y < $yMin;
		$yMax = $y if $y > $yMax;
	}
	return [ $xMin, $yMin, $xMax, $yMax ];
}

sub centroid {
	require OGF::Geo::Geometry;
	my( $self, $ctx ) = @_;
	$ctx = $self->{_context} if ! $ctx;
	my $aPoints = $ctx->way2points( $self );
	my( $x, $y ) = OGF::Geo::Geometry::polygonCentroid($aPoints);
	return ( $x, $y );
}

sub maximumInsideCircle {
	require OGF::Geo::Geometry;
	my( $self, $ctx ) = @_;
	$ctx = $self->{_context} if ! $ctx;
#	OGF::Util::printStackTrace();
	my $aRect = $self->boundingRectangle( $ctx, $ctx->{_proj} );

	my $aWay = $ctx->way2points( $self );
	my( $step, $x0, $y0, $x1, $y1 ) = ( 10, @$aRect );
	print STDERR "A \$step <", $step, ">  \$x0 <", $x0, ">  \$y0 <", $y0, ">  \$x1 <", $x1, ">  \$y1 <", $y1, ">\n";  # _DEBUG_
	my $aMaxDist = [ 0 ];

	foreach( 1, 2 ){
		for( my $y = $y0+$step/2; $y <= $y1; $y += $step ){
			for( my $x = $x0+$step/2; $x <= $x1; $x += $step ){
				my( $ins, $dist ) = OGF::Geo::Geometry::pointInside( $aWay, [$x,$y], {'minInsideDist' => 1} );
				$aMaxDist = [ $dist, $x, $y ] if $ins != 0 && $dist > $aMaxDist->[0];
			}
		}
		my( $x, $y ) = ( $aMaxDist->[1], $aMaxDist->[2] );
		( $step, $x0, $y0, $x1, $y1 ) = ( 2, $x-$step, $y-$step, $x+$step, $y+$step );
		print STDERR "B \$step <", $step, ">  \$x0 <", $x0, ">  \$y0 <", $y0, ">  \$x1 <", $x1, ">  \$y1 <", $y1, ">\n";  # _DEBUG_
	}
	return ( $aMaxDist->[1], $aMaxDist->[2], $aMaxDist->[0] );
}

sub nodeObjects {
	my( $self, $ctx ) = @_;
	$ctx = $self->{_context} if ! $ctx;
	my @nodes = map {$ctx->{_Node}{$_}} @{$self->{'nodes'}};
	return @nodes;
}

sub canvasPoints {
	require OGF::Geo::Geometry;
	my( $self, $ctx, $proj ) = @_;
	$ctx = $self->{_context} if ! $ctx;
	my $aNodes = $self->{'nodes'};
	my @points;
	for( my $i = 0; $i < $#{$aNodes}; ++$i ){
		my( $nodeA, $nodeB ) = ( $ctx->{_Node}{$aNodes->[$i]}, $ctx->{_Node}{$aNodes->[$i+1]} );
		my $ptA = $proj->geo2cnv( [$nodeA->{'lon'},$nodeA->{'lat'}] );
		my $ptB = $proj->geo2cnv( [$nodeB->{'lon'},$nodeB->{'lat'}] );
		push @points, OGF::Geo::Geometry::ptInt($ptA) if $i == 0;
		push @points, OGF::Geo::Geometry::linePoints($ptA,$ptB), OGF::Geo::Geometry::ptInt($ptB);
	}

	# remove duplicate points
	for( my $i = 0; $i < $#points; ++$i ){
		my( $ptA, $ptB ) = ( $points[$i], $points[$i+1] );
		$points[$i] = undef if $ptA->[0] == $ptB->[0] && $ptA->[1] == $ptB->[1];
	}
	@points = grep {defined} @points;

	return @points;
}

sub wayReverse {
	my( $self ) = @_;
	my( $ctx, $wayUid ) = ( $self->{_context}, $self->uid );

	my $n = $#{$self->{'nodes'}};
	my %revMap = map {'N|'.$_ => 'N|'.$self->{'nodes'}[$n-$_]} (0..$n);
	foreach my $nodeUid ( map {'N|'.$_} @{$self->{'nodes'}} ){
		my $hRevInfo = $self->{_rev_info}{$nodeUid};
		foreach my $uid ( keys %$hRevInfo ){
			$hRevInfo->{$uid} = $hRevInfo->{$revMap{$uid}};
		}
	}
	@{$self->{'nodes'}} = reverse @{$self->{'nodes'}};
}





#	if( length($str) > $MAX_LINE_WIDTH ){
#		my @lines = ($str =~ /.{,$MAX_LINE_WIDTH}/g);
#		$str = shift @lines . "\\\n ";
#		$str = $lines[0] . join("\\\n",@lines);
#	}




1;

