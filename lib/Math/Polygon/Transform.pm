#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Math::Polygon::Transform;
use parent 'Exporter';

use strict;
use warnings;

use Log::Report  'math-polygon';
use Math::Trig   qw/deg2rad pi rad2deg/;
use POSIX        qw/floor/;

our @EXPORT = qw/
	polygon_resize
	polygon_move
	polygon_rotate
	polygon_grid
	polygon_mirror
	polygon_simplify
/;

#--------------------
=chapter NAME

Math::Polygon::Transform - Polygon transformation

=chapter SYNOPSIS

  my @poly = ( [1,2], [2,4], [5,7], [1, 2] );

  my $area = polygon_transform resize => 3.14, @poly;

  # requires [2.00]
  my $area = polygon_transform +{resize => 3.14}, @poly;

=chapter DESCRIPTION

This package contains polygon transformation algorithms.

=chapter FUNCTIONS

=function polygon_resize [%options|\%options], @points
Make the polygon smaller or larger, with respect to a center.

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

sub polygon_resize(@)
{	my $args;
	if(ref $_[0] eq 'HASH') { $args = shift }
	else
	{	while(@_ && !ref $_[0])
		{	my $key       = shift;
			$args->{$key} = shift;
		}
	}

	my $sx = $args->{xscale} || $args->{scale} || 1.0;
	my $sy = $args->{yscale} || $args->{scale} || 1.0;
	return @_ if $sx==1.0 && $sy==1.0;

	my ($cx, $cy)   = defined $args->{center} ? @{$args->{center}} : (0,0);

	    $cx || $cy
	  ? map +[ $cx + ($_->[0]-$cx)*$sx,  $cy + ($_->[1]-$cy) * $sy ], @_
	  : map +[ $_->[0]*$sx, $_->[1]*$sy ], @_;
}

=function polygon_move [%options|\%options], @points
Returns a list of points which are moved over the indicated distance.

=option  dx FLOAT
=default dx 0
Displacement in the horizontal direction.

=option  dy FLOAT
=default dy 0
Displacement in the vertical direction.

=examples
  my @moved = polygon_move dx => -5.12, @points;
  my @moved = polygon_move +{dx => -5.12}, @points; # since [2.00]

=cut

sub polygon_move(@)
{	my $args;
	if(ref $_[0] eq 'HASH') { $args = shift }
	else
	{	while(@_ && !ref $_[0])
		{	my $key       = shift;
			$args->{$key} = shift;
		}
	}

	my ($dx, $dy) = ($args->{dx}||0, $args->{dy}||0);
	return @_ if $dx==0 && $dy==0;

	map +[ $_->[0] +$dx, $_->[1] +$dy ], @_;
}

=function polygon_rotate [%options|\%options], @points
Rotate a polygon around a center.

=option  degrees FLOAT
=default degrees 0
specify rotation angle in degrees (between -180 and 360).

=option  radians FLOAT
=default radians 0
specify rotation angle in rads (between -pi and 2*pi)

=option  center  POINT
=default center  C<[0,0]>

=cut

sub polygon_rotate(@)
{	my $args;
	if(ref $_[0] eq 'HASH') { $args = shift }
	else
	{	while(@_ && !ref $_[0])
		{	my $key       = shift;
			$args->{$key} = shift;
		}
	}

	my $angle
	  = exists $args->{radians} ? $args->{radians}
	  : exists $args->{degrees} ? deg2rad($args->{degrees})
	  :                           0;

	$angle
		or return @_;

	my $sina = sin($angle);
	my $cosa = cos($angle);

	my ($cx, $cy) = defined $args->{center} ? @{$args->{center}} : (0,0);
	$cx || $cy or return map +[
		 $cosa * $_->[0] + $sina * $_->[1],
		-$sina * $_->[0] + $cosa * $_->[1],
	], @_;

	map +[
		$cx +  $cosa * ($_->[0]-$cx) + $sina * ($_->[1]-$cy),
		$cy + -$sina * ($_->[0]-$cx) + $cosa * ($_->[1]-$cy),
	], @_;
}

=function polygon_grid [%options|\%options], @points
Snap the polygon points to grid points, where artifacts are removed.

=option  raster FLOAT
=default raster 1.0
The raster size, which determines the points to round to.  The origin
C<[0,0]> is always on a grid-point.  When the raster value is zero,
no transformation will take place.

=cut

sub polygon_grid(@)
{	my $args;
	if(ref $_[0] eq 'HASH') { $args = shift }
	else
	{	while(@_ && !ref $_[0])
		{	my $key       = shift;
			$args->{$key} = shift;
		}
	}

	my $raster = exists $args->{raster} ? $args->{raster} : 1;
	return @_ if $raster == 0;

	# use fast "int" for gridsize 1
	return map +[ floor($_->[0] + 0.5), floor($_->[1] + 0.5) ], @_
		if $raster > 0.99999 && $raster < 1.00001;

	map +[ $raster * floor($_->[0]/$raster + 0.5), $raster * floor($_->[1]/$raster + 0.5) ], @_;
}

=function polygon_mirror [%options|\%options], @points
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

=error you need to specify 'x', 'y', 'rc', or 'line'
=cut

