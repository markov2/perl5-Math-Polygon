use strict;
use warnings;

package Math::Polygon;
use Math::Polygon::Calc;
use Math::Polygon::Clip;

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

sub string() { polygon_string shift->points }

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

=function area
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

=method perimeter
The length of the line of the polygon.  This can also be used to compute
the length of any line: of the last point is not equal to the first, then
a line is presumed; for a polygon they must match.
Function M<Math::Polygon::Calc::polygon_perimeter()>.

=cut

sub perimeter() { polygon_perimeter shift->points }

=method startMinXY
Returns a new polygon object, where the point with the smallest x coordinate
is at the start (and end, of course).  If more points share the x coordinate,
the smallest y-values will make the final decission.
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
