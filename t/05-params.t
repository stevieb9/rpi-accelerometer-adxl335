#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

use RPi::Accelerometer::ADXL335;

# These exercise the parameter validation paths only; the mock ADC at
# the bottom of this file is never actually read, so no hardware (nor
# any real ADC distribution) is required

plan tests => 23;

my $ok = eval {
    RPi::Accelerometer::ADXL335->new;
    1;
};
is $ok, undef, "new() dies without an adc param";
like $@, qr/adc param/, "...with a relevant error message";

$ok = eval {
    RPi::Accelerometer::ADXL335->new(adc => 'not an object');
    1;
};
is $ok, undef, "new() dies with an unblessed adc param";
like $@, qr/adc param/, "...with a relevant error message";

$ok = eval {
    RPi::Accelerometer::ADXL335->new(adc => NoReadADC->new);
    1;
};
is $ok, undef, "new() dies if the ADC can't read";
like $@, qr/volts\(\) or percent\(\)/, "...naming the methods it looked for";

my $adc = MockADC->new;

eval { RPi::Accelerometer::ADXL335->new(adc => $adc); };
like $@, qr/x param/, "new() requires the x channel param";

eval { RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0); };
like $@, qr/y param/, "new() requires the y channel param";

eval { RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1); };
like $@, qr/z param/, "new() requires the z channel param";

eval { RPi::Accelerometer::ADXL335->new(adc => $adc, x => 'abc', y => 1, z => 2); };
like $@, qr/x param/, "new() rejects a non-integer channel";

eval { RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2, vs => 'abc'); };
like $@, qr/vs param/, "new() validates the vs param";

eval { RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2, vs => 0); };
like $@, qr/vs param/, "new() rejects a zero vs";

eval { RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2, vref => 'abc'); };
like $@, qr/vref param/, "new() validates the vref param";

eval { RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2, sensitivity => 0); };
like $@, qr/\$v_per_g param/, "new() validates the sensitivity param";

eval { RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2, zero_g => 'abc'); };
like $@, qr/\$offsets param/, "new() requires zero_g to be a hashref";

eval { RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2, zero_g => { q => 1.5 }); };
like $@, qr/axis keys/, "new() rejects unknown zero_g axes";

eval { RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2, zero_g => { x => 'abc' }); };
like $@, qr/x value/, "new() rejects non-numeric zero_g voltages";

my $accel = RPi::Accelerometer::ADXL335->new(adc => $adc, x => 0, y => 1, z => 2);

eval { $accel->g('q'); };
like $@, qr/\$axis param/, "g() validates the axis";

eval { $accel->volts('q'); };
like $@, qr/\$axis param/, "volts() validates the axis";

eval { $accel->calibrate('abc'); };
like $@, qr/\$samples param/, "calibrate() validates the sample count";

eval { $accel->calibrate(0); };
like $@, qr/\$samples param/, "calibrate() rejects a zero sample count";

eval { $accel->sensitivity('abc'); };
like $@, qr/\$v_per_g param/, "sensitivity() validates its param";

eval { $accel->zero_g([1.65]); };
like $@, qr/\$offsets param/, "zero_g() requires a hashref";

# The stand-in transports: one that reads, one that can't

package MockADC;

sub new {
    return bless {}, shift;
}
sub volts {
    return 1.65;
}

package NoReadADC;

sub new {
    return bless {}, shift;
}
