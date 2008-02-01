#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 12;

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


@p = ([1,1],[1,3],[4,3],[4,1],[1,1]);

ok( polygon_contains_point([3,1], @p), '2nd (3,1)');  # on vertical edge

ok( polygon_contains_point([1,1], @p), '2nd (1,1)');
ok( polygon_contains_point([1,3], @p), '2nd (1,3)');
ok( polygon_contains_point([4,3], @p), '2nd (4,3)');
ok( polygon_contains_point([4,1], @p), '2nd (4,1)');
