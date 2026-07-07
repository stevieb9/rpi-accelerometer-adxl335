#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

use RPi::Accelerometer::ADXL335;

# The mock ADCs at the bottom of this file stand in for the transport,
# so the scaling, calibration and tilt logic gets exercised with no
# hardware attached

plan tests => 27;

my $adc = MockADC->new;
my $accel = RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2);

isa_ok $accel, 'RPi::Accelerometer::ADXL335';

is $accel->adc, $adc, "adc() exposes the transport object";

is_deeply
    $accel->zero_g,
    { x => 1.65, y => 1.65, z => 1.65 },
    "zero g defaults to vs / 2 on all axes";

is sprintf("%.2f", $accel->sensitivity), '0.33', "sensitivity defaults to 0.1 x vs";

MockADC->set(0, 1.65);
MockADC->set(1, 1.98);
MockADC->set(2, 1.32);

is_deeply
    [map { sprintf "%.2f", $_ } $accel->volts],
    ['1.65', '1.98', '1.32'],
    "volts() maps each axis to its ADC channel";

is sprintf("%.2f", $accel->volts('y')), '1.98', "volts() takes a single axis";

is_deeply
    [map { sprintf "%.4f", $_ } $accel->g],
    ['0.0000', '1.0000', '-1.0000'],
    "g() converts each axis' voltage to g";

is sprintf("%.4f", $accel->g('z')), '-1.0000', "g() takes a single axis";

my $mapped = RPi::Accelerometer::ADXL335->new(adc => $adc, x => 5, y => 3, z => 7);

MockADC->set(5, 2.0);
MockADC->set(3, 1.0);
MockADC->set(7, 0.5);

is_deeply
    [map { sprintf "%.2f", $_ } $mapped->volts],
    ['2.00', '1.00', '0.50'],
    "channel mapping is per-axis, not positional";

my $vs3 = RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2, vs => 3);

is_deeply
    $vs3->zero_g,
    { x => 1.5, y => 1.5, z => 1.5 },
    "zero g scales with vs";

is sprintf("%.2f", $vs3->sensitivity), '0.30', "sensitivity scales with vs";

my $custom = RPi::Accelerometer::ADXL335->new(
    adc         => $adc,
    x           => 0,
    y           => 1,
    z           => 2,
    sensitivity => 0.5,
    zero_g      => { z => 1.7 },
);

is_deeply
    $custom->zero_g,
    { x => 1.65, y => 1.65, z => 1.7 },
    "zero_g param overrides only the axes given";

is $custom->sensitivity, 0.5, "sensitivity param overrides the ratiometric default";

MockADC->set(2, 2.2);

is sprintf("%.4f", $custom->g('z')), '1.0000',
    "g() uses the custom zero point and sensitivity";

$accel->zero_g({ x => 1.6 });

is_deeply
    $accel->zero_g,
    { x => 1.6, y => 1.65, z => 1.65 },
    "zero_g() updates only the axes given";

my $offsets = $accel->zero_g;
$offsets->{x} = 99;

is $accel->zero_g->{x}, 1.6, "zero_g() returns a copy, not the internals";

is $accel->sensitivity(0.25), 0.25, "sensitivity() sets and returns the new value";

my $pct = RPi::Accelerometer::ADXL335->new(adc => MockPctADC->new, x => 0, y => 1, z => 2);

MockPctADC->set(0, 50);
MockPctADC->set(1, 60);
MockPctADC->set(2, 40);

is_deeply
    [map { sprintf "%.3f", $_ } $pct->volts],
    ['1.650', '1.980', '1.320'],
    "percent-only ADCs scale by vref (defaulting to vs)";

is_deeply
    [map { sprintf "%.4f", $_ } $pct->g],
    ['0.0000', '1.0000', '-1.0000'],
    "...and the g math rides on top";

my $vref5 = RPi::Accelerometer::ADXL335->new(
    adc  => MockPctADC->new,
    x    => 0,
    y    => 1,
    z    => 2,
    vref => 5,
);

is sprintf("%.2f", $vref5->volts('x')), '2.50', "vref param scales percent-based reads";

my $both = RPi::Accelerometer::ADXL335->new(adc => MockBothADC->new, x => 0, y => 1, z => 2);

is $both->volts('x'), 1, "volts() is preferred when the ADC offers both methods";

my $cal = RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2);

MockADC->set(0, 1.60);
MockADC->set(1, 1.70);
MockADC->set(2, 1.98);

my $measured = $cal->calibrate(4);

is_deeply
    [map { sprintf "%.4f", $measured->{$_} } qw(x y z)],
    ['1.6000', '1.7000', '1.6500'],
    "calibrate() sets x/y zero to the mean, z a full g lower";

is sprintf("%.4f", $cal->g('z')), '1.0000', "a calibrated level sensor reads +1 g on z";

MockADC->set(0, 1.60, 1.70);

my $averaged = $cal->calibrate(2);

is sprintf("%.4f", $averaged->{x}), '1.6500', "calibrate() averages its samples";

my $t = RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2);

MockADC->set(0, 1.65);
MockADC->set(1, 1.65);
MockADC->set(2, 1.98);

is_deeply
    [map { sprintf "%.1f", $_ } $t->tilt],
    ['0.0', '0.0'],
    "tilt() reads level when flat, top side up";

MockADC->set(0, 1.98);
MockADC->set(1, 1.65);
MockADC->set(2, 1.65);

is_deeply
    [map { sprintf "%.1f", $_ } $t->tilt],
    ['90.0', '0.0'],
    "tilt() pitch reads +90 with the +X end straight up";

MockADC->set(0, 1.65);
MockADC->set(1, 1.98);
MockADC->set(2, 1.65);

is_deeply
    [map { sprintf "%.1f", $_ } $t->tilt],
    ['0.0', '90.0'],
    "tilt() roll reads +90 with the +Y end straight up";

# The stand-in transports. MockADC's volts() walks the per-channel
# queue set by set(), and the final value sticks, mimicking a level
# that has settled

package MockADC;

my %reads;

sub new {
    return bless {}, shift;
}
sub set {
    my (undef, $channel, @values) = @_;
    $reads{$channel} = [@values];
}
sub volts {
    my (undef, $channel) = @_;
    my $queue = $reads{$channel};
    return @{$queue} > 1 ? shift @{$queue} : $queue->[0];
}

package MockPctADC;

my %pct;

sub new {
    return bless {}, shift;
}
sub percent {
    my (undef, $channel) = @_;
    return $pct{$channel};
}
sub set {
    my (undef, $channel, $value) = @_;
    $pct{$channel} = $value;
}

package MockBothADC;

sub new {
    return bless {}, shift;
}
sub percent {
    return 100;
}
sub volts {
    return 1;
}
