#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Math::Polygon;

use strict;
use warnings;

# Include all implementations
use Math::Polygon::Calc;
use Math::Polygon::Clip;
use Math::Polygon::Transform;

#--------------------
=chapter NAME

Math::Polygon - Class for maintaining polygon data

=chapter SYNOPSIS

  my $poly = Math::Polygon->new( [1,2], [2,4], [5,7], [1,2] );
  print $poly->nrPoints;
  my @p    = $poly->points;

  my ($xmin, $ymin, $xmax, $ymax) = $poly->bbox;

  my $area   = $poly->area;
  my $l      = $poly->perimeter;
  if($poly->isClockwise) { ... };

  my $rot    = $poly->startMinXY;
  my $center = $poly->centroid;
  if($poly->contains($point)) { ... };

  my $boxed  = $poly->lineClip($xmin, $xmax, $ymin, $ymax);

=chapter DESCRIPTION

This class provides an Object Oriented interface around
Math::Polygon::Calc, Math::Polygon::Clip, and other.  Together,
these modules provide basic transformations on 2D polygons in pure perl.

B<WARNING:> these computations may show platform dependent rounding
differences.  These may also originate from compilation options of
the Perl version you installed.

B<TIP:> When you need better accuracy, you may use Math::BigFloat
as coordinate values.  Of course, this has a considerable price in
performance.

=chapter METHODS

=section Constructors

=ci_method new %options, [@points], %options
You may add %options before and/or after the @points.  You may also use
the "points" option to set the points.  Each point in @points is
(a references) to an ARRAY with two elements: an X and a Y coordinate.

When C<new()> is called as instance method, it is believed that the
new polygon is derived from the callee, and therefore some facts
(like clockwise or anti-clockwise direction) will get copied unless
overruled.

=option  points \@points
=default points undef
See M<points()> and M<nrPoints()>.

=option  clockwise BOOLEAN
=default clockwise undef
Is not specified, it will be computed by the M<isClockwise()> method
on demand.

=option  bbox [$xmin,$ymin, $xmax,$ymax]
=default bbox undef
Usually computed from the shape automatically, but can also be
overruled. See M<bbox()>.

=example creation of new polygon
  my $p = Math::Polygon->new([1,0],[1,1],[0,1],[0,0],[1,0]);

  my @p = ([1,0],[1,1],[0,1],[0,0],[1,0]);
  my $p = Math::Polygon->new(points => \@p);
=cut

sub new(@)
{	my $thing = shift;
	my $class = ref $thing || $thing;

	my @points;
	my %options;
	if(ref $thing)
	{	$options{clockwise} = $thing->{MP_clockwise};
	}

	while(@_)
	{	if(ref $_[0] eq 'ARRAY') { push @points, shift }
		else { my $k = shift; $options{$k} = shift }
	}
	$options{_points} = \@points;

	(bless {}, $class)->init(\%options);
}

sub init($$)
{	my ($self, $args) = @_;
	$self->{MP_points}    = $args->{points} || $args->{_points};
	$self->{MP_clockwise} = $args->{clockwise};
	$self->{MP_bbox}      = $args->{bbox};
	$self;
}

#--------------------
=section Attributes

=method nrPoints
Returns the number of points,
=cut

sub nrPoints() { scalar @{ $_[0]->{MP_points}} }

=method order
Returns the number of (unique?) points: one less than M<nrPoints()>.
=cut

sub order() { @{ $_[0]->{MP_points}} -1 }

=method points [FORMAT]
In LIST context, the points are returned as list, otherwise as
reference to an ARRAY of points.

[1.09] When a FORMAT is given, each coordinate will get processed.
This may be useful to hide platform specific rounding errors.  FORMAT
may be a CODE reference or a C<printf()> alike string.
See M<Math::Polygon::Calc::polygon_format()>.

=example
  my @points = $poly->points;
  my $first  = $points[0];
  my $x0 = $points[0][0];    # == $first->[0]  --> X
  my $y0 = $points[0][1];    # == $first->[1]  --> Y

  my @points = $poly->points("%.2f");
=cut

