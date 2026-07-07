package RPi::Accelerometer::ADXL335;

use strict;
use warnings;

use Carp qw(croak);
use Scalar::Util qw(blessed);

our $VERSION = '0.01';

use constant {
    DEFAULT_CAL_SAMPLES => 10,
    DEFAULT_VS          => 3.3,
    RAD_TO_DEG          => 45 / atan2(1, 1),    # 180 / pi
    SENS_PER_VS         => 0.1,                 # 300 mV/g at Vs = 3 V, ratiometric
};

# Public methods

sub adc {
    my ($self) = @_;
    return $self->{adc};
}
sub calibrate {
    my ($self, $samples) = @_;

    if (defined $samples && ($samples !~ /^\d+$/ || $samples == 0)){
        croak "calibrate() \$samples param must be a positive integer";
    }

    $samples = DEFAULT_CAL_SAMPLES if ! defined $samples;

    my %sum;

    for (1 .. $samples){
        for my $axis (qw(x y z)){
            $sum{$axis} += $self->_volts($axis);
        }
    }

    # Level and still, X and Y sit at zero g, while Z carries gravity -
    # a full g above its own zero point

    $self->{zero_g}{x} = $sum{x} / $samples;
    $self->{zero_g}{y} = $sum{y} / $samples;
    $self->{zero_g}{z} = $sum{z} / $samples - $self->{sensitivity};

    return $self->zero_g;
}
sub g {
    my ($self, $axis) = @_;

    if (defined $axis){
        if ($axis !~ /^[xyz]$/){
            croak "g() \$axis param must be x, y or z";
        }
        return $self->_axis_g($axis);
    }

    return map { $self->_axis_g($_) } qw(x y z);
}
sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    if (! blessed $args{adc}){
        croak "new() requires the adc param, an ADC object (eg. RPi::ADC::ADS)";
    }

    if (! $args{adc}->can('volts') && ! $args{adc}->can('percent')){
        croak "the adc param object must provide a volts() or percent() method";
    }

    $self->{adc} = $args{adc};

    for my $axis (qw(x y z)){
        my $out = uc($axis) . 'OUT';

        if (! defined $args{$axis} || $args{$axis} !~ /^\d+$/){
            croak "new() requires the $axis param, the ADC input channel " .
                  "wired to the sensor's $out pin";
        }

        $self->{channel}{$axis} = $args{$axis};
    }

    if (defined $args{vs} && ($args{vs} !~ /^\d+(?:\.\d+)?$/ || $args{vs} == 0)){
        croak "vs param must be a positive number of volts";
    }

    $self->{vs} = defined $args{vs} ? $args{vs} : DEFAULT_VS;

    if (defined $args{vref} && ($args{vref} !~ /^\d+(?:\.\d+)?$/ || $args{vref} == 0)){
        croak "vref param must be a positive number of volts";
    }

    # The ADC's full-scale reference is very commonly the same 3.3 V
    # rail that powers the sensor, so vs doubles as the vref default

    $self->{vref} = defined $args{vref} ? $args{vref} : $self->{vs};

    $self->{sensitivity} = SENS_PER_VS * $self->{vs};

    if (defined $args{sensitivity}){
        $self->sensitivity($args{sensitivity});
    }

    $self->{zero_g}{$_} = $self->{vs} / 2 for qw(x y z);

    if (defined $args{zero_g}){
        $self->zero_g($args{zero_g});
    }

    return $self;
}
sub sensitivity {
    my ($self, $v_per_g) = @_;

    if (defined $v_per_g){
        if ($v_per_g !~ /^\d+(?:\.\d+)?$/ || $v_per_g == 0){
            croak "sensitivity() \$v_per_g param must be a positive number " .
                  "of volts per g";
        }
        $self->{sensitivity} = $v_per_g;
    }

    return $self->{sensitivity};
}
sub tilt {
    my ($self) = @_;

    my ($gx, $gy, $gz) = $self->g;

    my $pitch = atan2($gx, sqrt($gy * $gy + $gz * $gz)) * RAD_TO_DEG;
    my $roll  = atan2($gy, $gz) * RAD_TO_DEG;

    return ($pitch, $roll);
}
sub volts {
    my ($self, $axis) = @_;

    if (defined $axis){
        if ($axis !~ /^[xyz]$/){
            croak "volts() \$axis param must be x, y or z";
        }
        return $self->_volts($axis);
    }

    return map { $self->_volts($_) } qw(x y z);
}
sub zero_g {
    my ($self, $offsets) = @_;

    if (defined $offsets){
        if (ref $offsets ne 'HASH'){
            croak "zero_g() \$offsets param must be a hashref with x, y " .
                  "and/or z keys";
        }

        for my $axis (sort keys %{$offsets}){
            if ($axis !~ /^[xyz]$/){
                croak "zero_g() axis keys must be x, y or z, not '$axis'";
            }

            if (! defined $offsets->{$axis} || $offsets->{$axis} !~ /^\d+(?:\.\d+)?$/){
                croak "zero_g() $axis value must be a non-negative number " .
                      "of volts";
            }

            $self->{zero_g}{$axis} = $offsets->{$axis};
        }
    }

    # A copy, so the caller can't reach into our calibration

    return { %{$self->{zero_g}} };
}

