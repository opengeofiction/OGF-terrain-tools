package OGF::Data::Relation;
use strict;
use warnings;
use OGF::Util;


sub new {
	my( $pkg, $context, $attr ) = @_;

	my $self = {};
	bless $self, $pkg;
	$self->parseAttr( $attr );
	$context->addObject( 'Relation', $self, $attr );

	return $self;
}

sub class {  'Relation';  }

sub uid {  'R|' . $_[0]->{'id'};  }

sub tagMatch {
	my( $self, $hMatch ) = @_;
	return OGF::Data::Context::tagMatch( $self, $hMatch );
}

sub add_tag {
	my( $self, %args ) = @_;
	map {$self->{'tags'}{$_} = $args{$_}} keys %args;
}

sub add_member {
	my( $self, @members ) = @_;
#	push @{$self->{'members'}}, @members;
	my $role = ref($members[0]) ? '' : (shift @members);
	foreach my $mb ( @members ){
		if( ref($mb) =~ /\b(Node|Way|Relation)\b/ ){
			$mb = {'type' => $mb->class, 'ref' => $mb->{'id'}, 'role' => $role};
		}
		push @{$self->{'members'}}, $mb;
	}
	$self->{_context}->setReverseInfo_Relation( $self ) if $self->{_context};
}

sub removeMember {
	my( $self, $obj ) = @_;
	my( $type, $id, $uid ) = ( $obj->class, $obj->{'id'}, $obj->uid );
	@{$self->{'members'}} = grep {!($_->{'type'} eq $type && $_->{'ref'} == $id)} @{$self->{'members'}};
	delete $self->{_context}{_rev_info}{$uid}{$self->uid};
}

sub toString {
	my( $self ) = @_;
	my $str = join( '|', 'R', $self->{'id'}, $self->{'version'} );
	if( $self->{'tags'} ){
		$str .= OGF::Util::tagText( $self->{'tags'} );
	}
	if( $self->{'members'} ){
		foreach my $mb ( @{$self->{'members'}} ){
			my( $type, $role, $mbId ) = ( $mb->{'type'}, $mb->{'role'}, $mb->{'ref'} );
			$role = substr($role,0,1) if $role eq 'inner' || $role eq 'outer';
			$str .= '|'. join( ';', uc(substr($type,0,1)), $role, $mbId );
		}
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
	my $hTags    = $self->{'tags'}    = {};
	my $aMembers = $self->{'members'} = [];

	foreach my $item ( @list ){
		if( $item =~ /^[NWR];/ ){
			my( $type, $role, $mbId ) = split /;/, $item;
			$type = $OGF::Util::OBJECT_TYPE_MAP{$type};
			if( $role eq 'o' ){
				$role = 'outer';
			}elsif( $role eq 'i' ){
				$role = 'inner';
			}
			push @$aMembers, {'type' => $type, 'role' => $role, 'ref' => $mbId};
		}else{
			OGF::Util::tagParse( $hTags, $item );
		}
	}
}

sub closedWayComponents {
	my( $self, $rxRole, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	if( ! $self->{_way_components}{$rxRole} ){
		$self->{_way_components}{$rxRole} = OGF::Geo::Topology::buildWaySequence( $self->{_context}, $self, undef, {'copy' => 1, 'role' => $rxRole, %$hOpt} );
	}
	return $self->{_way_components}{$rxRole};
}


sub boundingRectangle {
	my( $self, $ctx, $proj ) = @_;
	$proj = OGF::View::Projection->identity() if ! $proj;
	$ctx = $self->{_context} if ! $ctx;
#	print STDERR "Relation::boundingRectangle <", $self->{'id'}, ">\n";  # _DEBUG_
#	use ARS::Util::Exception; ARS::Util::Exception::printStackTrace();

#	my $mb = $self->{'members'}[0];
#	my $node = ($mb->{'type'} eq 'Node')? $ctx->{_Node}{$mb->{'ref'}} : $ctx->{_Node}{ $ctx->{_Way}{$mb->{'ref'}}{'nodes'}[0] };
	my $node = $self->findNode( $ctx );
	return undef if ! $node;

	my( $xMin, $yMin, $xMax, $yMax ) = ( $proj->geo2cnv($node->{'lon'},$node->{'lat'}), $proj->geo2cnv($node->{'lon'},$node->{'lat'}) );
	foreach my $mb ( @{$self->{'members'}} ){
		my( $type, $role, $mbId ) = ( $mb->{'type'}, $mb->{'role'}, $mb->{'ref'} );
#		print STDERR "\$type <", $type, ">  \$role <", $role, ">  \$mbId <", $mbId, ">\n";  # _DEBUG_
		my $obj = $ctx->{'_'.$type}{$mbId};
#		print STDERR "\$obj <", $obj, ">\n";  # _DEBUG_
		my( $x0, $y0, $x1, $y1 ) = ($type eq 'Node')? ($proj->geo2cnv($obj->{'lon'},$obj->{'lat'}),$proj->geo2cnv($obj->{'lon'},$obj->{'lat'})) : @{ $obj->boundingRectangle($ctx,$proj) };
		$xMin = $x0 if $x0 < $xMin;
		$xMax = $x1 if $x1 > $xMax;
		$yMin = $y0 if $y0 < $yMin;
		$yMax = $y1 if $y1 > $yMax;
	}
	return [ $xMin, $yMin, $xMax, $yMax ];
}

sub findNode {
	my( $self, $ctx ) = @_;
	my $node;
	foreach my $mb ( @{$self->{'members'}} ){
		my( $mbType, $mbId ) = ( $mb->{'type'}, $mb->{'ref'} );
		if( $mbType eq 'Node' ){
			$node = $ctx->{_Node}{$mbId};
			last;
		}elsif( $mbType eq 'Way' ){
			my $way = $ctx->{_Way}{$mbId};
			$node = $ctx->{_Node}{$way->{'nodes'}[0]} if @{$way->{'nodes'}};
			last if $node;
		}elsif( $mbType eq 'Relation' ){
			my $rel = $ctx->{_Relation}{$mbId};
			$node = $rel->findNode( $ctx );
			last if $node;
		}
	}
	return $node;
}



1;


