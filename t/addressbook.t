# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}
use lib '..';
use Modem;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

$|++;

my $port = $ENV{'DEV_MODEM_PORT'};
my $baud = $ENV{'DEV_MODEM_BAUD'};

if( !$port || !$baud ) {
	print "ok 2\n";
	print "ok 3\n";
	exit;
}

my $modem = new Device::Modem( port => $port );

if( $modem->connect( baudrate => $baud ) ) {
	print "ok 2\n";
} else {
	print "not ok 2\n";
	die "cannot connect to $port serial port!: $!";
}

print 'testing address book numbers storing', "\n";

my $ok1 = $modem->store_number(0, '10880432090000');
my $ok2 = $modem->store_number(1, '0432,649062' );

if( $ok1 && $ok2 ) {
	print "ok 3\n";
} else {
	print "not ok 3\n";
}

