use strict;
use warnings;

package Math::Polygon::Surface;
use Math::Polygon;

=chapter NAME

Math::Polygon::Surface - Polygon with exclusions

=chapter SYNOPSIS

 my $outer   = Math::Polygon->new( [1,2], [2,4], [5,7], [1,2] );
 my $surface = Math::Polygon::Surface->new($outer);

=chapter DESCRIPTION

A surface is one polygon which represents the outer bounds of an
array, plus optionally a list of polygons which represent exclusions
from that outer polygon.

=chapter METHODS

=section Constructors

=ci_method new [OPTIONS], [POLYGONS], [OPTIONS]
You may add OPTIONS after and/or before the POLYGONS.  You may also use
the "outer" and "inner" options.  POLYGONS are references to ARRAYs of points,
each an ARRAY of X and Y, but better instantiated M<Math::Polygon> objects.

=option  outer POLYGON
=default outer undef
The outer polygon, a M<Math::Polygon>.

=option  inner ARRAY-OF-POLYGONS
=default inner []
The inner polygons, zero or more M<Math::Polygon> objects.

=error Surface requires outer polygon
=cut

sub new(@)
{   my $thing = shift;
    my $class = ref $thing || $thing;

    my @poly;
    my %options;

    while(@_)
    {   if(!ref $_[0]) { my $k = shift; $options{$k} = shift }
        elsif(ref $_[0] eq 'ARRAY')        {push @poly, shift}
        elsif($_[0]->isa('Math::Polygon')) {push @poly, shift}
        else { die "Illegal argument $_[0]" }
    }

    $options{_poly} = \@poly if @poly;
    (bless {}, $class)->init(\%options);
}

sub init($$)
{   my ($self, $args)  = @_;
    my ($outer, @inner);

    if($args->{_poly})
    {   ($outer, @inner) = @{$args->{_poly}};
    }
    else
    {   $outer = $args->{outer}
            or die "ERROR: Surface requires outer polygon\n";

        @inner = @{$args->{inner}} if defined $args->{inner};
    }

    foreach ($outer, @inner)
    {  next unless ref $_ eq 'ARRAY';
       $_ = Math::Polygon->new(points => $_);
    }

    $self->{MS_outer} = $outer;
    $self->{MS_inner} = \@inner;
    $self;
}

=section Attributes

=method outer
Returns the outer polygon.
=cut

sub outer() { shift->{MS_outer} }

=method inner
Returns a list (often empty) of inner polygons.
=cut

sub inner() { @{shift->{MS_inner}} }

=section Simple calculations

=method bbox
Returns a list with four elements: (xmin, ymin, xmax, ymax), which describe
the bounding box of the surface, which is the bbox of the outer polygon.
See method M<Math::Polygon::bbox()>.
=cut

sub bbox() { shift->outer->bbox }

=function area
Returns the area enclosed by the outer polygon, minus the areas of the
inner polygons.
See method M<Math::Polygon::area()>.

=cut

sub area()
{   my $self = shift;
    my $area = $self->outer->area;
    $area   -= $_->area for $self->inner;
    $area;
}

=method perimeter
The length of the border: sums outer and inner perimeters.
See method M<Math::Polygon::perimeter()>.

=cut

sub perimeter()
{   my $self = shift;
    my $per  = $self->outer->perimeter;
    $per    += $_->perimeter for $self->inner;
    $per;
}

=section Clipping

=method lineClip BOX
Returned is a list of ARRAYS-OF-POINTS containing line pieces
from the input surface.  Lines from outer and inner polygons are
undistinguishable.
See method M<Math::Polygon::lineClip()>.
=cut

sub lineClip($$$$)
{   my ($self, @bbox) = @_;
    map { $_->lineClip(@bbox) } $self->outer, $self->inner;
}

=method fillClip1 BOX
Clipping a polygon into rectangles can be done in various ways.
With this algorithm, the parts of the polygon which are outside
the BOX are mapped on the borders.

All polygons are treated separately.
=cut

sub fillClip1($$$$)
{   my ($self, @bbox) = @_;
    my $outer = $self->outer->fillClip1(@bbox);
    return () unless defined $outer;

    $self->new
      ( outer => $outer
      , inner => [ map {$_->fillClip1(@bbox)} $self->inner ]
      );
}

1;
