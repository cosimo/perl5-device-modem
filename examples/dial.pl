# $Id: dial.pl,v 1.1 2002-06-03 19:00:44 Cosimo Exp $
#
# This script tries to dial a number taken from STDIN
# or as first argument.
# 
# Example:
#   perl dial.pl 012,3456789
#
# 03/06/2002 Cosimo
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

my $modem = new Device::Modem( port => $port );

if( $modem->connect( baudrate => $config{'baud'} || 19200 ) ) {
	print "ok connected.\n";
} else {
	die "cannot connect to $port serial port!: $!";
}

my $number = $ARGV[0];

while( ! $number ) {
	print "\nInsert the number to dial: \n";
	$number = <STDIN>;
	chomp $number;
	$number =~ s/\D//g;
}

print '- trying to dial [', $number, ']', "\n";

if( $lOk = $modem->dial($number,30) ) {

	print "Ok, number dialed\n";

} else {

	print "No luck!\n";

}
