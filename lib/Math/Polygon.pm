use strict;
use warnings;

package Math::Polygon;

use Math::Polygon::Calc;
use Math::Polygon::Clip;
use Math::Polygon::Transform;

=chapter NAME

Math::Polygon - Class for maintaining polygon data

=chapter SYNOPSIS

 my $poly = Math::Polygon->new( [1,2], [2,4], [5,7], [1,2] );
 print $poly->nrPoints;
 my @p    = $poly->points;

 my ($xmin, $ymin, $xmax, $ymax) = $poly->bbox;

 my $area = $poly->area;
 my $l    = $poly->perimeter;
 if($poly->isClockwise) { ... };
 
 my $rot  = $poly->startMinXY;

 my $boxed = $poly->lineClip($xmin, $xmax, $ymin, $ymax);

=chapter DESCRIPTION

This class provides an OO interface around M<Math::Polygon::Calc>
and M<Math::Polygon::Clip>.

=chapter METHODS

=section Constructors

=ci_method new [OPTIONS], [POINTS], [OPTIONS]
You may add OPTIONS after and/or before the POINTS.  You may also use
the "points" options to get the points listed.  POINTS are references
to an ARRAY of X and Y.

When C<new> is called as instance method, it is believed that the
new polygon is derived from the callee, and therefore some facts
(like clockwise or anti-clockwise direction) will get copied unless
overruled.

=option  points ARRAY-OF-POINTS
=default points undef
See M<points()> and M<nrPoints()>.

=option  clockwise BOOLEAN
=default clockwise undef
Is not specified, it will be computed by the M<isClockwise()> method
on demand.

=option  bbox ARRAY
=default bbox undef
Usually computed from the figure automatically, but can also be
specified as [xmin,ymin,xmax, ymax].  See M<bbox()>.

=example creation of new polygon
 my $p = Math::Polygon->new([1,0],[1,1],[0,1],[0,0],[1,0]);

 my @p = ([1,0],[1,1],[0,1],[0,0],[1,0]);
 my $p = Math::Polygon->new(points => \@p);
=cut

sub new(@)
{   my $thing = shift;
    my $class = ref $thing || $thing;

    my @points;
    my %options;
    if(ref $thing)
    {   $options{clockwise} = $thing->{MP_clockwise};
    }

    while(@_)
    {   if(ref $_[0] eq 'ARRAY') {push @points, shift}
        else { my $k = shift; $options{$k} = shift }
    }
    $options{_points} = \@points;

    (bless {}, $class)->init(\%options);
}

sub init($$)
{   my ($self, $args) = @_;
    $self->{MP_points}    = $args->{points} || $args->{_points};
    $self->{MP_clockwise} = $args->{clockwise};
    $self->{MP_bbox}      = $args->{bbox};
    $self;
}

=section Attributes

=method nrPoints
Returns the number of points,
=cut

sub nrPoints() { scalar @{shift->{MP_points}} }

=method order
Returns the number of uniqe points: one less than M<nrPoints()>.
=cut

sub order() { @{shift->{MP_points}} -1 }

=method points
In LIST context, the points are returned as list, otherwise as
reference to an ARRAY.
=cut

sub points() { wantarray ? @{shift->{MP_points}} : shift->{MP_points} }

=method point INDEX, [INDEX, ...]
Returns the point with the specified INDEX or INDEXES.  In SCALAR context,
only the first INDEX is used.
=cut

sub point(@)
{   my $points = shift->{MP_points};
    wantarray ? @{$points}[@_] : $points->[shift];
}

=section Simple calculations

=method string 
=cut

sub string() { polygon_string(shift->points) }

=method bbox
Returns a list with four elements: (xmin, ymin, xmax, ymax), which describe
the bounding box of the polygon (all points of the polygon are inside that
area).  The computation is expensive, and therefore, the results are
cached.
Function M<Math::Polygon::Calc::polygon_bbox()>.
=cut

sub bbox()
{   my $self = shift;
    return @{$self->{MP_bbox}} if $self->{MP_bbox};

    my @bbox = polygon_bbox $self->points;
    $self->{MP_bbox} = \@bbox;
}

=method area
Returns the area enclosed by the polygon.  The last point of the list
must be the same as the first to produce a correct result.  The computed
result is cached.
Function M<Math::Polygon::Calc::polygon_area()>.

=cut

sub area()
{   my $self = shift;
    return $self->{MP_area} if defined $self->{MP_area};
    $self->{MP_area} = polygon_area $self->points;
}

=method isClockwise
The points are (in majority) orded in the direction of the hands of the clock.
This calculation is quite expensive (same effort as calculating the area of
the polygon), and the result is therefore cached.
=cut

sub isClockwise()
{   my $self = shift;
    return $self->{MP_clockwise} if defined $self->{MP_clockwise};
    $self->{MP_clockwise} = polygon_is_clockwise $self->points;
}

