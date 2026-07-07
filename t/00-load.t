#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'RPi::Accelerometer::ADXL335' ) || print "Bail out!\n";
}

diag( "Testing RPi::Accelerometer::ADXL335 $RPi::Accelerometer::ADXL335::VERSION, Perl $], $^X" );
