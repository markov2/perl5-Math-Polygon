use strict;
use warnings;

package Math::Polygon::Calc;
use base 'Exporter';

our @EXPORT = qw/
 polygon_area
 polygon_bbox
 polygon_beautify
 polygon_equal
 polygon_is_clockwise
 polygon_clockwise
 polygon_counter_clockwise
 polygon_perimeter
 polygon_same
 polygon_start_minxy
 polygon_string
/;

use List::Util    qw/min max/;

=chapter NAME

Math::Polygon::Calc - Simple polygon calculations

=chapter SYNOPSIS

 my @poly = ( [1,2], [2,4], [5,7], [1, 2] );

 my ($xmin, $ymin, $xmax, $ymax) = polygon_bbox @poly;

 my $area = polygon_area @poly;
 MY $L    = polygon_perimeter @poly;
 if(polygon_is_clockwise @poly) { ... };
 
 my @rot  = polygon_start_minxy @poly;

=chapter DESCRIPTION

This package contains a wide variaty of relatively easy polygon
calculations.  More complex calculations are put in separate
packages.

=chapter FUNCTIONS

=function polygon_string LIST-OF-POINTS
=cut

sub polygon_string(@) { join ', ', map { "[$_->[0],$_->[1]]" } @_ }

=function polygon_bbox LIST-OF-POINTS
Returns a list with four elements: (xmin, ymin, xmax, ymax), which describe
the bounding box of the polygon (all points of the polygon are within that
area.
=cut

sub polygon_bbox(@)
{
    ( min( map {$_->[0]} @_ )
    , min( map {$_->[1]} @_ )
    , max( map {$_->[0]} @_ )
    , max( map {$_->[1]} @_ )
    );
}

=function polygon_area LIST-OF-POINTS
Returns the area enclosed by the polygon.  The last point of the list
must be the same as the first to produce a correct result.

The algorithm was found at L<http://mathworld.wolfram.com/PolygonArea.html>,
and sounds:

 A = abs( 1/2 * (x1y2-x2y1 + x2y3-x3y2 ...)

=cut

sub polygon_area(@)
{   my $area    = 0;
    while(@_ >= 2)
    {   $area += $_[0][0]*$_[1][1] - $_[0][1]*$_[1][0];
        shift;
    }

    abs($area)/2;
}

=function polygon_is_clockwise LIST-OF-POINTS
=cut

sub polygon_is_clockwise(@)
{   my $area  = 0;
    while(@_ >= 2)
    {   $area += $_[0][0]*$_[1][1] - $_[0][1]*$_[1][0];
        shift;
    }

    $area < 0;
}

=function polygon_clockwise LIST-OF-POINTS
Be sure the polygon points are in clockwise order.
=cut

sub polygon_clockwise(@)
{   polygon_is_clockwise(@_) ? @_ : reverse @_;
}

=function polygon_counter_clockwise LIST-OF-POINTS
Be sure the polygon points are in counter-clockwise order.
=cut

sub polygon_counter_clockwise(@)
{   polygon_is_clockwise(@_) ? reverse(@_) : @_;
}


=function polygon_perimeter LIST-OF-POINTS
The length of the line of the polygon.  This can also be used to compute
the length of any line: of the last point is not equal to the first, then
a line is presumed; for a polygon they must match.

This is simply Pythagoras.

 $l = sqrt((x1-x0)^2 + (y1-y0)^2) + sqrt((x2-x1)^2+(y2-y1)^2) + ...

=cut

sub polygon_perimeter(@)
{   my $l    = 0;

    while(@_ >= 2)
    {   $l += sqrt(($_[0][0]-$_[1][0])**2 + ($_[0][1]-$_[1][1])**2);
        shift;
    }

    $l;
}

=function polygon_start_minxy LIST-OF-POINTS
Returns the polygon, where the point with the smallest x coordinate is at
the start (and end, of course).  If more points share the x coordinate, the
smallest y-values will make the final decission.
=cut

sub polygon_start_minxy(@)
{
    return @_ if @_ <= 1;
    my $ring  = $_[0][0]==$_[-1][0] && $_[-1][1]==$_[-1][1];
    pop @_ if $ring;

    my $rot   = 0;
    my $minxy = $_[0];

    for(my $i=1; $i<@_; $i++)
    {   next if $_[$i][0] > $minxy->[0];

        if($_[$i][0] < $minxy->[0] || $_[$i][1] < $minxy->[1])
	{   $minxy = $_[$i];
	    $rot   = $i;
	}
    }

    $rot==0 ? (@_, ($ring ? $minxy : ()))
            : (@_[$rot..$#_], @_[0..$rot-1], ($ring ? $minxy : ()));
}

=function polygon_beautify [HASH], LIST-OF-POINTS
Polygons, certainly after some computations, can have a lot of
horrible artifacts: points which are double, spikes, etc.  This
functions provided by this module beautify
The optional HASH contains the OPTIONS:

=option  remove_spikes BOOLEAN
=default remove_spikes <false>

=option  remove_between BOOLEAN
=default remove_between <false>
Simple points in-between are always removed, but more complex
points are not: when the line is not parallel to one of the axes,
more intensive calculations must take place.  This will only be
done when this flags is set.
NOT IMPLEMENTED YET

=cut

sub polygon_beautify(@)
{   my %opts     = ref $_[0] eq 'HASH' ? %{ (shift) } : ();
    return () unless @_;

    my $despike  = exists $opts{remove_spikes}  ? $opts{remove_spikes}  : 0;
#   my $interpol = exists $opts{remove_between} ? $opts{remove_between} : 0;

    my @res      = @_;
    return () if @res < 4;  # closed triangle = 4 points
    pop @res;               # cyclic: last is first
    my $unchanged= 0;

    while($unchanged < 2*@res)
    {    return () if @res < 3;  # closed triangle = 4 points

         my $this = shift @res;
	 push @res, $this;         # recycle
	 $unchanged++;

         # remove doubles
	 my ($x, $y) = @$this;
         while(@res && $res[0][0]==$x && $res[0][1]==$y)
	 {   $unchanged = 0;
             shift @res;
	 }

         # remove spike
	 if($despike && @res >= 2)
	 {   # any spike
	     if($res[1][0]==$x && $res[1][1]==$y)
	     {   $unchanged = 0;
	         shift @res;
	     }

	     # x-spike
	     if(   $y==$res[0][1] && $y==$res[1][1]
	        && (  ($res[0][0] < $x && $x < $res[1][0])
	           || ($res[0][0] > $x && $x > $res[1][0])))
	     {   $unchanged = 0;
	         shift @res;
             }

             # y-spike
	     if(   $x==$res[0][0] && $x==$res[1][0]
	        && (  ($res[0][1] < $y && $y < $res[1][1])
	           || ($res[0][1] > $y && $y > $res[1][1])))
	     {   $unchanged = 0;
	         shift @res;
             }
	 }

	 # remove intermediate
	 if(   @res >= 2
	    && $res[0][0]==$x && $res[1][0]==$x
	    && (   ($y < $res[0][1] && $res[0][1] < $res[1][1])
	        || ($y > $res[0][1] && $res[0][1] > $res[1][1])))
	 {   $unchanged = 0;
	     shift @res;
	 }

	 if(   @res >= 2
	    && $res[0][1]==$y && $res[1][1]==$y
	    && (   ($x < $res[0][0] && $res[0][0] < $res[1][0])
	        || ($x > $res[0][0] && $res[0][0] > $res[1][0])))
	 {   $unchanged = 0;
	     shift @res;
	 }

	 # remove 2 out-of order between two which stay
	 if(@res >= 3
	    && $x==$res[0][0] && $x==$res[1][0] && $x==$res[2][0]
	    && ($y < $res[0][1] && $y < $res[1][1]
	        && $res[0][1] < $res[2][1] && $res[1][1] < $res[2][1]))
         {   $unchanged = 0;
	     splice @res, 0, 2;
	 }

	 if(@res >= 3
	    && $y==$res[0][1] && $y==$res[1][1] && $y==$res[2][1]
	    && ($x < $res[0][0] && $x < $res[1][0]
	        && $res[0][0] < $res[2][0] && $res[1][0] < $res[2][0]))
         {   $unchanged = 0;
	     splice @res, 0, 2;
	 }
    }

    @res ? (@res, $res[0]) : ();
}

=function polygon_equal ARRAY-OF-POINTS, ARRAY-OF-POINTS, [TOLERANCE]
Compare two polygons, on the level of points. When the polygons are
the same but rotated, this will return false. See M<same()>.
=cut

sub polygon_equal($$;$)
{   my  ($f,$s, $tolerance) = @_;
    return 0 if @$f != @$s;
    my @f = @$f;
    my @s = @$s;

    if(defined $tolerance)
    {    while(@f)
         {    return 0 if abs($f[0][0]-$s[0][0]) > $tolerance
                       || abs($f[0][1]-$s[0][1]) > $tolerance;
              shift @f; shift @s;
         }
         return 1;
    }

    while(@f)
    {    return 0 if $f[0][0] != $s[0][0] || $f[0][1] != $s[0][1];
         shift @f; shift @s;
    }

    1;
}

=function polygon_same ARRAY-OF-POINTS, ARRAY-OF-POINTS, [TOLERANCE]
Compare two polygons, where the polygons may be rotated wrt each
other. This is (much) slower than M<equal()>, but some algorithms
will cause un unpredictable rotation in the result.
=cut

sub polygon_same($$;$)
{   return 0 if @{$_[0]} != @{$_[1]};
    my @f = polygon_start_minxy @{ (shift) };
    my @s = polygon_start_minxy @{ (shift) };
    polygon_equal \@f, \@s, @_;
}

1;
