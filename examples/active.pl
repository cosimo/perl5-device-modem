# $Id: active.pl,v 1.2 2002-09-03 19:39:39 cosimo Exp $
#
# This script tries to test if modem is active (on and enabled)
# If modem is not active, tries to reset it.
#
# As I know, this script works to the extent as it:
#
# 1) Fails if modem is turned off
# 2) Succeeds if modem is turned on
#
# It's not a big thing, I know ... :-(
#

use Device::Modem;

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

	$config{'tty'} = $^O =~ /Win32/i ? 'COM1' : '/dev/ttyS1';
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

if( $modem->connect( baudrate => $config{'baud'} || 19200 ) ) {
	print "ok 2\n";
} else {
	print "not ok 2\n";
	die "cannot connect to $port serial port!: $!";
}

print '- testing if modem is turned on and available', "\n";

my $lOk = 0;

if( $lOk = $modem->is_active() ) {

	print "Ok, modem is active\n";

} else {

	print "NO! Modem is turned off, or not functioning...\n";

}