sub polygon_mirror(@)
{	my $args;
	if(ref $_[0] eq 'HASH') { $args = shift }
	else
	{	while(@_ && !ref $_[0])
		{	my $key       = shift;
			$args->{$key} = shift;
		}
	}

	if(defined $args->{x})
	{	my $x2 = 2* $args->{x};
		return map +[ $x2 - $_->[0], $_->[1] ], @_;
	}

	if(defined $args->{y})
	{	my $y2 = 2* $args->{y};
		return map +[ $_->[0], $y2 - $_->[1] ], @_;
	}

	# Mirror in line

	my ($rc, $b);
	if(exists $args->{rc} )
	{	$rc = $args->{rc};
		$b  = $args->{b} || 0;
	}
	elsif(my $through = $args->{line})
	{	my ($p0, $p1) = @$through;
		if($p0->[0]==$p1->[0])
		{	$b = $p0->[0];      # vertical mirror
		}
		else
		{	$rc = ($p1->[1] - $p0->[1]) / ($p1->[0] - $p0->[0]);
			$b  = $p0->[1] - $p0->[0] * $rc;
		}
	}
	else
	{	error __"you need to specify 'x', 'y', 'rc', or 'line'";
	}

	unless(defined $rc)    # vertical
	{	my $x2 = 2* $b;
		return map +[ $x2 - $_->[0], $_->[1] ], @_;
	}

	# mirror is y=x*rc+b, y=-x/rc+c through mirrored point
	my $yf = 2/($rc*$rc +1);
	my $xf = $yf * $rc;

	map { my $c = $_->[1] + $_->[0]/$rc;
		+[ $xf*($c-$b) - $_->[0], $yf*($b-$c) + 2*$c - $_->[1] ]
	} @_;
}

=function polygon_simplify [%options|\%options], @points

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

sub _angle($$$)
{	my ($p0, $p1, $p2) = @_;
	my $a0 = atan2($p0->[1] - $p1->[1], $p0->[0] - $p1->[0]);
	my $a1 = atan2($p2->[1] - $p1->[1], $p2->[0] - $p1->[0]);
	my $a  = abs($a0 - $a1);
	$a = 2*pi - $a    if $a > pi;
	$a;
}

sub polygon_simplify(@)
{	my $args;
	if(ref $_[0] eq 'HASH') { $args = shift }
	else
	{	while(@_ && !ref $_[0])
		{	my $key       = shift;
			$args->{$key} = shift;
		}
	}

	@_ or return ();

	my $is_ring     = $_[0][0]==$_[-1][0] && $_[0][1]==$_[-1][1];
	my $same        = $args->{same} || 0.0001;
	my $slope       = $args->{slope};
	my $changes     = 1;

	while($changes && @_)
	{	$changes    = 0;
		my @new;

		my $p       = shift;
		while(@_)
		{	my ($x, $y)   = @$p;

			my ($nx, $ny) = @{$_[0]};
			my $d01 = sqrt(($nx-$x)*($nx-$x) + ($ny-$y)*($ny-$y));
			if($d01 < $same)
			{	$changes++;

				# point within threshold: middle, unless we are at the
				# start of the polygo description: that one has a slight
				# preference, to avoid an endless loop.
				push @new, !@new ? [ ($x,$y) ] : [ ($x+$nx)/2, ($y+$ny)/2 ];
				shift;            # remove next
				$p       = shift; # 2nd as new current
				next;
			}

			unless(@_ >= 2 && defined $slope)
			{	push @new, $p;     # keep this
				$p       = shift;  # check next
				next;
			}

			my ($sx,$sy) = @{$_[1]};
			my $d12 = sqrt(($sx-$nx)*($sx-$nx) + ($sy-$ny)*($sy-$ny));
			my $d02 = sqrt(($sx-$x) *($sx-$x)  + ($sy-$y) *($sy-$y) );

			if($d01 + $d12 <= $d02 + $slope)
			{	# three points nearly on a line, remove middle
				$changes++;
				push @new, $p, $_[1];
				shift; shift;
				$p         = shift;  # jump over next
				next;
			}

			if(@_ > 2 && abs($d01-$d12-$d02) < $slope)
			{	# check possibly a Z shape
				my ($tx,$ty) = @{$_[2]};
				my $d03 = sqrt(($tx-$x) *($tx-$x)  + ($ty-$y) *($ty-$y));
				my $d13 = sqrt(($tx-$nx)*($tx-$nx) + ($ty-$ny)*($ty-$ny));

				if($d01 - $d13 <= $d03 + $slope)
				{	$changes++;
					push @new, $p, $_[2];  # accept 1st and 4th
					splice @_, 0, 3;       # jump over handled three!
					$p = shift;
					next;
				}
			}

			push @new, $p;   # nothing for this one.
			$p = shift;
		}
		push @new, $p if defined $p;

		unshift @new, $new[-1]    # be sure to keep ring closed
			if $is_ring && ($new[0][0]!=$new[-1][0] || $new[0][1]!=$new[-1][1]);

		@_ = @new;
	}

	exists $args->{max_points}
		or return @_;

	#
	# Reduce the number of points to $max
	#

	# Collect all angles
	my $max_angles = $args->{max_points};
	my @angles;

	if($is_ring)
	{	return @_ if @_ <= $max_angles;
		pop @_;
		push @angles, [0, _angle($_[-1], $_[0], $_[1])], [$#_, _angle($_[-2], $_[-1], $_[0])];
	}
	else
	{	return @_ if @_ <= $max_angles;
		$max_angles -= 2;
	}

	foreach (my $i=1; $i<@_-1; $i++)
	{	push @angles, [$i, _angle($_[$i-1], $_[$i], $_[$i+1]) ];
	}

	# Strip widest angles
	@angles = sort { $b->[1] <=> $a->[1] } @angles;
	while(@angles > $max_angles)
	{	my $point = shift @angles;
		$_[$point->[0]] = undef;
	}

	# Return left-over points
	@_ = grep defined, @_;
	push @_, $_[0] if $is_ring;
	@_;
}

1;
