# Algorithm by Dan Sunday
# - http://geometryalgorithms.com/Archive/algorithm_0109/algorithm_0109.htm
# Original implementation in Perl by Jari Turkia.

use strict;
use warnings;

package Math::Polygon::Convex;
use base 'Exporter';

use Math::Polygon;

our @EXPORT = qw/
  chainHull_2D
/;

=chapter NAME

Math::Polygon::Convex - Collection of convex algorithms

=chapter SYNOPSIS

 use Math::Polygon::Convex  qw/chainHull_2D/;

 my @points = ( [1,2], [2,4], [5,7], [1,2] );
 my $poly   = chainHull_2D @points;

=chapter DESCRIPTION

The "convex polygon" around a set of points, is the polygon with a minimal
size which contains all points.

This package contains one convex calculation algorithm, but may be extended
with alternative implementations in the future.

=chapter FUNCTIONS

=function chainHull_2D $points
Each POINT is an ARRAY of two elements: the X and Y coordinate of a point.
Returned is the enclosing convex M<Math::Polygon> object.

Algorithm by Dan Sunday,
F<http://geometryalgorithms.com/Archive/algorithm_0109/algorithm_0109.htm>
=cut

# is_left(): tests if a point is Left|On|Right of an infinite line.
#    >0 for P2 left of the line through P0 and P1
#    =0 for P2 on the line
#    <0 for P2 right of the line
# See: the January 2001 Algorithm on Area of Triangles
#    http://geometryalgorithms.com/Archive/algorithm_0101/algorithm_0101.htm

sub is_left($$$)
{   my ($P0, $P1, $P2) = @_;

      ($P1->[0] - $P0->[0]) * ($P2->[1] - $P0->[1])
    - ($P2->[0] - $P0->[0]) * ($P1->[1] - $P0->[1]);
}

sub chainHull_2D(@)
{   my @P = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @_;
    my @H;   # output poly

    # Get the indices of points with min x-coord and min|max y-coord
    my $xmin = $P[0][0];
    my ($minmin, $minmax) = (0, 0);
    $minmax++ while $minmax < @P-1 && $P[$minmax+1][0]==$xmin;

    if($minmax == @P-1)   # degenerate case: all x-coords == xmin
    {   push @H, $P[$minmin];
        push @H, $P[$minmax] if $P[$minmax][1] != $P[$minmin][1];
        push @H, $P[$minmin];
        return Math::Polygon->new(@H);
    }

    push @H, $P[$minmin];

    # Get the indices of points with max x-coord and min|max y-coord
    my $maxmin = my $maxmax = @P-1;
    my $xmax   = $P[$maxmax][0];
    $maxmin-- while $maxmin >= 1 && $P[$maxmin-1][0]==$xmax;

    # Compute the lower hull
    for(my $i = $minmax+1; $i <= $maxmin; $i++)
    {   # the lower line joins P[minmin] with P[maxmin]
        # ignore P[i] above or on the lower line
        next if $i < $maxmin
             && is_left($P[$minmin], $P[$maxmin], $P[$i]) >= 0;

        pop @H
           while @H >= 2 && is_left($H[-2], $H[-1], $P[$i]) < 0;
 
        push @H, $P[$i];
    }

    push @H, $P[$maxmax]
        if $maxmax != $maxmin;

    # Next, compute the upper hull on the stack H above the bottom hull
    my $bot = @H-1;           # the bottom point of the upper hull stack
    for(my $i = $maxmin-1; $i >= $minmax; --$i)
    {   # the upper line joins P[maxmax] with P[minmax]
        # ignore P[i] below or on the upper line
        next if $i > $minmax
             && is_left($P[$maxmax], $P[$minmax], $P[$i]) >= 0;

        pop @H
            while @H-1 > $bot && is_left($H[-2], $H[-1], $P[$i]) < 0;

        push @H, $P[$i];
    }

    push @H, $P[$minmin]
        if $minmax != $minmin; # joining endpoint onto stack

    # Remove duplicate points.
    for(my $i = @H-1; $i > 1; $i--)
    {   splice @H, $i, 1
            while $H[$i][0]==$H[$i-1][0] && $H[$i][1]==$H[$i-1][1];
    }

    Math::Polygon->new(@H);
}

1;