# Private methods

sub _axis_g {
    my ($self, $axis) = @_;

    my $v = $self->_volts($axis);

    return ($v - $self->{zero_g}{$axis}) / $self->{sensitivity};
}
sub _volts {
    my ($self, $axis) = @_;

    my $channel = $self->{channel}{$axis};

    if ($self->{adc}->can('volts')){
        return $self->{adc}->volts($channel);
    }

    # Percent-only ADCs (eg. RPi::ADC::MCP3008) report 0-100 of their
    # own reference voltage

    return $self->{adc}->percent($channel) / 100 * $self->{vref};
}

sub _vim{}; # Fold placeholder

1;
__END__

=head1 NAME

RPi::Accelerometer::ADXL335 - Interface to the Analog Devices ADXL335 3-axis
accelerometer

=for html
<a href="https://github.com/stevieb9/rpi-accelerometer-adxl335/actions"><img src="https://github.com/stevieb9/rpi-accelerometer-adxl335/workflows/CI/badge.svg"/></a>
<a href='https://coveralls.io/github/stevieb9/rpi-accelerometer-adxl335?branch=main'><img src='https://coveralls.io/repos/stevieb9/rpi-accelerometer-adxl335/badge.svg?branch=main&service=github' alt='Coverage Status' /></a>


=head1 SYNOPSIS

    use RPi::ADC::ADS;
    use RPi::Accelerometer::ADXL335;

    # The Pi has no analog inputs; the sensor's three output pins go
    # through an ADC (here, XOUT on A0, YOUT on A1, ZOUT on A2)

    my $adc = RPi::ADC::ADS->new(model => 'ADS1115');

    my $accel = RPi::Accelerometer::ADXL335->new(
        adc => $adc,
        x   => 0,
        y   => 1,
        z   => 2,
    );

    # Acceleration, in g

    my ($gx, $gy, $gz) = $accel->g;

    printf "x: %+.2f g  y: %+.2f g  z: %+.2f g\n", $gx, $gy, $gz;

    # ...or a single axis

    my $gz = $accel->g('z');

    # Tilt angles, in degrees

    my ($pitch, $roll) = $accel->tilt;

    # One-time zero point calibration (sensor level and still)

    $accel->calibrate;

=head1 DESCRIPTION

Interface to the Analog Devices ADXL335 3-axis, +/-3 g accelerometer.
The chip measures the static acceleration of gravity - which is what
makes it a tilt sensor - as well as dynamic acceleration from motion,
shock and vibration.

The sensor is fully analog: its C<XOUT>, C<YOUT> and C<ZOUT> pins each
output a voltage proportional to the acceleration along that axis. The
Raspberry Pi has no analog inputs, so those three pins must go through
an analog-to-digital converter, and this module sits on top of whichever
ADC object you hand it - L<RPi::ADC::ADS> (I2C) and L<RPi::ADC::MCP3008>
(SPI) both work as-is. Any object providing a C<volts($channel)> or
C<percent($channel)> method will do.

This distribution is pure Perl, with no hard hardware dependencies at
all; the compiled layer belongs to the ADC distribution you choose, and
this module is only the scaling math on top. It installs, and its
hardware-free test suite passes, on any machine.

