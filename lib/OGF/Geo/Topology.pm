package OGF::Geo::Topology;
use strict;
use warnings;
use Math::Trig;
use OGF::Const;
use OGF::Data::Context;
use OGF::Geo::Geometry;
#use Exporter;
#our @ISA = qw( Exporter );
#our @EXPORT_OK = qw(  );


my $pi  = $OGF::PI;
my $deg = $OGF::DEG;


sub max { $_[0] > $_[1] ? $_[0] : $_[1] }
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }

sub buildWaySequence {
	my( $ctx, $rel, $hWays, $hOpt ) = @_;
#	print STDERR "buildWaySequence( $ctx, $rel, $hWays, $hOpt )\n";  # _DEBUG_
	$hOpt = {} if ! $hOpt;
	my $repeatFlag = defined($hWays);

	if( ! $hWays ){
		my @ways;
		if( defined $rel ){
			my $rxRole = $hOpt->{'role'} ? $hOpt->{'role'} : '$';
#			@ways = map {$ctx->{_Way}{$_->{'ref'}}} grep {$_->{'type'} eq 'Way'&& $_->{'role'} =~ /$rxRole/} @{$rel->{'members'}};
			# grep {defined} to allow handling incomplete relations
			@ways = grep {defined} map {$ctx->{_Way}{$_->{'ref'}}} grep {$_->{'type'} eq 'Way'&& $_->{'role'} =~ /$rxRole/} @{$rel->{'members'}};
		}else{
			@ways = values %{$ctx->{_Way}};
		}
#		@ways = map {$ctx->cloneObject($_)} @ways if $hOpt->{'copy'};
		@ways = map {$ctx->cloneObject($_)} grep {defined} @ways if $hOpt->{'copy'};  # relation might be only partially included 
		$hWays = { map {$_->{'id'} => $_} @ways };
	}

	my( %ptStart, %ptEnd, %relOrder );
	%relOrder = %{$hOpt->{'relOrder'}} if ref($hOpt->{'relOrder'});

	foreach my $way ( values %$hWays ){
		if( scalar(@{$way->{'nodes'}}) < 2 ){
			warn qq/ERROR: Way consisting of single node\n/;
			next;
		}

		my( $idStart, $idEnd ) = ( $way->{'nodes'}[0], $way->{'nodes'}[-1] );
#		print STDERR "idStart <", $idStart, ">  \$idEnd <", $idEnd, ">\n";  # _DEBUG_
		$relOrder{$way->{'id'}} = [ $way->{'id'} ] if $hOpt->{'relOrder'};

		if( $idStart == $idEnd ){
			$ptStart{$idStart} = $way;
		}else{
			if( ($ptStart{$idStart} || $ptEnd{$idEnd}) && ! $hOpt->{'wayDirection'} ){
				my $way2 = $ptStart{$idStart} || $ptEnd{$idEnd};
#				print STDERR "rev $way2->{id}\n";
				@{$way2->{'nodes'}} = reverse @{$way2->{'nodes'}};
				if( $hOpt->{'relOrder'} ){
					my $id = $way2->{'id'};
					@{$relOrder{$id}} = reverse @{$relOrder{$id}};
#					my @relWays = reverse @{$relOrder{$id}};
#					$relOrder{$relWays[0]} = delete $relOrder{$id};
				}
				my( $idS, $idE ) = ( $way2->{'nodes'}[0], $way2->{'nodes'}[-1] );
				delete $ptStart{$idE};
				delete $ptEnd{$idS};
				$ptStart{$idS} = $ptEnd{$idE} = $way2;
#				print STDERR "S: ", join(' ',keys %ptStart), "\nE: ", join(' ',keys %ptEnd), "\n";
			}
			if( $ptEnd{$idStart} ){
				shift @{$way->{'nodes'}};
#				print STDERR "join A $ptEnd{$idStart}->{id} $way->{id} -> $ptEnd{$idStart}->{nodes}[0] $ptEnd{$idStart}->{nodes}[-1]\n";
				push @{$ptEnd{$idStart}->{'nodes'}}, @{$way->{'nodes'}};
				if( $hOpt->{'relOrder'} ){
					push @{$relOrder{ $ptEnd{$idStart}->{'id'} }}, @{$relOrder{$way->{'id'}}};
					delete $relOrder{$way->{'id'}};
				}
				delete $hWays->{$way->{'id'}};
				removeContextWay( $ctx, $way ) unless $hOpt->{'copy'};
				$way = $ptEnd{$idStart};
				delete $ptEnd{$idStart};
			}
			if( $way->{'nodes'}[0] != $way->{'nodes'}[-1] ){
				if( $ptStart{$idEnd} ){
					pop @{$way->{'nodes'}};
#					print STDERR "join B $way->{id} $ptStart{$idEnd}->{id} -> $way->{nodes}[0] $way->{nodes}[-1]\n";
					push @{$way->{'nodes'}}, @{$ptStart{$idEnd}->{'nodes'}};
					if( $hOpt->{'relOrder'} ){
						push @{$relOrder{ $way->{'id'} }}, @{$relOrder{$ptStart{$idEnd}->{'id'}}};
						delete $relOrder{$ptStart{$idEnd}->{'id'}};
					}
					delete $hWays->{$ptStart{$idEnd}->{'id'}};
					removeContextWay( $ctx, $ptStart{$idEnd} ) unless $hOpt->{'copy'};
					delete $ptStart{$idEnd};
				}
				$ptStart{$way->{'nodes'}[0]} = $ptEnd{$way->{'nodes'}[-1]} = $way;
			}
		}
	}

	$hOpt->{'relOrder'} = \%relOrder if $hOpt->{'relOrder'};
	buildWaySequence( $ctx, $rel || undef, $hWays, $hOpt ) unless $repeatFlag;

	return $hOpt->{'relOrder'} ? [ sort {scalar(@$b) <=> scalar(@$a)} values %relOrder ] : [ values %$hWays ];
}