sub points(;$)
{	my ($self, $format) = @_;
	my $points = $self->{MP_points};
	$points    = [ polygon_format $format, @$points ] if $format;
	wantarray ? @$points : $points;
}

=method point $index, [$index,...]
Returns the point with the specified $index or INDEXES.  In SCALAR context,
only the first $index is used.
=examples
  my $point = $poly->point(2);
  my ($first, $last) = $poly->point(0, -1);
=cut

sub point(@)
{	my $points = shift->{MP_points};
	wantarray ? @{$points}[@_] : $points->[shift];
}

#--------------------
=section Geometry

=method bbox
Returns a list with four elements: (xmin, ymin, xmax, ymax), which describe
the bounding box of the polygon (all points of the polygon are inside that
area).  The computation is expensive, and therefore, the results are
cached.
Function M<Math::Polygon::Calc::polygon_bbox()>.

=example
  my ($xmin, $ymin, $xmax, $ymax) = $poly->bbox;
=cut

sub bbox()
{	my $self = shift;
	return @{$self->{MP_bbox}} if $self->{MP_bbox};

	my @bbox = polygon_bbox $self->points;
	$self->{MP_bbox} = \@bbox;
	@bbox;
}

=method area
Returns the area enclosed by the polygon.  The last point of the list
must be the same as the first to produce a correct result.  The computed
result is cached.
Function M<Math::Polygon::Calc::polygon_area()>.

=example
  my $area = $poly->area;
  print "$area $poly_units ^2\n";
=cut

sub area()
{	my $self = shift;
	return $self->{MP_area} if defined $self->{MP_area};
	$self->{MP_area} = polygon_area $self->points;
}

=method centroid
Returns the centroid location of the polygon.  The last point of the list
must be the same as the first to produce a correct result.  The computed
result is cached.  Function M<Math::Polygon::Calc::polygon_centroid()>.

B<Be aware> that this algorithm does not like very flat polygons.  Also,
small polygons far from the origin (typical in geo applications) will
suffer from rounding errors: translate them to the origin first.

=example
  my $center = $poly->centroid;
  my ($cx, $cy) = @$center;

=cut

sub centroid()
{	my $self = shift;
	$self->{MP_centroid} //= polygon_centroid $self->points;
}

=method isClockwise
The points are (in majority) orded in the direction of the hands of the clock.
This calculation is quite expensive (same effort as calculating the area of
the polygon), and the result is therefore cached.

=example
  if($poly->isClockwise) ...
=cut

sub isClockwise()
{	my $self = shift;
	return $self->{MP_clockwise} if exists $self->{MP_clockwise};
	$self->{MP_clockwise} = polygon_is_clockwise $self->points;
}

=method clockwise
Make sure the points are in clockwise order.

=example
  $poly->clockwise;
=cut

sub clockwise()
{	my $self = shift;
	return $self if $self->isClockwise;

	$self->{MP_points}    = [ reverse $self->points ];
	$self->{MP_clockwise} = 1;
	$self;
}

=method counterClockwise
Make sure the points are in counter-clockwise order.

=example
  $poly->counterClockwise
=cut

sub counterClockwise()
{	my $self = shift;
	$self->isClockwise or return $self;

	$self->{MP_points}    = [ reverse $self->points ];
	$self->{MP_clockwise} = 0;
	$self;
}

=method perimeter
The length of the line of the polygon.  This can also be used to compute
the length of any line: of the last point is not equal to the first, then
a line is presumed; for a polygon they must match.
Function M<Math::Polygon::Calc::polygon_perimeter()>.

=example
  my $fence = $poly->perimeter;
  print "fence length: $fence $poly_units\n"
=cut

sub perimeter() { polygon_perimeter $_[0]->points }

=method startMinXY
Returns a new polygon object, where the points are rotated in such a way
that the point which is losest to the left-bottom point of the bounding
box has become the first.

Function M<Math::Polygon::Calc::polygon_start_minxy()>.
=cut

sub startMinXY()
{	my $self = shift;
	$self->new(polygon_start_minxy $self->points);
}

