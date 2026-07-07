#!/usr/bin/env perl

# Calibrate the zero points flat on the bench, then stream pitch and
# roll angles.
#
# Usage: perl tilt.pl

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

print "calibrating - keep the sensor level and still...\n";

my $offsets = $accel->calibrate;

printf(
    "zero g points: x %.3f v, y %.3f v, z %.3f v\n",
    $offsets->{x},
    $offsets->{y},
    $offsets->{z},
);

my $running = 1;
$SIG{INT} = sub { $running = 0 };

print "streaming, Ctrl-C to quit\n";

while ($running){
    my ($pitch, $roll) = $accel->tilt;

    printf "pitch: %+6.1f  roll: %+6.1f\n", $pitch, $roll;

    select(undef, undef, undef, 0.2);
}
