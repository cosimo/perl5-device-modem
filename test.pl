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

print "\n\n*** REMEMBER to run these tests as `root' (where required)!\n\n";
sleep 2;

my %config;
if( open CACHED_CONFIG, '< .config' ) {
	while( <CACHED_CONFIG> ) {
		my @t = split /[\s\t]+/;
		$config{ $t[0] } = $t[1];
	}
	close CACHED_CONFIG;
}

if( $config{'tty'} ) {

	print "Your serial port is `$config{'tty'}' (cached)\n";

} else {

	$config{'tty'} = $^O =~ /Win32/i ? 'COM1' : '/dev/ttyS1';
	my $port;

	print "What is your serial port? [$config{'tty'}] ";
	chomp( $port = <STDIN> );
	$port ||= $config{'tty'};

	if( open( CONFIG, '>.config' ) ) {
		print CONFIG "tty\t$port\n";
		close CONFIG;
	}

}

# -----------------------------------------------------
# BEGIN OF TESTS
# -----------------------------------------------------

my $modem = new Device::Modem( serial => $port );

if( $modem->connect ) {
	print "ok 2\n";
} else {
	print "not ok 2\n";
	die "cannot connect to $port serial port!: $!";
}

# Try with AT escape code
$modem->atsend('+++');
my $ans = $modem->answer();
print 'sending +++, modem says `', $ans, "'\n";

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
}


# This must generate an error!
$modem->atsend('AT@x@@!$#'.Device::Modem::CR);
$ans = $modem->answer();
print 'sending erroneous AT command, modem says `', $ans, "'\n";

if( $ans =~ /ERROR/ ) {
	print "ok 5\n";
} else {
	print "not ok 5\n";
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
}



print 'testing echo enable/disable...', "\n";
if( $modem->echo(1) && $modem->echo(0) ) {
	print "ok 7\n";

} else {
	print "not ok 7\n";
}

print 'testing offhook function...', "\n";
print $modem->offhook();

sleep(1);

print 'hanging up...', "\n";
print $modem->hangup();

print "ok 8\n";