=head1 METHODS

=head2 new

Instantiates a new L<RPi::Accelerometer::ADXL335> object.

I<Parameters>:

All parameters are sent in within a single hash.

    adc => $object

I<Mandatory, Object>: An instantiated ADC object, wired to the sensor's
three output pins. Reads go through the object's C<volts($channel)>
method if it has one (L<RPi::ADC::ADS>), falling back to
C<percent($channel)> scaled by C<vref> (L<RPi::ADC::MCP3008>).

    x => $int
    y => $int
    z => $int

I<Mandatory, Integer>: The ADC input channel each of the sensor's
C<XOUT>, C<YOUT> and C<ZOUT> pins is wired to.

    vs => $num

I<Optional, Number>: The supply voltage actually powering the ADXL335,
which its output scaling is ratiometric to. Defaults to C<3.3>, the
Pi's 3.3 V rail. See L</RATIOMETRIC SCALING AND CALIBRATION>.

    vref => $num

I<Optional, Number>: The ADC's full-scale reference voltage, used only
for percent-based ADCs (eg. the MCP3008's C<VREF> pin voltage).
Defaults to C<vs>, since both are commonly tied to the same 3.3 V rail.

    zero_g => $hashref

I<Optional, Hashref>: Per-axis zero g output voltages, with C<x>, C<y>
and/or C<z> keys. Each axis defaults to C<vs / 2>. See L</zero_g>.

    sensitivity => $num

I<Optional, Number>: The output sensitivity in volts per g, shared by
all three axes. Defaults to C<0.1 * vs> (the datasheet's 300 mV/g at
3 V, scaled ratiometrically - 330 mV/g at 3.3 V).

I<Returns>: The L<RPi::Accelerometer::ADXL335> object. Croaks on any invalid
parameter.

=head2 g

Reads acceleration.

I<Parameters>:

    $axis

I<Optional, String>: C<x>, C<y> or C<z> to read a single axis.

I<Returns>: With C<$axis>, that axis' acceleration in g as a floating
point number. Without, a three element list of C<(x, y, z)>
acceleration in g. At rest, an axis pointing straight up reads C<+1>,
straight down C<-1>, and horizontal C<0>.

=head2 tilt

Derives the sensor's attitude from the static pull of gravity.

Meaningful only while the sensor is at rest - shake it, and gravity
can't be told apart from the shaking.

Takes no parameters.

I<Returns>: A two element list, C<($pitch, $roll)>, in degrees. Pitch
is positive when the C<+X> end tips up (+/-90); roll is positive when
the C<+Y> end tips up (+/-180). Both read C<0> when the sensor sits
flat, top side up. See L</AXES AND ORIENTATION>.

=head2 volts

Reads the raw output voltage, before any g scaling - what
L</calibrate> uses, and handy when verifying the wiring.

I<Parameters>:

    $axis

I<Optional, String>: C<x>, C<y> or C<z> to read a single axis.

I<Returns>: With C<$axis>, that axis' output voltage. Without, a three
element list of C<(x, y, z)> voltages.

=head2 calibrate

Measures the per-axis zero g points, replacing the C<vs / 2> assumption
with your part's reality. The sensor B<must> be level (top side up) and
still: X and Y are taken as reading zero g, and Z as reading exactly
C<+1> g.

Part-to-part zero g tolerance is the ADXL335's biggest error source -
worth a full g on the Z axis - so calibrate once, keep the returned
offsets, and feed them back to C<new()> thereafter. See
L</RATIOMETRIC SCALING AND CALIBRATION>.

I<Parameters>:

    $samples

I<Optional, Integer>: The number of reads per axis to average. Defaults
to C<10>.

I<Returns>: The new per-axis zero g voltages, as a hashref with C<x>,
C<y> and C<z> keys - the same form C<new()>'s C<zero_g> param and
L</zero_g> accept.

=head2 zero_g

Sets and/or gets the per-axis zero g output voltages.

I<Parameters>:

    $offsets

I<Optional, Hashref>: C<x>, C<y> and/or C<z> keys, each a voltage. Axes
not mentioned keep their current value.

I<Returns>: A hashref of all three axes' zero g voltages.

=head2 sensitivity

Sets and/or gets the output sensitivity used to convert volts to g.

I<Parameters>:

    $v_per_g

I<Optional, Number>: The new sensitivity, in volts per g.

I<Returns>: The current sensitivity in volts per g.

=head2 adc

Returns the ADC object passed into C<new()>, for anything this API
doesn't wrap (changing the ADC's gain or sample averaging, reading a
spare channel, etc).

