#!/usr/bin/perl
#
# $Id: shell.pl,v 1.4 2002-04-03 20:02:44 cosimo Exp $
#

use strict;
use Device::Modem;

if( $> && $< ) {
	print "\n*** REMEMBER to run this program as root if you cannot connect on serial port!\n";
	sleep 3;
}

print "Your serial port? [/dev/ttyS1]\n";
my $port = <STDIN>;
chomp $port;

$port ||= '/dev/ttyS1';

my $modem = new Device::Modem ( port => $port, baud => 9600 );
my $stop;

die "Could not connect to $port!\n" unless $modem->connect();


print "Connected to $port.\n\n";

while( not $stop ) {

	print "insert AT command (`stop' to quit)\n";
	print "> ";

	my $AT = <STDIN>;
	chomp $AT;

	if( $AT eq 'stop' ) {
		$stop = 1;
	} else {
		$modem->atsend( $AT . "\r\n" );
		print $modem->answer(), "\n";

	}

}

print "Done.\n";