=method clockwise
Make sure the points are in clockwise order.
=cut

sub clockwise()
{   my $self = shift;
    return $self if $self->isClockwise;

    $self->{MP_points}    = [ reverse $self->points ];
    $self->{MP_clockwise} = 1;
    $self;
}

=method counterClockwise
Make sure the points are in counter-clockwise order.
=cut

sub counterClockwise()
{   my $self = shift;
    return $self unless $self->isClockwise;

    $self->{MP_points}    = [ reverse $self->points ];
    $self->{MP_clockwise} = 0;
    $self;
}

=method perimeter
The length of the line of the polygon.  This can also be used to compute
the length of any line: of the last point is not equal to the first, then
a line is presumed; for a polygon they must match.
Function M<Math::Polygon::Calc::polygon_perimeter()>.

=cut

sub perimeter() { polygon_perimeter shift->points }

=method startMinXY
Returns a new polygon object, where the points are rotated in such a way
that the point which is losest to the left-bottom point of the bouding
box has become the first.

Function M<Math::Polygon::Calc::polygon_start_minxy()>.
=cut

sub startMinXY()
{   my $self = shift;
    $self->new(polygon_start_minxy $self->points);
}

=method beautify OPTIONS
Returns a new, beautified version of this polygon.
Function M<Math::Polygon::Calc::polygon_beautify()>.

Polygons, certainly after some computations, can have a lot of
horrible artifacts: points which are double, spikes, etc.  This
functions provided by this module beautify

=option  remove_spikes BOOLEAN
=default remove_spikes <false>

=cut

sub beautify(@)
{   my ($self, %opts) = @_;
    my @beauty = polygon_beautify \%opts, $self->points;
    @beauty>2 ? $self->new(points => \@beauty) : ();
}

=method equal (OTHER|ARRAY, [TOLERANCE])|POINTS
Compare two polygons, on the level of points. When the polygons are
the same but rotated, this will return false. See M<same()>.
Function M<Math::Polygon::Calc::polygon_equal()>.
=cut

sub equal($;@)
{   my $self  = shift;
    my ($other, $tolerance);
    if(@_ > 2 || ref $_[1] eq 'ARRAY') { $other = \@_ }
    else
    {   $other     = ref $_[0] eq 'ARRAY' ? shift : shift->points;
        $tolerance = shift;
    }
    polygon_equal scalar($self->points), $other, $tolerance;
}

=method same (OTHER|ARRAY, [TOLERANCE])|POINTS
Compare two polygons, where the polygons may be rotated wrt each
other. This is (much) slower than M<equal()>, but some algorithms
will cause un unpredictable rotation in the result.
Function M<Math::Polygon::Calc::polygon_same()>.
=cut

sub same($;@)
{   my $self = shift;
    my ($other, $tolerance);
    if(@_ > 2 || ref $_[1] eq 'ARRAY') { $other = \@_ }
    else
    {   $other     = ref $_[0] eq 'ARRAY' ? shift : shift->points;
        $tolerance = shift;
    }
    polygon_same scalar($self->points), $other, $tolerance;
}

=method contains POINT
Returns a truth value indicating whether the point is inside the polygon
or not.  On the edge is inside.
=cut

sub contains($)
{   my ($self, $point) = @_;
    polygon_contains_point($point, shift->points);
}

=section Transformations

Implemented in M<Math::Polygon::Transform>: changes on the structure of
the polygon except clipping.  All functions return a new polygon object
or undef.

=method resize OPTIONS
Returns a resized polygon object.
See M<Math::Polygon::Transform::polygon_resize()>.

=option  scale FLOAT
=default scale C<1.0>
Resize the polygon with the indicated factor.  When the factor is larger
than 1, the resulting polygon with grow, when small it will be reduced in
size.  The scale will be respective from the center.

=option  xscale FLOAT
=default xscale <scale>
Specific scaling factor in the horizontal direction.

=option  yscale FLOAT
=default yscale <scale>
Specific scaling factor in the vertical direction.

=option  center POINT
=default center C<[0,0]>

=cut

sub resize(@)
{   my $self = shift;

    my $clockwise = $self->{MP_clockwise};
    if(defined $clockwise)
    {   my %args   = @_;
        my $xscale = $args{xscale} || $args{scale} || 1;
        my $yscale = $args{yscale} || $args{scale} || 1;
        $clockwise = not $clockwise if $xscale * $yscale < 0;
    }

    (ref $self)->new
       ( points    => [ polygon_resize @_, $self->points ]
       , clockwise => $clockwise
       # we could save the bbox calculation as well
       );
}

=method move OPTIONS
Returns a moved polygon object: all point are moved over the
indicated distance.  See M<Math::Polygon::Transform::polygon_move()>.

=option  dx FLOAT
=default dx 0
Displacement in the horizontal direction.

