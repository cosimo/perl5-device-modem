# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..4\n"; }
END {print "not ok 1\n" unless $loaded;}
use lib '..';
use Device::Modem;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my %config;
if( open CACHED_CONFIG, '< ../.config' ) {
	while( <CACHED_CONFIG> ) {
		my @t = split /[\s\t]+/;
		$config{ $t[0] } = $t[1];
	}
	close CACHED_CONFIG;
}

if( $config{'tty'} ) {

	print "Your serial port is `$config{'tty'}' (cached)\n";

} else {

	$config{'tty'} = $Device::Modem::DEFAULT_PORT;
	my $port;

	print "What is your serial port? [$config{'tty'}] ";
	chomp( $port = <STDIN> );
	$port ||= $config{'tty'};

	if( open( CONFIG, '>../.config' ) ) {
		print CONFIG "tty\t$port\n";
		close CONFIG;
	}

}

# -----------------------------------------------------
# BEGIN OF TESTS
# -----------------------------------------------------

my $modem = new Device::Modem( port => $port );

if( $modem->connect ) {
	print "ok 2\n";
} else {
	print "not ok 2\n";
	die "cannot connect to $port serial port!: $!";
}

print '- testing echo enable/disable', "\n";
my $lOk = 1;

if( ! $modem->echo(1) )
{
    print "not ok 3\n";
    print "not ok 4\n";
}
else 
{

    print "ok 3\n", "\t", 'sending AT@@@ string...', "\n";

	$modem->atsend('AT@@@'.Device::Modem::CR);
	my $ans = $modem->answer();
	$ans =~ s/[\r\n]/^M/g;

	print "\t", 'answer with echo on = ', $ans, "\n";

	$lOk &&= ( $ans =~ /AT@@@/ && $ans =~ /ERROR/ );

	$lOk &&= $modem->echo(0);

	$modem->atsend('AT@@@'.Device::Modem::CR);
	$ans = $modem->answer();
	print "\t", 'answer with echo off = ', $ans, "\n";

	$lOk &&= ( $ans =~ /ERROR/ );

	if( $lOk ) {
		print "ok 4\n";
	} else {
		print "not ok 4\n";
	}
}

