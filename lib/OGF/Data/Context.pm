package OGF::Data::Context;
use strict;
use warnings;
use FileHandle;
use IO::Scalar;
use OGF::Const;
use OGF::Util qw( exception );
use OGF::Data::Node;
use OGF::Data::Way;
use OGF::Data::Relation;


our $AUTOLOAD;


sub new {
	my( $pkg, $proj ) = @_;

	my $self = {
		_Node      => {},
		_Way       => {},
		_Relation  => {},
		_Changeset => {},
		_new_ID    => 0,
		_rev_info  => {},
	};
	$self->{_proj} = $proj if $proj;

	bless $self, $pkg;
}


sub AUTOLOAD {
	require OGF::Geo::Geometry;
	my $self = shift;
	$AUTOLOAD =~ s/.*:://;
#	print "TkView::AUTOLOAD ($self) $AUTOLOAD\n";

	if( OGF::Geo::Geometry->can($AUTOLOAD) ){
		my @args = $self->list_geo2cnv( @_ );
		
		no strict 'refs';
		my $func = 'OGF::Geo::Geometry::' . $AUTOLOAD;
		my @ret = &$func( @args );

		@ret = $self->list_cnv2geo( @ret );
		return wantarray ? @ret : $ret[0];
	}
}

sub list_geo2cnv {
	my( $self, @in ) = @_;
	my $proj = $self->{_proj};
	my @out;
	foreach my $arg ( @in ){
		if( ref($arg) eq 'OGF::Data::Node' ){
			my( $x, $y ) = $proj->geo2cnv( $arg->{'lon'}, $arg->{'lat'} );
			$arg = [ $x, $y ];
		}
		push @out, $arg;
	}
	return @out;
}

sub list_cnv2geo {
	my( $self, @in ) = @_;
	my $proj = $self->{_proj};
	my @out;
	foreach my $arg ( @in ){
		if( ref($arg) eq 'ARRAY' && $#{$arg} == 1 ){
			my( $lon, $lat ) = $proj->cnv2geo( $arg->[0], $arg->[1] );
			$arg = OGF::Data::Node->new($self,{'lon' => $lon, 'lat' => $lat});
		}
		push @out, $arg;
	}
	return @out;
}

sub way2points {
	my( $self, $way ) = @_;
	my $proj = $self->{_proj};
	my @points;
	foreach my $nodeId ( @{$way->{'nodes'}} ){
		my $node = $self->{_Node}{$nodeId};
		my( $x, $y ) = $proj->geo2cnv( $node->{'lon'}, $node->{'lat'} );
		push @points, [ $x, $y, $nodeId ];
	}
	return wantarray ? @points : \@points;
}

sub points2way {
	my( $self, $aPoints, $hCache ) = @_;
	my $proj = $self->{_proj};
	my @nodes;
	foreach my $pt ( @$aPoints ){
		my( $x, $y, $nodeId ) = @$pt;
		if( !defined($nodeId) ){
			my( $lon, $lat ) = $proj->cnv2geo( $x, $y );
			my $ptag = $lon .'|'. $lat;
			if( $hCache && $hCache->{$ptag} ){	
				$nodeId = $hCache->{$ptag};
			}else{
				my $node = OGF::Data::Node->new( $self, {'lon' => $lon, 'lat' => $lat} );
				$nodeId = $node->{'id'};
			}
			$hCache->{$ptag} = $nodeId if $hCache;
		}
		push @nodes, $nodeId;
	}
	return wantarray ? @nodes : \@nodes;
}



sub addObject {
	my( $self, $type, $obj ) = @_;
	if( ! $obj->{'id'} ){
		$obj->{'id'} = (-- $self->{_new_ID});
	}elsif( $obj->{'id'} < $self->{_new_ID} ){
		$self->{_new_ID} = $obj->{'id'};
	}
	$self->{'_'.$type}{$obj->{'id'}} = $obj;
	$obj->{'version'} = '' if ! $obj->{'version'};
	$obj->{_context} = $self;
}

#sub getObject {
#	my( $self, $type_or_uid, $id ) = @_;
##	print STDERR "getObject( $type_or_uid, $id )\n";  # _DEBUG_
#	my $obj;
#	if( defined $id ){
#		$obj = $self->{'_'.$type_or_uid}{$id};
#	}else{
#		my( $type, $id ) = split /\|/, $type_or_uid;
#		$type = $OGF::Util::OBJECT_TYPE_MAP{$type};
#		$obj = $self->{'_'.$type}{$id};
#	}
#	exception( qq/Context::getObject: no object found ($type_or_uid/ .($id ? ",$id" : ""). ')' ) if $type_or_uid =~ /^\*/ && ! $obj;
#	return $obj;
#}