=option  dy FLOAT
=default dy 0
Displacement in the vertical direction.

=cut

sub move(@)
{   my $self = shift;

    (ref $self)->new
       ( points    => [ polygon_move @_, $self->points ]
       , clockwise => $self->{MP_clockwise}
       , bbox      => $self->{MP_bbox}
       );
}

=method rotate OPTIONS
Returns a rotated polygon object: all point are moved over the
indicated distance.  See M<Math::Polygon::Transform::polygon_rotate()>.

=option  degrees FLOAT
=default degrees 0
specify rotation angle in degrees (between -180 and 360).

=option  radians FLOAT
=default radians 0
specify rotation angle in rads (between -pi and 2*pi)

=option  center  POINT
=default center  C<[0,0]>

=cut

sub rotate(@)
{   my $self = shift;

    (ref $self)->new
       ( points    => [ polygon_rotate @_, $self->points ]
       , clockwise => $self->{MP_clockwise}
       # we could save the bbox calculation as well
       );
}

=method grid OPTIONS
Returns a polygon object with the points snapped to grid points.
See M<Math::Polygon::Transform::polygon_grid()>.

=option  raster FLOAT
=default raster 1.0
The raster size, which determines the points to round to.  The origin
C<[0,0]> is always on a grid-point.  When the raster value is zero,
no transformation will take place.

=cut

sub grid(@)
{   my $self = shift;

    (ref $self)->new
       ( points    => [ polygon_grid @_, $self->points ]
       , clockwise => $self->{MP_clockwise}  # probably
       # we could save the bbox calculation as well
       );
}

=method mirror OPTIONS
Mirror the polygon in a line.  Only one of the options can be provided.
Some programs call this "flip" or "flop".

=option  x FLOAT
=default x C<undef>
Mirror in the line C<x=value>, which means that C<y> stays unchanged.

=option  y FLOAT
=default y C<undef>
Mirror in the line C<y=value>, which means that C<x> stays unchanged.

=option  rc FLOAT
=default rc C<undef>
Description of the line which is used to mirror in. The line is
C<y= rc*x+b>.  The C<rc> equals C<-dy/dx>, the firing angle.  If
C<undef> is explicitly specified then C<b> is used as constant x: it's
a vertical mirror.

=option  b  FLOAT
=default b  C<0>
Only used in combination with option C<rc> to describe a line.

=option  line [POINT, POINT]
=default line <undef>
Alternative way to specify the mirror line.  The C<rc> and C<b> are
computed from the two points of the line.
=cut

sub mirror(@)
{   my $self = shift;

    my $clockwise = $self->{MP_clockwise};
    $clockwise    = not $clockwise if defined $clockwise;

    (ref $self)->new
       ( points    => [ polygon_grid @_, $self->points ]
       , clockwise => $clockwise
       # we could save the bbox calculation as well
       );
}

=method simplify OPTIONS
Returns a polygon object where points are removed.
See M<Math::Polygon::Transform::polygon_simplify()>.

=option  same FLOAT
=default same C<0.0001>
The distance between two points to be considered "the same" point.  The value
is used as radius of the circle.

=option  slope FLOAT
=default slope C<undef>
With three points X(n),X(n+1),X(n+2), the point X(n+1) will be removed if
the length of the path over all three points is less than C<slope> longer
than the direct path between X(n) and X(n+2).

The slope will not be removed around the starting point of the polygon.
Removing points will change the area of the polygon.

=option  max_points INTEGER
=default max_points C<undef>
First, C<same> and C<slope> reduce the number of points.  Then, if there
are still more than the specified number of points left, the points with
the widest angles will be removed until the specified maximum number is
reached.
=cut

sub simplify(@)
{   my $self = shift;

    (ref $self)->new
       ( points    => [ polygon_simplify @_, $self->points ]
       , clockwise => $self->{MP_clockwise}  # probably
       , bbox      => $self->{MP_bbox}       # protect bounds
       );
}

=section Clipping

=method lineClip BOX
Returned is a list of ARRAYS-OF-POINTS containing line pieces
from the input polygon.
Function M<Math::Polygon::Clip::polygon_line_clip()>.
=cut

sub lineClip($$$$)
{   my ($self, @bbox) = @_;
    polygon_line_clip \@bbox, $self->points;
}

=method fillClip1 BOX
Clipping a polygon into rectangles can be done in various ways.
With this algorithm, the parts of the polygon which are outside
the BOX are mapped on the borders.  The polygon stays in one piece,
but may have vertices which are followed in two directions.

Returned is one polygon, which is cleaned from double points,
spikes and superfluous intermediate points, or undef.
=cut

sub fillClip1($$$$)
{   my ($self, @bbox) = @_;
    my @clip = polygon_fill_clip1 \@bbox, $self->points;
    $self->new(points => \@clip);
}

1;