Takes no parameters.

=head1 TECHNICAL INFORMATION

=head2 DEVICE SPECIFICS

    - 3-axis accelerometer; +/-3 g minimum full-scale range (+/-3.6 g typical)
    - analog voltage outputs, one per axis; no bus, no registers
    - ratiometric: sensitivity 300 mV/g typ at Vs = 3 V (270-330 mV/g)
    - ratiometric: zero g output nominally Vs / 2 on all axes
    - outputs driven through internal 32 kohm (+/-15%) resistors
    - bandwidth set by external capacitors: X/Y to 1600 Hz, Z to 550 Hz
    - noise density 150 ug/sqrt(Hz) X/Y, 300 ug/sqrt(Hz) Z
    - supply: 1.8-3.6 V, drawing ~350 uA at 3 V
    - turn-on time ~160 x C(uF) + 1 ms (~17 ms with 0.1 uF filters)
    - 10,000 g shock survival; -40 to +85 C operating range
    - 16-lead 4 mm x 4 mm x 1.45 mm LFCSP package

=head2 PINOUT AND WIRING

Of the chip's 16 pins: C<VS> (x2) is supply, C<COM> (x4) is ground,
C<XOUT>/C<YOUT>/C<ZOUT> are the per-axis outputs, C<ST> is self-test,
and the rest are no-connects. Breakout boards (GY-61 and friends) boil
that down to a header:

    VCC    3.3 V supply (see the regulator note below)
    GND    ground; common with the Pi and the ADC
    X      XOUT - analog X axis, to an ADC input
    Y      YOUT - analog Y axis, to an ADC input
    Z      ZOUT - analog Z axis, to an ADC input
    ST     self-test; leave unconnected (see SELF-TEST)

The chain is sensor -> ADC -> Pi. With an ADS1115 breakout:

    ADXL335 VCC -> Pi 3.3 V        ADS1115 VDD -> Pi 3.3 V
    ADXL335 GND -> Pi GND          ADS1115 GND -> Pi GND
    ADXL335 X   -> ADS1115 A0      ADS1115 SCL -> Pi GPIO 3
    ADXL335 Y   -> ADS1115 A1      ADS1115 SDA -> Pi GPIO 2
    ADXL335 Z   -> ADS1115 A2

Two cautions. The bare chip's absolute maximum supply is 3.6 V - feed a
bare ADXL335 from the Pi's 3.3 V pin, never 5 V. Many breakouts add an
onboard regulator so their C<VCC> accepts 5 V, but then the I<chip> is
running at the regulator's output (usually 3.3 V) - C<vs> describes the
chip's supply, not the board input. Second, the outputs come through
internal 32 kohm resistors; a high-impedance ADC input (the ADS1x15
family) reads them accurately, but the MCP3008's sample-and-hold charges
through that 32 k and can read slightly low - average a few samples, or
buffer through an op amp follower if you need every last count.

=head2 RATIOMETRIC SCALING AND CALIBRATION

The ADXL335's output is ratiometric to its supply. At Vs = 3 V the
datasheet numbers are 300 mV/g sensitivity and a Vs / 2 (1.5 V) zero g
point; scale the supply and both scale with it:

    Vs       zero g (Vs / 2)    sensitivity (~0.1 x Vs)
    2.0 V    1.00 V             195 mV/g
    3.0 V    1.50 V             300 mV/g
    3.3 V    1.65 V             330 mV/g
    3.6 V    1.80 V             360 mV/g

This module turns voltage into acceleration with exactly that model:

    g = (volts - zero_g) / sensitivity

