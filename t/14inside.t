#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;

use lib '../lib';
use Math::Polygon::Calc;

my @p = ([0,0], [1,1], [-2,1], [-2,-2], [-1,-1], [0,-2], [1,-1], [0,0]);
                                                                                
ok( polygon_contains_point([-1,0], @p), '(-1,0)');
ok( polygon_contains_point([0,-1], @p), '(0,-1)');

ok(!polygon_contains_point([10,10], @p), '(10,10)');
ok(!polygon_contains_point([1,0], @p), '(1,0)');
ok(!polygon_contains_point([-1,-1.5], @p), '(-1,-1.5)');

# On the edge
ok( polygon_contains_point([0,0], @p), '(0,0)');
ok( polygon_contains_point([-1,-1], @p), '(-1,-1)');

