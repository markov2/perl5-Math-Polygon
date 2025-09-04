#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Math::Polygon::Calc;
use parent 'Exporter';

use strict;
use warnings;

use Log::Report   'math-polygon';
use List::Util    qw/min max/;
use Scalar::Util  qw/blessed/;

our @EXPORT = qw/
	polygon_area
	polygon_bbox
	polygon_beautify
	polygon_centroid
	polygon_clockwise
	polygon_contains_point
	polygon_counter_clockwise
	polygon_distance
	polygon_equal
	polygon_is_clockwise
	polygon_is_closed
	polygon_perimeter
	polygon_same
	polygon_start_minxy
	polygon_string
	polygon_format
/;

sub polygon_is_closed(@);

#--------------------
=chapter NAME

Math::Polygon::Calc - Simple polygon calculations

=chapter SYNOPSIS

  my @poly = ( [1,2], [2,4], [5,7], [1,2] );

  my ($xmin, $ymin, $xmax, $ymax) = polygon_bbox @poly;

  my $area = polygon_area @poly;
  MY $L    = polygon_perimeter @poly;
  if(polygon_is_clockwise @poly) { ... };

  my @rot  = polygon_start_minxy @poly;

  # The OO interface simplifies access:
  my $poly = Math::Polygon->new(1,2], [2,4], [5,7], [1,2]);
  my @box  = $poly->box;
  my $area = $poly->area;
  if($poly->isClockwise) { ... }

=chapter DESCRIPTION

This package contains a wide variaty of relatively easy polygon
calculations.  More complex calculations are put in separate
packages.

=chapter FUNCTIONS

=function polygon_string @points
=cut

sub polygon_string(@) { join ', ', map "[$_->[0],$_->[1]]", @_ }