sub removeContextWay {   # avoid removal of related nodes (as in $ctx->removeObject)
	my( $ctx, $way ) = @_;
	delete $ctx->{_Way}{$way->{'id'}};
}

sub findDuplicatePoints {
	my( $way, $prefix ) = @_;
	my( $ct, $dupCount, %idCount ) = ( 0, 0 );
	foreach my $id ( @{$way->{'nodes'}} ){
		++$ct;
		++$idCount{$id};
		++$dupCount if $idCount{$id} == 2;
	}
	print STDERR "$prefix: $way -> $dupCount/$ct duplicates\n" if $dupCount;
}

sub removeLoops_ident {
	my( $ctx, $way ) = @_;
	print STDERR "removeLoops_ident( $ctx, $way->{'id'} )\n";  # _DEBUG_
	my( $i0, $i1 ) = ( 0, $#{$way->{'nodes'}} );
	my( $i, %pcache ) = ( $i0 );

	while( $i <= $i1 ){
		my $node = $ctx->{_Node}{$way->{'nodes'}[$i]};
		my $ptag = $node->{'lon'} .'|'. $node->{'lat'};
		my $j = $pcache{$ptag};
		if( defined($j) && $i <= $j+20 ){
#			print STDERR "  \$j <", $j, ">\n";  # _DEBUG_
			if( $i == $i1 ){
				map {$way->{'nodes'}[$_] = undef} ($j .. $i-1);
			}else{
				map {$way->{'nodes'}[$_] = undef} ($j+1 .. $i);
			}
			@{$way->{'nodes'}} = grep {defined} @{$way->{'nodes'}};
			( $i, $i1, %pcache ) = ( $i0, $#{$way->{'nodes'}} );
		}else{
			$pcache{$ptag} = $i;
			++$i;
		}
#		print STDERR "  $i1 - $i\n";
	}
}

sub removeLoops_intersect {
	my( $ctx, $way ) = @_;
	print STDERR "removeLoops_intersect( $ctx, $way->{'id'} )\n";  # _DEBUG_
	my( $i0, $i1 ) = ( 0, $#{$way->{'nodes'}} );

	my @points = $ctx->way2points( $way );
#	use Data::Dumper; local $Data::Dumper::Indent = 1; print STDERR Data::Dumper->Dump( [\@points], ['*points'] ), "\n"; exit; # _DEBUG_
#	my @inter = OGF::Geo::Geometry::array_intersect( \@points, \@points, {'limit' => [$i0,$i1,$i0,$i1]} );
	my @inter = OGF::Geo::Geometry::array_intersect( \@points, \@points, {'range' => 100} );
	foreach my $aI ( @inter ){
		my( $pt, $i, $j ) = @$aI;
		print STDERR "\$pt <", $pt, ">  \$i <", $i, ">  \$j <", $j, ">\n";  # _DEBUG_
		if( $j > $i && $j <= $i+10 ){
			map {$points[$_] = undef} ($i+1 .. $j);
			OGF::Geo::Geometry::array_insert( $aI );
		}
	}
	@points = grep {defined} @points;
	@{$way->{'nodes'}} = $ctx->points2way( \@points );
#	use Data::Dumper; local $Data::Dumper::Indent = 0; print STDERR Data::Dumper->Dump( [$self->{_ccnv}], ['ccnv'] ), "\n";
}

sub removeLoops_antiparallel {
	my( $ctx, $way ) = @_;
	print STDERR "removeLoops_antiparallel( $ctx, $way->{'id'} )\n";  # _DEBUG_
	my( $i0, $i1 ) = ( 0, $#{$way->{'nodes'}} );
	my( $i, %pcache ) = ( $i0 );

	while( $i+2 <= $i1 ){
		my $nodeA = $ctx->{_Node}{$way->{'nodes'}[$i]};
		my $nodeB = $ctx->{_Node}{$way->{'nodes'}[$i+1]};
		my $nodeC = $ctx->{_Node}{$way->{'nodes'}[$i+2]};
		my $sp = $ctx->scalarProduct( $nodeA, $nodeB, $nodeB, $nodeC );
		my $vp = $ctx->vectorProduct( $nodeA, $nodeB, $nodeB, $nodeC );
		if( $vp == 0 && $sp < 0 ){
			$way->{'nodes'}[$i+1] = undef;
			@{$way->{'nodes'}} = grep {defined} @{$way->{'nodes'}};
			( $i, $i1 ) = ( max($i0,$i-2), $#{$way->{'nodes'}} );
			print STDERR "> \$i <", $i, ">  \$i1 <", $i1, ">\n";  # _DEBUG_
		}else{
			++$i;
		}
	}
}

sub pconnect {
	my( $ctx, $wayA, $wayB ) = @_;
#	my $cut = ($hOpt && defined $hOpt->{'cut'})? $hOpt->{'cut'} : 4;
#	print STDERR "\$cut <", $cut, ">\n";  # _DEBUG_

	my @pointsA = $ctx->way2points( $wayA );
	my @pointsB = $ctx->way2points( $wayB );

	my @inter = OGF::Geo::Geometry::array_intersect( \@pointsA, \@pointsB );
#	use Data::Dumper; local $Data::Dumper::Indent = 0; print STDERR Data::Dumper->Dump( [\@inter], ['inter'] );
	return 0 if ! @inter;

	OGF::Geo::Geometry::array_insert( \@pointsA, @inter );
	return 1 if $wayA == $wayB;

	# TODO: handle case of two intersection points in one segment of $other
	@inter = map {[$_->[0],$_->[2]]} sort {$a->[2] <=> $b->[2]} @inter;
	return 0 if ! @inter;
	OGF::Geo::Geometry::array_insert( \@pointsB, @inter );

	my %ptCache;
	@{$wayA->{'nodes'}} = $ctx->points2way( \@pointsA, \%ptCache );
	@{$wayB->{'nodes'}} = $ctx->points2way( \@pointsB, \%ptCache );
	return 1;
}









1;