=method beautify %options
Returns a new, beautified version of this polygon.
Function M<Math::Polygon::Calc::polygon_beautify()>.

Polygons, certainly after some computations, can have a lot of horrible
artifacts: points which are double, spikes, etc.  This functions provided
by this module beautify them.  A new polygon is returned.

=option  remove_spikes BOOLEAN
=default remove_spikes <false>

=cut

sub beautify(@)
{	my ($self, %args) = @_;
	my @beauty = polygon_beautify \%args, $self->points;
	@beauty > 2 ? $self->new(points => \@beauty) : ();
}

=method equal <$other | \@points,[$tolerance]> | $points
Compare two polygons, on the level of points. When the polygons are
the same but rotated, this will return false. See M<same()>.
Function M<Math::Polygon::Calc::polygon_equal()>.

=examples
  if($poly->equal($other_poly, 0.1)) ...
  if($poly->equal(\@points, 0.1)) ...
  if($poly->equal(@points)) ...

=cut

sub equal($;@)
{	my $self  = shift;
	my ($other, $tolerance);
	if(@_ > 2 || ref $_[1] eq 'ARRAY') { $other = \@_ }
	else
	{	$other     = ref $_[0] eq 'ARRAY' ? shift : shift->points;
		$tolerance = shift;
	}
	polygon_equal scalar($self->points), $other, $tolerance;
}

=method same <$other_polygon | \@points, [$tolerance]> | @points
[1.12] Compare two polygons, where the polygons may be rotated or
mirrored wrt each other. This is (much) slower than M<equal()>, but
some algorithms will cause un unpredictable rotation in the result.
Function M<Math::Polygon::Calc::polygon_same()>.

=examples
  if($poly->same($other_poly, 0.1)) ...
  if($poly->same(\@points, 0.1)) ...
  if($poly->same(@points)) ...

=cut

sub same($;@)
{	my $self = shift;
	my ($other, $tolerance);
	if(@_ > 2 || ref $_[1] eq 'ARRAY') { $other = \@_ }
	else
	{	$other     = ref $_[0] eq 'ARRAY' ? shift : shift->points;
		$tolerance = shift;
	}
	polygon_same scalar($self->points), $other, $tolerance;
}

=method contains $point
Returns a truth value indicating whether the point is inside the polygon
or not.  On the edge is inside.
=cut

sub contains($)
{	my ($self, $point) = @_;
	polygon_contains_point($point, $self->points);
}

=method distance $point
[1.05] Returns the distance of the point to the closest point on the border of
the polygon, zero if the point is on an edge.
=cut

sub distance($)
{	my ($self, $point) = @_;
	polygon_distance($point, $self->points);
}

=method isClosed
Returns true if the first point of the poly definition is the same
as the last point.
=cut

sub isClosed() { polygon_is_closed(shift->points) }

#--------------------
=section Transformations

Implemented in Math::Polygon::Transform: changes on the structure of
the polygon except clipping.  All functions return a new polygon object
or undef.

=method resize %options
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

=option  center $point
=default center C<[0,0]>

=cut

sub resize(@)
{	my $self = shift;

	my $clockwise = $self->{MP_clockwise};
	if(defined $clockwise)
	{	my %args   = @_;
		my $xscale = $args{xscale} || $args{scale} || 1;
		my $yscale = $args{yscale} || $args{scale} || 1;
		$clockwise = not $clockwise if $xscale * $yscale < 0;
	}

	(ref $self)->new(
		points    => [ polygon_resize @_, $self->points ],
		clockwise => $clockwise,
		# we could save the bbox calculation as well
	);
}

=method move %options
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
{	my $self = shift;

	(ref $self)->new(
		points    => [ polygon_move @_, $self->points ],
		clockwise => $self->{MP_clockwise},
		bbox      => $self->{MP_bbox},
	);
}

=method rotate %options
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
{	my $self = shift;

	(ref $self)->new(
		points    => [ polygon_rotate @_, $self->points ],
		clockwise => $self->{MP_clockwise},
		# we could save the bbox calculation as well
	);
}

=method grid %options
Returns a polygon object with the points snapped to grid points.
See M<Math::Polygon::Transform::polygon_grid()>.