=function polygon_bbox @points
Returns a list with four elements: (xmin, ymin, xmax, ymax), which describe
the bounding box of the polygon (all points of the polygon are within that
area.
=cut

sub polygon_bbox(@)
{
	(	min( map $_->[0], @_ ),
		min( map $_->[1], @_ ),
		max( map $_->[0], @_ ),
		max( map $_->[1], @_ )
	);
}

=function polygon_area @points
Returns the area enclosed by the polygon.  The last point of the list
must be the same as the first to produce a correct result.

The algorithm was found at L<https://mathworld.wolfram.com/PolygonArea.html>,
and sounds:

  A = abs( 1/2 * (x1y2-x2y1 + x2y3-x3y2 ...)

=cut

sub polygon_area(@)
{	my $area    = 0;
	while(@_ >= 2)
	{	$area += $_[0][0]*$_[1][1] - $_[0][1]*$_[1][0];
		shift;
	}

	abs($area)/2;
}

=function polygon_is_clockwise @points
=cut

sub polygon_is_clockwise(@)
{	my $area  = 0;

	polygon_is_closed(@_)
		or error __"polygon must be closed: begin==end";

	while(@_ >= 2)
	{	$area += $_[0][0]*$_[1][1] - $_[0][1]*$_[1][0];
		shift;
	}

	$area < 0;
}

=function polygon_clockwise @points
Be sure the polygon points are in clockwise order.
=cut

sub polygon_clockwise(@)
{	polygon_is_clockwise(@_) ? @_ : reverse @_;
}

=function polygon_counter_clockwise @points
Be sure the polygon points are in counter-clockwise order.
=cut

sub polygon_counter_clockwise(@)
{	polygon_is_clockwise(@_) ? reverse(@_) : @_;
}


=function polygon_perimeter @points
The length of the line of the polygon.  This can also be used to compute
the length of any line: of the last point is not equal to the first, then
a line is presumed; for a polygon they must match.

This is simply Pythagoras.

  $l = sqrt((x1-x0)^2 + (y1-y0)^2) + sqrt((x2-x1)^2+(y2-y1)^2) + ...

=cut

sub polygon_perimeter(@)
{	my $l    = 0;

	while(@_ >= 2)
	{	$l += sqrt(($_[0][0]-$_[1][0])**2 + ($_[0][1]-$_[1][1])**2);
		shift;
	}

	$l;
}

=function polygon_start_minxy @points
Returns the polygon, where the point which is closest to the left-bottom
corner of the bounding box is made first.
=cut

sub polygon_start_minxy(@)
{	return @_ if @_ <= 1;
	my $ring  = $_[0][0]==$_[-1][0] && $_[0][1]==$_[-1][1];
	pop @_ if $ring;

	my ($xmin, $ymin) = polygon_bbox @_;

	my $rot   = 0;
	my $dmin_sq = ($_[0][0]-$xmin)**2 + ($_[0][1]-$ymin)**2;

	for(my $i=1; $i<@_; $i++)
	{	next if $_[$i][0] - $xmin > $dmin_sq;

		my $d_sq = ($_[$i][0]-$xmin)**2 + ($_[$i][1]-$ymin)**2;
		if($d_sq < $dmin_sq)
		{	$dmin_sq = $d_sq;
			$rot     = $i;
		}
	}

	$rot==0 ? (@_, ($ring ? $_[0] : ())) : (@_[$rot..$#_], @_[0..$rot-1], ($ring ? $_[$rot] : ()));
}

=function polygon_beautify [%options|\%options], @points
Polygons, certainly after some computations, can have a lot of
horrible artifacts: points which are double, spikes, etc.

=option  remove_spikes BOOLEAN
=default remove_spikes <false>
Spikes contain of three successive points, where the first is on the
line between the second and the third.  The line goes from first to
second, but then back to get to the third point.

At the moment, only pure horizontal and pure vertical spikes are
removed.

=cut

sub polygon_beautify(@)
{	my $args;
	if(ref $_[0] eq 'HASH') { $args = shift }
	else
	{	while(@_ && !ref $_[0])
		{	my $key       = shift;
			$args->{$key} = shift;
		}
	}

	@_ or return ();

	my $despike  = exists $args->{remove_spikes} ? $args->{remove_spikes}  : 0;

	my @res      = @_;
	return () if @res < 4;  # closed triangle = 4 points
	pop @res;               # cyclic: last is first
	my $unchanged= 0;

	while($unchanged < 2*@res)
	{	return () if @res < 3;  # closed triangle = 4 points

		my $this = shift @res;
		push @res, $this;         # recycle
		$unchanged++;

		# remove doubles
		my ($x, $y) = @$this;
		while(@res && $res[0][0]==$x && $res[0][1]==$y)
		{	$unchanged = 0;
			shift @res;
		}

		# remove spike
		if($despike && @res >= 2)
		{	# any spike
			if($res[1][0]==$x && $res[1][1]==$y)
			{	$unchanged = 0;
				shift @res;
			}

			# x-spike
			if($y==$res[0][1] && $y==$res[1][1]
				&& (($res[0][0] < $x && $x < $res[1][0]) || ($res[0][0] > $x && $x > $res[1][0])))
			{	$unchanged = 0;
				shift @res;
			}

			# y-spike
			if(   $x==$res[0][0] && $x==$res[1][0]
				&& (($res[0][1] < $y && $y < $res[1][1]) || ($res[0][1] > $y && $y > $res[1][1])))
			{	$unchanged = 0;
				shift @res;
			}
		}

		# remove intermediate
		if(   @res >= 2
			&& $res[0][0]==$x && $res[1][0]==$x
			&& (($y < $res[0][1] && $res[0][1] < $res[1][1]) || ($y > $res[0][1] && $res[0][1] > $res[1][1])))
		{	$unchanged = 0;
			shift @res;
		}

		if(   @res >= 2
			&& $res[0][1]==$y && $res[1][1]==$y
			&& (($x < $res[0][0] && $res[0][0] < $res[1][0]) || ($x > $res[0][0] && $res[0][0] > $res[1][0])))
		{	$unchanged = 0;
			shift @res;
		}

		# remove 2 out-of order between two which stay
		if(@res >= 3
			&& $x==$res[0][0] && $x==$res[1][0] && $x==$res[2][0]
			&& ($y < $res[0][1] && $y < $res[1][1] && $res[0][1] < $res[2][1] && $res[1][1] < $res[2][1]))
		{	$unchanged = 0;
			splice @res, 0, 2;
		}

		if(@res >= 3
			&& $y==$res[0][1] && $y==$res[1][1] && $y==$res[2][1]
			&& ($x < $res[0][0] && $x < $res[1][0] && $res[0][0] < $res[2][0] && $res[1][0] < $res[2][0]))
		{	$unchanged = 0;
			splice @res, 0, 2;
		}
	}

	@res ? (@res, $res[0]) : ();
}

=function polygon_equal \@points1, \@points2, [$tolerance]
Compare two polygons, on the level of points. When the polygons are
the same but rotated, this will return false. See M<polygon_same()>.
=cut

sub polygon_equal($$;$)
{	my  ($f,$s, $tolerance) = @_;
	return 0 if @$f != @$s;

	my @f = @$f;
	my @s = @$s;

	if(defined $tolerance)
	{	while(@f)
		{	return 0 if abs($f[0][0]-$s[0][0]) > $tolerance || abs($f[0][1]-$s[0][1]) > $tolerance;
			shift @f; shift @s;
		}
		return 1;
	}

	while(@f)
	{	return 0 if $f[0][0] != $s[0][0] || $f[0][1] != $s[0][1];
		shift @f; shift @s;
	}

	1;
}

=function polygon_same \@points1, \@points2, [$tolerance]
[1.12] Compare two polygons, where the polygons may be rotated or mirrored
wrt each other. This is (much) slower than M<polygon_equal()>, but some
algorithms will cause un unpredictable rotation in the result.
=cut

sub polygon_same($$;$)
{	return 0 if @{$_[0]} != @{$_[1]};
	my @f = polygon_start_minxy polygon_clockwise @{ (shift) };
	my @s = polygon_start_minxy polygon_clockwise @{ (shift) };
	polygon_equal \@f, \@s, $_[0];
}

=function polygon_contains_point $point, @points
Returns true if the point is inside the closed polygon.  On an edge will
be flagged as 'inside'.  But be warned of rounding issues, caused by
the floating-point calculations used by this algorithm.
=cut

# Algorithms can be found at
# http://www.eecs.umich.edu/courses/eecs380/HANDOUTS/PROJ2/InsidePoly.html
# p1 = polygon[0];
# for (i=1;i<=N;i++) {
#   p2 = polygon[i % N];
#   if (p.y > MIN(p1.y,p2.y)) {
#     if (p.y <= MAX(p1.y,p2.y)) {
#       if (p.x <= MAX(p1.x,p2.x)) {
#         if (p1.y != p2.y) {
#           xinters = (p.y-p1.y)*(p2.x-p1.x)/(p2.y-p1.y)+p1.x;
#           if (p1.x == p2.x || p.x <= xinters)
#             counter++;
#         }
#       }
#     }
#   }
#   p1 = p2;
# }
# inside = counter % 2;

sub polygon_contains_point($@)
{	my $point = shift;
	return 0 if @_ < 3;

	my ($x, $y) = @$point;
	my $inside  = 0;

	polygon_is_closed(@_)
		or error __"polygon must be closed: begin==end";

	my ($px, $py) = @{ (shift) };

	while(@_)
	{	my ($nx, $ny) = @{ (shift) };

		# Extra check for exactly on the edge when the axes are
		# horizontal or vertical.
		return 1 if $y==$py && $py==$ny
				&& ($x >= $px || $x >= $nx)
				&& ($x <= $px || $x <= $nx);

		return 1 if $x==$px && $px==$nx
				&& ($y >= $py || $y >= $ny)
				&& ($y <= $py || $y <= $ny);

		if(   $py == $ny
			|| ($y <= $py && $y <= $ny)
			|| ($y >  $py && $y >  $ny)
			|| ($x >  $px && $x >  $nx)
		)
		{
			($px, $py) = ($nx, $ny);
			next;
		}

		# side wrt diagonal
		my $xinters = ($y-$py)*($nx-$px)/($ny-$py)+$px;
		$inside = !$inside
			if $px==$nx || $x <= $xinters;

		($px, $py) = ($nx, $ny);
	}

	$inside;
}

=function polygon_centroid [%options|\%options], @points
Returns the centroid location of the polygon.

The last point of the list must be the same as the first (must be
'closed') to produce a correct result.

B<warning:> When the polygon is very flat, it will not produce a
stable result: minor changes in single coordinates will move the
centroid too far.

The algorithm was found at
L<https://en.wikipedia.org/wiki/Centroid#Of_a_polygon>

=option  is_large BOOLEAN
=default is_large false
When the polygon is small and far from the origin C<(0,0)> (as often
happens when processing geo coordinates), then rounding errors will have a
large impact on result of the algorithm.  To avoid this, we will move the
poly first close to the origin, and move the calculated center point back.

This transform, which cost modest performance, can be disabled with
this option.  The transformation will also not happen when the first
C<x> coordinate is an object, like Math::BigFloat.

=error polygon points on a line, so no centroid
=cut

sub polygon_centroid(@)
{	my $args;
	if(ref $_[0] eq 'HASH') { $args = shift }
	else
	{	while(@_ && !ref $_[0])
		{	my $key       = shift;
			$args->{$key} = shift;
		}
	}

	polygon_is_closed @_
		or error __"polygon must be closed: begin==end";

	return [ ($_[0][0] + $_[1][0])/2, ($_[0][1] + $_[1][1])/2 ]
		if @_==3;  # line

	my $correct   = exists $args->{is_large} ? $args->{is_large} : blessed($_[0][0]);
	my ($mx, $my) = $correct ? (0, 0) : @{$_[0]};
	my $do_move   = $mx != 0 || $my != 0;

	@_ = map [ $_->[0] - $mx, $_->[1] - $my ], @_
		if $do_move;

	my ($cx, $cy, $a) = (0, 0, 0);
	foreach my $i (0..@_-2)
	{	my $ap =   $_[$i][0] * $_[$i+1][1] - $_[$i+1][0] * $_[$i][1];
		$cx   += ( $_[$i][0] + $_[$i+1][0] ) * $ap;
		$cy   += ( $_[$i][1] + $_[$i+1][1] ) * $ap;
		$a    += $ap;
	}

	$a != 0
		or error __"polygon points on a line, so no centroid";

	my $c = 3*$a; # 6*$a/2;
	$do_move ? [ $cx/$c + $mx, $cy/$c + $my ] : [ $cx/$c, $cy/$c ];
}

=function polygon_is_closed @points
=error empty polygon is neither closed nor open
=cut

sub polygon_is_closed(@)
{	@_ or error __"empty polygon is neither closed nor open";

	my ($first, $last) = @_[0,-1];
	$first->[0]==$last->[0] && $first->[1]==$last->[1];
}

=function polygon_distance $point, @polygon
[1.05] calculate the shortest distance between a point and any vertex of
a closed polygon.
=cut

# Contributed by Andreas Koenig for 1.05
# http://stackoverflow.com/questions/10983872/distance-from-a-point-to-a-polygon#10984080
# with correction from
# http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
sub polygon_distance($%)
{	my $p = shift;

	my ($x, $y) = @$p;
	my $minDist;

	@_ or return undef;

	my ($x1, $y1) = @{ (shift) };
	unless(@_)
	{	my ($dx, $dy) = ($x1 - $x, $y1 - $y);
		return sqrt($dx * $dx + $dy * $dy);
	}

	while(@_)
	{	my ($x2, $y2) = @{ (shift) };   # closed poly!
		my $A =  $x - $x1;
		my $B =  $y - $y1;
		my $C = $x2 - $x1;
		my $D = $y2 - $y1;

		# closest point to the line segment
		my $dot    = $A * $C + $B * $D;
		my $len_sq = $C * $C + $D * $D;
		my $angle  = $len_sq==0 ? -1 : $dot / $len_sq;

		my ($xx, $yy)
		= $angle < 0 ? ($x1, $y1)   # perpendicular line crosses off segment
		: $angle > 1 ? ($x2, $y2)
		:              ($x1 + $angle * $C, $y1 + $angle * $D);

		my $dx = $x - $xx;
		my $dy = $y - $yy;
		my $dist = sqrt($dx * $dx + $dy * $dy);
		$minDist = $dist unless defined $minDist;
		$minDist = $dist if $dist < $minDist;

		($x1, $y1) = ($x2, $y2);
	}

	$minDist;
}

=function polygon_format $format, @points
[1.07] Map the $format over all @points, both the X and Y coordinate.  This
is especially useful to reduce the number of digits in the stringification.
For instance, when you want reproducible results in regression scripts.

The format is anything supported by C<printf()>, for instance C<"%5.2f">.  Or,
you can pass a code reference which accepts a single value.
=cut

sub polygon_format($@)
{	my $format = shift;
	my $call   = ref $format eq 'CODE' ? $format : sub { sprintf $format, $_[0] };

	map +[ $call->($_->[0]), $call->($_->[1]) ], @_;
}

1;