sub getObject {
	my( $self, $type_or_uid, $id ) = @_;
#	print STDERR "getObject( $type_or_uid, $id )\n";  # _DEBUG_
	my( $type, $obj );
	if( defined $id ){
		$type = $type_or_uid;
	}else{
		$id = $type_or_uid;
	}
	return $id if ref($id);
	if( $type ){
		$id =~ s/^[NWR]\|//;
	}else{
		( $type, $id ) = split /\|/, $id;
	}
	$type = $OGF::Util::OBJECT_TYPE_MAP{$type};
	$obj = $self->{'_'.$type}{$id};
	exception( qq/Context::getObject: no object found ($type_or_uid/ .($id ? ",$id" : ""). ')' ) if $type_or_uid =~ /^\*/ && ! $obj;
	return $obj;
}

sub getNode {
	my( $self, $id ) = @_;
	return $self->getObject( 'Node', $id );
}

sub getWay {
	my( $self, $id ) = @_;
	return $self->getObject( 'Way', $id );
}

sub getRelation {
	my( $self, $id ) = @_;
	return $self->getObject( 'Relation', $id );
}

sub findNodeForObject {
	my( $self, $obj_or_uid ) = @_;
	my $obj = $self->getObject( $obj_or_uid );
	my $class = $obj->class;
	if( $class eq 'Node' ){
		return $obj;
	}elsif( $class eq 'Way' ){
		return $self->{_Node}{$obj->{'nodes'}[0]};
	}elsif( $class eq 'Relation' ){
		return $obj->findNode( $self );
	}else{
		return undef;
	}
}


sub removeObject {
	my( $self, $obj ) = @_;
#	$self->setReverseInfo() if ! $self->{_rev_info};

	$obj = $self->getObject( $obj ) if ! ref($obj);
	return if ! $obj;

	my( $class, $id, $uid ) = ( $obj->class, $obj->{'id'}, $obj->uid );
#	print STDERR "\$class <", $class, ">  \$id <", $id, ">  \$uid <", $uid, ">\n";  # _DEBUG_
	my $hAffected = {_Way => {}};

	if( $class eq 'Way' ){
		foreach my $nodeUid ( map {"N|$_"} @{$obj->{'nodes'}} ){
#			print STDERR "\$nodeUid <", $nodeUid, ">\n";  # _DEBUG_
			my @otherWays = grep {$_ ne $uid} keys %{$self->{_rev_info}{$nodeUid}};
			if( @otherWays ){
#				print STDERR "removeObject $id: keep node $nodeUid\n";  # _DEBUG_
				delete $self->{_rev_info}{$nodeUid}{$uid};
				map {$hAffected->{_Way}{$_} = 1} @otherWays;
			}else{
#				print STDERR "removeObject $id: delete node $nodeUid\n";  # _DEBUG_
				$self->removeObject( $nodeUid );
			}
		}		
	}

	foreach my $key ( keys %{$self->{_rev_info}{$uid}} ){
		my $obj2 = $self->getObject( $key );
		if( $key =~ /^W/ ){
			@{$obj2->{'nodes'}} = grep {$_ != $id} @{$obj2->{'nodes'}};
		}elsif( $key =~ /^R/ ){
			@{$obj2->{'members'}} = grep {!($_->{'ref'} == $id && $_->{'type'} eq $class)} @{$obj2->{'members'}};
		}
	}

	delete $self->{_rev_info}{$uid};
	delete $self->{'_'.$class}{$id};
	return $hAffected;
}

sub replaceNode {
	my( $self, $node, $nodeR ) = @_;
#	$self->setReverseInfo() if ! $self->{_rev_info};

	$node = $self->getObject( $node ) if ! ref($node);
	my( $id,  $uid  ) = ( $node->{'id'},  $node->uid );
	my( $idR, $uidR ) = ( $nodeR->{'id'}, $nodeR->uid );

	foreach my $key ( keys %{$self->{_rev_info}{$uid}} ){
		my $obj2 = $self->getObject( $key );
		if( $key =~ /^W/ ){
			map {$_ = $idR if $_ == $id} @{$obj2->{'nodes'}};
		}elsif( $key =~ /^R/ ){
			@{$obj2->{'members'}} = grep {!($_->{'ref'} == $id && $_->{'type'} eq 'Node')} @{$obj2->{'members'}};
			map {$_->{'ref'} = $idR if ($_->{'ref'} == $id && $_->{'type'} eq 'Node')} @{$obj2->{'members'}};
		}
	}

	map {$self->{_rev_info}{$uidR}{$_} = $self->{_rev_info}{$uid}{$_}} keys %{$self->{_rev_info}{$uid}};
	delete $self->{_rev_info}{$uid};
	delete $self->{_Node}{$id};
}


sub splitIntersect {
	my( $self, $way, $hOpt ) = @_;
	$self->setReverseInfo() if ! $self->{_rev_info};
	my @nodes = @{$way->{'nodes'}};
	my @inter;
	for( my $i = 0; $i <= $#nodes; ++$i ){
		my $nodeId = $nodes[$i];
		my @ways = keys %{$self->{_rev_info}{"N|$nodeId"}};
		push @inter, $i if scalar(@ways) >= 2;
	}
	if( @inter && !($way->{'nodes'}[0] != $way->{'nodes'}[-1] && $hOpt->{'removeEnds'}) ){
		unshift @inter, 0       unless $inter[0]  == 0;
		push    @inter, $#nodes unless $inter[-1] == $#nodes;
	}
	my $ct = 0;
	for( my $j = 0; $j < $#inter; ++$j ){
		my $wayNew = OGF::Data::Way->new( $self, {'tags' => $way->{'tags'}} );
		$wayNew->{'nodes'} = [ @nodes[$inter[$j] .. $inter[$j+1]] ];
		++$ct;
	}
	delete $self->{_Way}{$way->{'id'}} if $ct > 0;
}

sub geo2cnv {
	my( $self, $lon, $lat ) = @_;
	( $lon, $lat ) = ( $lon->{'lon'}, $lon->{'lat'} ) if ref($lon); 
	my( $x, $y ) = $self->{_proj}->geo2cnv( $lon, $lat );
	return ( $x, $y );
}

sub cnv2geo {
	my( $self, $x, $y ) = @_;
	( $x, $y ) = ( $x->{'x'}, $x->{'y'} ) if ref($x); 
	my( $lon, $lat ) = $self->{_proj}->cnv2geo( $x, $y );
	return ( $lon, $lat );
}

sub setProjection {
	my( $self, $proj ) = @_;
	$self->{_proj} = $proj;
}

sub setReverseInfo {
	my( $self ) = @_;
	$self->{_rev_info} = {} if $self->{_rev_info};

	foreach my $way ( values %{$self->{_Way}} ){
		$self->setReverseInfo_Way( $way );
	}

	foreach my $rel ( values %{$self->{_Relation}} ){
		$self->setReverseInfo_Relation( $rel );
	}
}

sub setReverseInfo_Way {
	my( $self, $way ) = @_;
    my $wayUid = $way->uid;
    foreach my $nodeUid ( map {"N|$_"} @{$way->{'nodes'}} ){
        $self->{_rev_info}{$nodeUid}{$wayUid} = 1;
    }
    my( $nodeS, $nodeE ) = map {'N|'.$way->{'nodes'}[$_]} ( 0, -1 );
    $self->{_rev_info}{$nodeS}{$wayUid} = 'S';
    $self->{_rev_info}{$nodeE}{$wayUid} = ($nodeE eq $nodeS)? 'C' : 'E';
}

sub setReverseInfo_Relation {
	my( $self, $rel ) = @_;
    my $relUid = $rel->uid;
    foreach my $mb ( @{$rel->{'members'}} ){
        my( $type, $role, $mbId ) = ( $mb->{'type'}, $mb->{'role'}, $mb->{'ref'} );
        my $mbUid = substr($type,0,1) .'|'. $mbId;
        $self->{_rev_info}{$mbUid}{$relUid} = 'role';
    }
}

sub addKeyItem {
	my( $obj, $attr, $item ) = @_;
#	print STDERR "addKeyItem( $obj, $attr, $item )\n";  # _DEBUG_
	$obj->{$attr} = [] if ! $obj->{$attr};
	push @{$obj->{$attr}}, $item;
}


sub loadFromFile {
	my( $self, $file, $cProc, $hOpt ) = @_;
	$hOpt = {} if ! $hOpt;
	my $hInfo;
	if( $file =~ /\.ogf(\.gz)?$/ ){
		$hInfo = $self->loadFromOgf( $file, $cProc );
	}elsif( $file =~ /\.pbf$/ ){
		$hInfo = $self->loadFromPbf( $file, $cProc, $hOpt );
	}elsif( $file =~ /\.osm(\.gz)?$/ ){
		$hInfo = $self->loadFromXml( $file, $cProc );
	}else{
		exception( qq/Cannot load "$file": unsupported type suffix\n/ );
	}
	$self->{_source_file} = $file if $hInfo;
	$self->{_source_file} =~ s/\.gz$//;
	return $hInfo;
}

sub loadFromXml {
	require XML::SAX;
	require OGF::Data::XML;
	my( $self, $file, $cProc ) = @_;
	my $startTime = time();

	my %procOpt = $cProc ? ('process' => $cProc) : ();
	my $handler = OGF::Data::XML->new( 'context' => $self, %procOpt );
	my $parser = XML::SAX::ParserFactory->parser( Handler => $handler );

	my $fh = OGF::Util::fileHandle( $file, '<' );
	$parser->parse_file( $fh );

	$self->{_loadTime} = time() - $startTime;

	my $hInfo = $handler->{_OGF_bbox} ? {_bbox => $handler->{_OGF_bbox}} : {};
	return $hInfo;
}


our %PBF_CONVERT_INFO;

sub loadFromPbf {
	my( $self, $file, $cProc, $hOpt ) = @_;
	my $startTime = time();

	my $tmpXmlFile;
	if( ! $PBF_CONVERT_INFO{$file} ){
		$tmpXmlFile = OGF::Util::fileTemp( $file, 'osm' );
		OGF::Util::convertOsmosis( $file, $tmpXmlFile, $hOpt );
		$PBF_CONVERT_INFO{$file} = $tmpXmlFile;
	}else{
		$tmpXmlFile = $PBF_CONVERT_INFO{$file};
	}
	my $hInfo = $self->loadFromXml( $tmpXmlFile, $cProc );

	$self->{_loadTime} = time() - $startTime;
	return $hInfo;
}

sub loadFromOgf {
	my( $self, $file, $cProc ) = @_;
	my $startTime = time();

	my $fh = OGF::Util::fileHandle( $file, '<:encoding(UTF-8)' );

	my $line;
	while( defined($line = OGF::Util::multiLineRead($fh)) ){
		next if $line =~ /^(#|\s*$)/;
		chomp $line;
		$line =~ s/^\x{FEFF}//;  # remove BOM (added by notepad)
#		$line =~ s/^[^\s\w]+//;  # work-around for garbage at file start (hand-edited ogf file)
#		print STDERR "[$.] \$line <", $line, ">\n";  # _DEBUG_
		my $obj = $self->loadObject( $line );
		$cProc->( $obj ) if $cProc;	
	}
	$fh->close();
	$self->{_loadTime} = time() - $startTime;
	return {};
}

sub loadObject {
	my( $self, $str ) = @_;
	$str =~ /^(.)/;
	my $class = 'OGF::Data::' . $OGF::Util::OBJECT_TYPE_MAP{$1};
	my $obj = $class->new( $self, $str );
	return $obj;
}

sub writeToFile {
	require Date::Format;
	my( $self, $file ) = @_;
	$file = $self->{_source_file} if ! $file;
	$file = $OGF::TASKSERVICE_DIR .'/../save/'. Date::Format::time2str('%y%m%d_%H%M%S',time) .'.ogf' if ! $file;
	print STDERR "writeToFile: ", $file, "\n";
	OGF::Util::fileBackup( $file ) if -e $file;
	my $text;
	if( $file =~ /\.ogf$/ ){
		$text = $self->writeToOgf( $file );
	}elsif( $file =~ /\.osm$/ ){
		$text = $self->writeToXml( $file );
	}else{
		exception( qq/Cannot save "$file": unsupported type suffix\n/ );
	}
	return $text;
}

sub writeToXml {
	require Date::Format;
	my( $self, $file ) = @_;
#	print STDERR "OGF::Data::Context::writeToXml: NOT IMPLEMENTED !!!\n";

	my $user = 'thilo';
	my $timeStamp = Date::Format::time2str( '%Y-%m-%dT%H:%M:%S', time() );

	my $text = "";
	$file = \$text if ! defined( $file );
	my $fh = OGF::Util::fileHandle( $file, '>:encoding(UTF-8)' );

	$fh->print( qq|<?xml version='1.0' encoding='UTF-8'?>\n| );
	$fh->print( qq|<osm version="0.6" generator="JOSM">\n| );

	foreach my $node ( map {$self->{_Node}{$_}} sort {$a <=> $b} keys %{$self->{_Node}} ){
        printXmlNode( $fh, $node, $timeStamp, $user );
	}

	foreach my $way ( map {$self->{_Way}{$_}} sort {$a <=> $b} keys %{$self->{_Way}} ){
        printXmlWay( $fh, $way, $timeStamp, $user );
	}

	foreach my $rel ( map {$self->{_Relation}{$_}} sort {$a <=> $b} keys %{$self->{_Relation}} ){
        printXmlRelation( $fh, $rel, $timeStamp, $user );
	}

	$fh->print( "</osm>\n" );
	$fh->close();
	return $text;
}

sub printXmlObject {
    my( $fh, $obj, $timeStamp, $user ) = @_;
    my $class = $obj->class();
    if( $class eq 'Node' ){
        printXmlNode( $fh, $obj, $timeStamp, $user );
    }elsif( $class eq 'Way' ){
        printXmlWay( $fh, $obj, $timeStamp, $user );
    }elsif( $class eq 'Relation' ){
        printXmlRelation( $fh, $obj, $timeStamp, $user );
    }else{
        die qq/Unexpected error: unknown object class "$class"/;
    }
}

sub printXmlNode {
    my( $fh, $node, $timeStamp, $user ) = @_;
    my( $id, $version, $lon, $lat ) = map {$node->{$_}} qw/id version lon lat/;
    my $versionAttr = $version ? qq|version="$version"| : "";
    $fh->print( qq|  <node id="$id" $versionAttr lon="$lon" lat="$lat" visible="true" timestamp="$timeStamp" user="$user">\n| );
    printObjectTags( $fh, $node ) if $node->{'tags'};
    $fh->print( qq|  </node>\n| );
}

sub printXmlWay {
    my( $fh, $way, $timeStamp, $user ) = @_;
    my( $id, $version ) = map {$way->{$_}} qw/id version/;
    my $versionAttr = $version ? qq|version="$version"| : "";
    $fh->print( qq|  <way id="$id" $versionAttr visible="true" timestamp="$timeStamp" user="$user">\n| );
    foreach my $nodeId ( @{$way->{'nodes'}} ){
        $fh->print( qq|    <nd ref="$nodeId"/>\n| );
    }
    printObjectTags( $fh, $way );
    $fh->print( qq|  </way>\n| );
}

sub printXmlRelation {
    my( $fh, $rel, $timeStamp, $user ) = @_;
    my( $id, $version ) = map {$rel->{$_}} qw/id version/;
    my $versionAttr = $version ? qq|version="$version"| : "";
    $fh->print( qq|  <relation id="$id" $versionAttr visible="true" timestamp="$timeStamp" user="$user">\n| );
    foreach my $mb ( @{$rel->{'members'}} ){
        my( $type, $role, $mbId ) = map {$mb->{$_}} qw/type role ref/;
        $type = lc($type);
        $fh->print( qq|    <member type="$type" ref="$mbId" role="$role"/>\n| );
    }
    printObjectTags( $fh, $rel );
    $fh->print( qq|  </relation>\n| );
}

sub printObjectTags {
	my( $fh, $obj ) = @_;
	foreach my $key ( keys %{$obj->{'tags'}} ){
		my $val = $obj->{'tags'}{$key};
		$fh->print( qq|    <tag k="$key" v="$val"/>\n| );
	}
}

sub writeToOgf {
	my( $self, $file ) = @_;
	my $text = "";
	$file = \$text if ! defined( $file );
	my $fh = OGF::Util::fileHandle( $file, '>:encoding(UTF-8)' );
#	foreach my $obj ( values(%{$self->{_Node}}), values(%{$self->{_Way}}), values(%{$self->{_Relation}}) ){
	foreach my $obj ( (map {$self->{_Node}{$_}}     sort {$a <=> $b} keys %{$self->{_Node}}),
					  (map {$self->{_Way}{$_}}      sort {$a <=> $b} keys %{$self->{_Way}}),
					  (map {$self->{_Relation}{$_}} sort {$a <=> $b} keys %{$self->{_Relation}}) ){
		my $line = $obj->toString();
		$line = OGF::Util::multiLineBreak($line,$OGF::DATA_FORMAT_MAXWIDTH) if length($line) > $OGF::DATA_FORMAT_MAXWIDTH;
		$fh->print( $line, "\n" );
	}
	$fh->close();
	return $text;
}

sub removeDuplicateNodes {
	my( $self ) = @_;
	$self->setReverseInfo();

	my %cache;
	foreach my $node ( values %{$self->{_Node}} ){
#		my $ptag = $node->{'lon'} .'|'. $node->{'lat'};
		my $ptag = sprintf( '%.12lf|%.12lf' , $node->{'lon'}, $node->{'lat'} );
		if( $cache{$ptag} ){
			print STDERR "removeDuplicateNodes \$cache{$ptag} <", $cache{$ptag}{'id'}, ">\n";  # _DEBUG_
			if( scalar(keys %{$self->{_rev_info}{$node->uid}}) >= 2 ){
				$self->replaceNode( $node, $cache{$ptag} );
			}else{
				$self->removeObject( $node );
			}
		}else{
			$cache{$ptag} = $node;
		}
	}

	foreach my $way ( values %{$self->{_Way}} ){
		my $n = $#{$way->{'nodes'}};
		for( my $i = 0; $i < $n; ++$i ){
			if( $way->{'nodes'}[$i] == $way->{'nodes'}[$i+1] ){
				$way->{'nodes'}[$i] = undef;
			}
		}
		@{$way->{'nodes'}} = grep {defined} @{$way->{'nodes'}};
	}
}

sub mergeContext {
	my( $self, $other ) = @_;
	my $minId = $self->getMinimumId() - 100;
	my %idMap;

	foreach my $type ( qw/_Node _Way _Relation/ ){
		foreach my $id ( keys %{$other->{$type}} ){
			if( $id < 0 ){
				--$minId;
				$idMap{$type}{$id} = $minId;
				$self->{$type}{$minId} = idMapObject( $other->{$type}{$id}, \%idMap );
			}else{
				$self->{$type}{$id} = idMapObject( $other->{$type}{$id}, \%idMap );
			}
		}
	}
	$self->validateIds();
}

sub idMapObject {
	my( $obj, $hMap ) = @_;
	my( $id, $class ) = ( $obj->{'id'}, '_'.$obj->class );
	$obj->{'id'} = $hMap->{$class}{$id} if $hMap->{$class}{$id};

	if( $obj->{'nodes'} ){
		for( my $i = 0; $i <= $#{$obj->{'nodes'}}; ++$i ){
			my $nodeId = $obj->{'nodes'}[$i];
			$obj->{'nodes'}[$i] = $hMap->{_Node}{$nodeId} if $hMap->{_Node}{$nodeId};
		}
	}

	if( $obj->{'members'} ){
		foreach my $mb ( @{$obj->{'members'}} ){
			my( $mbId, $type ) = ( $mb->{'ref'}, '_'.$mb->{'type'} );
			$mb->{'ref'} = $hMap->{$type}{$mbId} if $hMap->{$type}{$mbId};
		}
	}

	return $obj;
}

sub getMinimumId {
	my( $self ) = @_;
	my $minId = 0;
	foreach my $id ( keys %{$self->{_Node}}, keys %{$self->{_Way}}, keys %{$self->{_Relation}} ){
		$minId = $id if $id < $minId;
	}
	return $minId;
}

sub validateIds {
	my( $self ) = @_;
	foreach my $type ( qw/_Node _Way _Relation/ ){
		foreach my $id ( keys %{$self->{$type}} ){
			die qq/ERROR: Object id != $type key/ if $self->{$type}{$id}{'id'} != $id;
		}
	}
	foreach my $way ( values %{$self->{_Way}} ){
		foreach my $nodeId ( @{$way->{'nodes'}} ){
			die qq/ERROR: way $way->{id} contains unknown node $nodeId/ if ! $self->{_Node}{$nodeId};
		}
	}
	foreach my $rel ( values %{$self->{_Relation}} ){
		foreach my $mb ( @{$rel->{'members'}} ){
			my( $mbId, $type ) = ( $mb->{'ref'}, '_'.$mb->{'type'} );
			die qq/ERROR: relation $rel->{id} contains unknown $type $mbId/ if ! $self->{'_'.$type}{$mbId};
		}
	}
}

sub dummyContext {
	my( $pkg ) = @_;
	return OGF::Data::Context::Dummy->new();
}

sub cloneObject {
	my( $self, $obj ) = @_;
	my $newObj = bless {}, ref($obj);
	$newObj->{'id'} = $obj->{'id'};
	$newObj->{'tags'} = { %{$obj->{'tags'}} } if $obj->{'tags'};
	$newObj->{'nodes'} = [ @{$obj->{'nodes'}} ] if $obj->{'nodes'};
	$newObj->{'members'} = [ map {{%$_}} @{$obj->{'members'}} ] if $obj->{'members'};
	return $newObj;
}

sub cloneContext {
	my( $self, $objType, $hMatch ) = @_;
	$objType = '_' . $objType unless $objType =~ /^_/;

	my $ctx = OGF::Data::Context->new();
	foreach my $type ( qw/_Node _Way _Relation/ ){
		if( $type eq $objType ){
			foreach my $obj ( values %{$self->{$type}} ){
				next unless tagMatch( $obj, $hMatch );
				$ctx->{$type}{$obj->{'id'}} = $ctx->cloneObject( $obj );
			}
		}else{
			$ctx->{_type} = $self->{_type};
		}
	}

	return $ctx;
}

#sub tagMatch {
#	my( $obj, $hMatch ) = @_;
#	my $hTags = $obj->{'tags'};
##	print STDERR "\$hMatch <", ($hMatch ? join('|',%$hMatch) : 'undef'), ">  \$hTags <", ($hTags ? join('|',%$hTags) : 'undef'), ">\n";  # _DEBUG_
#	my $ret = 1;
#	foreach my $attr ( keys %$hMatch ){
#		if( ! defined($hTags->{$attr}) ){
#			$ret = 0;
#		}elsif( ref($hMatch->{$attr}) eq 'ARRAY' ){
#			my $val = $hTags->{$attr};
#			$ret = 0 if ! (grep {$_ eq $val} @{$hMatch->{$attr}});
#		}elsif( $hMatch->{$attr} eq '*' ){
#			# do nothing, any value is OK
#		}else{
#			$ret = 0 if $hTags->{$attr} ne $hMatch->{$attr};
#		}
#	}
##	map {$ret &&= ($hTags->{$_} && $hTags->{$_} eq $hMatch->{$_})} keys %$hMatch;
#	return $ret;
#}

sub tagMatch {
	my( $obj, @match ) = @_;  # returns true if one of @ matches
	my $hTags = $obj->{'tags'};
#	print STDERR "\$hMatch <", ($hMatch ? join('|',%$hMatch) : 'undef'), ">  \$hTags <", ($hTags ? join('|',%$hTags) : 'undef'), ">\n";  # _DEBUG_
	my $ret = 0;
	foreach my $hMatch ( @match ){
        $ret = 1;
        foreach my $attr ( keys %$hMatch ){
            if( ! defined($hTags->{$attr}) ){
                $ret = 0;
            }elsif( ref($hMatch->{$attr}) eq 'ARRAY' ){
                my $val = $hTags->{$attr};
                $ret = 0 if ! (grep {$_ eq $val} @{$hMatch->{$attr}});
            }elsif( $hMatch->{$attr} eq '*' ){
                # do nothing, any value is OK
            }else{
                $ret = 0 if $hTags->{$attr} ne $hMatch->{$attr};
            }
        }
        last if $ret;
    }
#	map {$ret &&= ($hTags->{$_} && $hTags->{$_} eq $hMatch->{$_})} keys %$hMatch;
	return $ret;
}


#-------------------------------------------------------------------------------

sub loadOgfMap {
	my( $pkg, $file, $cProc ) = @_;
	my $startTime = time();

	my $fh = ref($file) ? IO::Scalar->new($file) : FileHandle->new($file,'<');
	if( ! $fh ){
		exception( qq/loadOgfMap: Cannot open "$file": $!\n/ );
		return;
	};

	my %ogfMap;
	my $line;
	while( defined($line = OGF::Util::multiLineRead($fh)) ){
		chomp $line;
		next if $line =~ /^(#|\s*$)/;
		if( $line =~ s/^([NWR]\|-?\d+)\|// ){
			$ogfMap{$1} = $line;		
		}else{
			die qq/Invalid line ($.) in file "$file":\n$line/;
		}
	}
	$fh->close();

#	$self->{_loadTime} = time() - $startTime;
	return \%ogfMap;
}

sub diffOgfMap {
	my( $pkg, $hMap, $file ) = @_;
	
	my $fh = ref($file) ? IO::Scalar->new($file) : FileHandle->new($file,'<');
	if( ! $fh ){
		exception( qq/diffOgfMap: Cannot open "$file": $!\n/ );
		return;
	};

	my %diffMap = ( 'c' => {}, 'u' => {}, 'd' => {}, '#' => {} );
	my $line;
	while( defined($line = OGF::Util::multiLineRead($fh)) ){
		chomp $line;
		next if $line =~ /^(#|\s*$)/;
		if( $line =~ s/^([NWR]\|-?\d+)\|// ){
			my $key = $1;
			if( $hMap->{$key} ){
				if( $hMap->{$key} ne $line ){
#					$fhOut->print( "u ", $key, "|", $line, "\n" );
					mapDiffLine( \%diffMap, $hMap, 'u', $key, $line );
				}
				$hMap->{"|$key"} = delete $hMap->{$key};
			}else{
#				$fhOut->print( "c ", $key, "|", $line, "\n" );
				mapDiffLine( \%diffMap, $hMap, 'c', $key, $line );
			}
		}else{
			die qq/Invalid line ($.) in file "$file":\n$line/;
		}
	}
	$fh->close();

	foreach my $key ( grep {!/^\|/} keys %$hMap ){
#		$fhOut->print( "d ", $key, "|", $hMap->{$key}, "\n" );
		mapDiffLine( \%diffMap, $hMap, 'd', $key, $hMap->{$key} );
	}
	foreach my $key ( keys %{$diffMap{'#'}} ){
		$diffMap{'#'}{$key} = $hMap->{$key} || $hMap->{"|$key"} || $diffMap{'c'}{$key};
	}

#	$self->{_diffTime} = time() - $startTime;
#	use Data::Dumper; local $Data::Dumper::Indent = 1; local $Data::Dumper::Maxdepth = 5; print STDERR Data::Dumper->Dump( [\%diffMap], ['*diffMap'] ), "\n";  # _DEBUG_
	return \%diffMap;
}

sub mapDiffLine {
	my( $hDiff, $hMap, $op, $key, $line ) = @_;
	$hDiff->{$op}{$key} = $line;
	if( $key =~ /^W/ ){
		$line =~ s/^\d+\|//;  # don't interpret version number as nodeId
		my @nodeIds = grep {/^\d+$/} split /\|/, $line;
		map {$hDiff->{'#'}{"N|$_"} = ''} @nodeIds;
	}
}

sub printDiffMap {
	my( $pkg, $hDiffMap, $fileCmd, $fileDrw, $fileXml ) = @_;
	my $fhCmd = FileHandle->new($fileCmd,'>');
	if( ! $fhCmd ){
		exception( qq/diffOgfMap: Cannot open "$fileCmd" for writing: $!\n/ );
		return;
	};
	my $fhDrw = FileHandle->new($fileDrw,'>');
	if( ! $fhDrw ){
		exception( qq/diffOgfMap: Cannot open "$fileDrw" for writing: $!\n/ );
		return;
	};
#	my $fhXml = FileHandle->new($fileXml,'>');
#	if( ! $fhXml ){
#		exception( qq/diffOgfMap: Cannot open "$fileXml" for writing: $!\n/ );
#		return;
#	};

#	my $user = 'thilo';
#	my $timeStamp = Date::Format::time2str( '%Y-%m-%dT%H:%M:%S', time() );

	foreach my $op ( 'c', 'u', 'd', '#' ){
#       $fmXml->print();
		my $hMap = $hDiffMap->{$op};
		my @sr = ($op eq 'd')? qw/R W N/ : qw/N W R/;
		my %sr = map {$sr[$_] => $_} (0..$#sr);
		foreach my $key ( sort {$sr{substr($a,0,1)} <=> $sr{substr($b,0,1)}} keys %$hMap ){
			my $line = $hMap->{$key};
			next if ! $line;
			$line = OGF::Util::multiLineBreak($line,$OGF::DATA_FORMAT_MAXWIDTH) if length($line) > $OGF::DATA_FORMAT_MAXWIDTH;
#			print STDERR "$op \$key <", $key, ">  \$line <", $line, ">\n";  # _DEBUG_
			$fhCmd->print( $op, ' ', $key, '|', $line, "\n" ) unless $op eq '#';
			$fhDrw->print( $key, '|', $line, "\n" );

#			my $obj = $pkg->loadObject( $key .'|'. $line );
#			printXmlObject( $fhXml, $obj, $timeStamp, $user );
		}
#       $fmXml->print();
	}
	$fhCmd->close();
	$fhDrw->close();
#   $fhXml->close();
}

sub diffOgfFiles {
	my( $pkg, $fileOld, $fileNew ) = @_;

	my( $fileCmd, $fileDrw ) = ( $fileNew, $fileNew );
	$fileCmd =~ s/\.(\w+$)/_DIFF.$1/;
	$fileDrw =~ s/\.(\w+$)/_DIFF_DRAW.$1/;

	die qq/File "$fileCmd" already exists./ if -e $fileCmd;
	die qq/File "$fileDrw" already exists./ if -e $fileDrw;

	my $hMap = $pkg->loadOgfMap( $fileOld );
	my $hDiffMap = $pkg->diffOgfMap( $hMap, $fileNew );

	$pkg->printDiffMap( $hDiffMap, $fileCmd, $fileDrw );
}

sub boundingRectangle {
	my( $self, $proj ) = @_;
	$proj = OGF::View::Projection->identity() if ! $proj;
	my( $ct, $xMin, $yMin, $xMax, $yMax ) = ( 0 );

	foreach my $node ( values %{$self->{_Node}} ){
		my( $x, $y ) = $proj->geo2cnv( $node->{'lon'}, $node->{'lat'} );
		( $xMin, $yMin, $xMax, $yMax ) = ( $x, $y, $x, $y ) unless $ct++;
		$xMin = $x if $x < $xMin;
		$xMax = $x if $x > $xMax;
		$yMin = $y if $y < $yMin;
		$yMax = $y if $y > $yMax;
	}
	return [ $xMin, $yMin, $xMax, $yMax ];
}


#-------------------------------------------------------------------------------
package OGF::Data::Context::Dummy;
our @ISA = qw( OGF::Data::Context );

sub addObject {
	# do nothing
}




1;