=option  raster FLOAT
=default raster 1.0
The raster size, which determines the points to round to.  The origin
C<[0,0]> is always on a grid-point.  When the raster value is zero,
no transformation will take place.

=cut

sub grid(@)
{	my $self = shift;

	(ref $self)->new(
		points    => [ polygon_grid @_, $self->points ],
		clockwise => $self->{MP_clockwise},  # probably we could save the bbox calculation as well
	);
}

=method mirror %options
Mirror the polygon in a line.  Only one of the options can be provided.
Some programs call this "flip" or "flop".

=option  x FLOAT
=default x undef
Mirror in the line C<x=value>, which means that P<y> stays unchanged.

=option  y FLOAT
=default y undef
Mirror in the line C<y=value>, which means that P<x> stays unchanged.

=option  rc FLOAT
=default rc undef
Description of the line which is used to mirror in. The line is
C<y= rc*x+b>.  The P<rc> equals C<-dy/dx>, the firing angle.  If
undef is explicitly specified then P<b> is used as constant x: it's
a vertical mirror.

=option  b  FLOAT
=default b  C<0>
Only used in combination with option P<rc> to describe a line.

=option  line [POINT, POINT]
=default line <undef>
Alternative way to specify the mirror line.  The P<rc> and P<b> are
computed from the two points of the line.
=cut

sub mirror(@)
{	my $self = shift;

	my $clockwise = $self->{MP_clockwise};
	$clockwise    = not $clockwise if defined $clockwise;

	(ref $self)->new(
		points    => [ polygon_mirror @_, $self->points ],
		clockwise => $clockwise,
		# we could save the bbox calculation as well
	);
}

=method simplify %options
Returns a polygon object where points are removed.
See M<Math::Polygon::Transform::polygon_simplify()>.

=option  same FLOAT
=default same C<0.0001>
The distance between two points to be considered "the same" point.  The value
is used as radius of the circle.

=option  slope FLOAT
=default slope undef
With three points X(n),X(n+1),X(n+2), the point X(n+1) will be removed if
the length of the path over all three points is less than P<slope> longer
than the direct path between X(n) and X(n+2).

The slope will not be removed around the starting point of the polygon.
Removing points will change the area of the polygon.

=option  max_points INTEGER
=default max_points undef
First, P<same> and P<slope> reduce the number of points.  Then, if there
are still more than the specified number of points left, the points with
the widest angles will be removed until the specified maximum number is
reached.
=cut

sub simplify(@)
{	my $self = shift;

	(ref $self)->new(
		points    => [ polygon_simplify @_, $self->points ],
		clockwise => $self->{MP_clockwise},
		bbox      => $self->{MP_bbox},       # protect bounds
	);
}

#--------------------
=section Clipping

=method lineClip $box
Returned is a list of ARRAYS-OF-POINTS containing line pieces
from the input polygon.
Function M<Math::Polygon::Clip::polygon_line_clip()>.
=cut

sub lineClip($$$$)
{	my ($self, @bbox) = @_;
	polygon_line_clip \@bbox, $self->points;
}

=method fillClip1 $box
Clipping a polygon into rectangles can be done in various ways.
With this algorithm, the parts of the polygon which are outside
the $box are mapped on the borders.  The polygon stays in one piece,
but may have vertices which are followed in two directions.

Returned is one polygon, which is cleaned from double points,
spikes and superfluous intermediate points, or undef when
no polygon is outside the $box.
Function M<Math::Polygon::Clip::polygon_fill_clip1()>.
=cut

sub fillClip1($$$$)
{	my ($self, @bbox) = @_;
	my @clip = polygon_fill_clip1 \@bbox, $self->points;
	@clip ? $self->new(points => \@clip) : undef;
}

#--------------------
=section Display

=method string [FORMAT]
Print the polygon.

[1.09] When a FORMAT is specified, all coordinates will get formatted
first.  This may hide platform dependent rounding differences.

=cut

sub string(;$)
{	my ($self, $format) = @_;
	polygon_string $self->points($format);
}

1;
