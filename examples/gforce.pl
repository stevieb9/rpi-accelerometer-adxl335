#!/usr/bin/env perl

# Stream live acceleration from all three axes to STDOUT.
#
# Usage: perl gforce.pl

use warnings;
use strict;

use RPi::ADC::ADS;
use RPi::Accelerometer::ADXL335;

my $adc = RPi::ADC::ADS->new(model => 'ADS1115');

my $accel = RPi::Accelerometer::ADXL335->new(
    adc => $adc,
    x   => 0,
    y   => 1,
    z   => 2,
);

my $running = 1;
$SIG{INT} = sub { $running = 0 };

print "streaming, Ctrl-C to quit\n";

while ($running){
    my ($gx, $gy, $gz) = $accel->g;

    printf "x: %+.2f g  y: %+.2f g  z: %+.2f g\n", $gx, $gy, $gz;

    select(undef, undef, undef, 0.2);
}
