use ExtUtils::MakeMaker;

require 5.006;

WriteMakefile
  ( NAME		=> 'Math::Polygon'
  , VERSION_FROM	=> 'version'
  , PREREQ_PM		=>
     { Test::More    => 0.47
     , Scalar::Util  => 1.13
     , Math::Trig    => 0
     }
  , AUTHOR              => 'Mark Overmeer'
  , ABSTRACT            => 'Polygon calculations'
  );
