# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..6\n"; }
END {print "not ok 1\n" unless $loaded;}
use lib '.';
use Modem;

$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):


# Load Makefile settings
require '.config.pm';

# If non-win platforms and user is not root, skip tests
# because they access serial port (only accessible under root user)

my $is_windoze = $^O =~ /Win/i;

if( ! $is_windoze && ( $< || $> ) ) {
	print "\n\n*** SKIPPING tests. You need root privileges to test modems on serial ports. Sorry\n";
	skip(1) for (1..6);
	exit(0);
}


print "\n\n*** REMEMBER to run these tests as `root' (where required)!\n\n"
        unless $is_windoze;

sleep 1;

if( $Device::Modem::port eq 'NONE' || $Device::Modem::port eq '' ) {

	print "\n\n    [ No serial port set up, so no tests will be executed...\n";
	print "    [ To enable tests, re-run `perl Makefile.PL' command.\n";

	print "skip $_\n" for (2..6);

	exit;

} else {

	print "Your serial port is `$Device::Modem::port' (configured by Makefile.PL)\n";
	print "Link baud rate   is `$Device::Modem::baudrate' (configured by Makefile.PL)\n";

}

# -----------------------------------------------------
# BEGIN OF TESTS
# -----------------------------------------------------

# If tests that increment this counter all *fail*,
# then almost certainly you don't have a gsm device
# connected to your serial port or maybe it's the wrong
# serial port
my $not_connected_guess;

# test syslog logging
# my $modem = new Device::Modem( port => $port, log => 'syslog' );

# test text file logging
my $port = $Device::Modem::port;
my $baud = $Device::Modem::baudrate;

my $modem = new Device::Modem( port => $port );

if( $modem->connect(baudrate => $baud) ) {
	print "ok 2\n";
} else {
	print "not ok 2\n";
	die "cannot connect to $port serial port!: $!";
}


# Try with AT escape code
my $ans = $modem->attention();
print 'sending attention, modem says `', $ans, "'\n";

if( $ans eq '' ) {
	print "ok 3\n";
} else {
	print "not ok 3\n";
}

# Send empty AT command
$modem->atsend('AT'.Device::Modem::CR);
$ans = $modem->answer();
print 'sending AT, modem says `', $ans, "'\n";

if( $ans =~ /OK/ ) {
	print "ok 4\n";
} else {
	print "not ok 4\n";
	$not_connected_guess++;
}


# This must generate an error!
$modem->atsend('AT@x@@!$#'.Device::Modem::CR);
$ans = $modem->answer();
print 'sending erroneous AT command, modem says `', $ans, "'\n";

if( $ans =~ /ERROR/ ) {
	print "ok 5\n";
} else {
	print "not ok 5\n";
	$not_connected_guess++;
}

$modem->atsend('AT'.Device::Modem::CR);
$modem->answer();

$modem->atsend('ATZ'.Device::Modem::CR);
$ans = $modem->answer();
print 'sending ATZ reset command, modem says `', $ans, "'\n";

if( $ans =~ /OK/ ) {
	print "ok 6\n";
} else {
	print "not ok 6\n";
	$not_connected_guess++;
}



print 'testing echo enable/disable...', "\n";
if( $modem->echo(1) && $modem->echo(0) ) {
	print "ok 7\n";

} else {
	print "not ok 7\n";
	$not_connected_guess++;
}

print 'testing offhook function...', "\n";
if( $modem->offhook() ) {
	print "ok 8\n";
} else {
	print "not ok 8\n";
}

sleep(1);

# 9
print 'hanging up...', "\n";
if( $modem->hangup() =~ /OK/ ) {
	print "ok 9\n";
} else {
	print "not ok 9\n";
	$not_connected_guess++;
}


# --- 10 ---
print 'testing is_active() function...', "\n";
if( $modem->is_active() ) {
	print "ok 10\n";
} else {
	print "not ok 10\n";
	$not_connected_guess += 10;
}


if( $not_connected_guess >= 4 ) {


	print <<EOT;

--------------------------------------------------------
Results of your test procedure indicate
almost certainly that you *DON'T HAVE* a modem device
connected to your *serial port* or maybe it's the wrong
port.
--------------------------------------------------------

EOT

	sleep 2;

}