where C<zero_g> defaults to C<vs / 2> and C<sensitivity> to
C<0.1 * vs>. The catch is part-to-part tolerance. At 3 V, the X and Y
zero g points are specified anywhere from 1.35 V to 1.65 V - that
+/-150 mV is a raw error of up to B<half a g> - and the Z axis is
looser still at 1.2 V to 1.8 V, up to a B<full g>. Sensitivity holds
much tighter (270-330 mV/g).

Hence L</calibrate>: set the sensor down level and still, let it
measure its own zero points, and persist the returned voltages to feed
back into C<new()>'s C<zero_g> param on later runs. Temperature drift
after that is minor (roughly +/-1 mg/C).

=head2 BANDWIDTH AND FILTER CAPACITORS

Each output pin needs a capacitor to ground; together with the internal
32 kohm resistor it forms the low-pass filter that sets that axis'
bandwidth, limits noise, and prevents aliasing:

    F(-3 dB) = 5 uF / C

    bandwidth    capacitor
    ----------------------
    1 Hz         4.7 uF
    10 Hz        0.47 uF
    50 Hz        0.10 uF
    100 Hz       0.05 uF
    200 Hz       0.027 uF
    500 Hz       0.01 uF

A minimum of 0.0047 uF is required in all cases; typical breakout
boards ship 0.1 uF, so ~50 Hz per axis. Noise scales with the square
root of bandwidth:

    rms noise = noise density x sqrt(bandwidth x 1.6)

At 50 Hz that works out to ~1.3 mg rms on X/Y (double it for Z), with
peak-to-peak excursions of roughly 4x rms - tilt resolution of a
fraction of a degree. For slow tilt work, a bigger capacitor buys a
quieter signal; keep the bandwidth at or below half your ADC sampling
rate either way, or aliasing folds the noise right back in.

=head2 SELF-TEST

Driving the C<ST> pin to Vs deflects the sensor beam electrostatically,
letting you prove each axis is alive without moving anything: at 3 V,
X shifts about -325 mV, Y about +325 mV, and Z about +550 mV (-1.08 g,
+1.08 g, +1.83 g). Ground C<ST> (or leave it open) for normal
operation, and never drive it above Vs + 0.3 V. The response in volts
scales roughly with the cube of Vs.

Wire C<ST> to a spare GPIO (at a 3.3 V supply, a GPIO high is close
enough to Vs) and you can self-test from software: read L</volts>,
raise the pin, read again, and compare the shifts.

=head2 AXES AND ORIENTATION

    Az
    |     Ay
    |    /
    |   /
    |  /
    | /
    +----------- Ax

Output voltage increases when the package accelerates along a positive
axis. Held still, each axis reads the component of gravity along it: a
positive axis pointing straight up reads C<+1> g, straight down C<-1>
g, horizontal C<0> g. The six cardinal orientations:

    orientation (gravity down)    x       y       z
    ------------------------------------------------
    flat, top side up             0 g     0 g    +1 g
    flat, top side down           0 g     0 g    -1 g
    on edge, +X end up           +1 g     0 g     0 g
    on edge, +X end down         -1 g     0 g     0 g
    on edge, +Y end up            0 g    +1 g     0 g
    on edge, +Y end down          0 g    -1 g     0 g

L</tilt> turns those static components into angles:

    pitch = atan2( gx, sqrt(gy^2 + gz^2) )
    roll  = atan2( gy, gz )

The three axes come off a single micromachined structure, so they're
highly orthogonal (cross-axis sensitivity is ~1%); what error remains
is mostly mechanical alignment of the die in the package (+/-1 degree),
which the mounting of the board itself usually dwarfs anyway.

=head2 POWER

Decouple the supply with a 0.1 uF capacitor right at the chip (breakout
boards include it). The outputs are valid roughly C<160 x C + 1>
milliseconds after power-up (C in uF) - about 17 ms with the usual
0.1 uF filters - so there's no meaningful warm-up to wait through.

=head1 SEE ALSO

L<RPi::ADC::ADS> and L<RPi::ADC::MCP3008>, the ADC distributions this
module is designed to ride on, and L<RPi::WiringPi>, the top-level
distribution of the RPi:: ecosystem.

The ADXL335 datasheet:
L<https://www.analog.com/media/en/technical-documentation/data-sheets/ADXL335.pdf>

=head1 AUTHOR

Steve Bertrand, C<< <steveb at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2026 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>
