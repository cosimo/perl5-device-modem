#!/usr/bin/perl

use strict;
use Device::Modem;

my $port = '/dev/ttyS0';
my $modem = new Device::Modem ( serial => $port, baud => 9600 );
my $stop;

die "Could not connect to $port!\n" unless $modem->connect();


print "Connected to $port.\n\n";

while( not $stop ) {

	print "insert AT command to send\n";
	print "> ";

	my $AT = <STDIN>;
	chomp $AT;

	if( $AT eq 'stop' ) {
		$stop = 1;
	} else {
		$modem->atsend( $AT . "\r\n" );
		print "\n", $modem->answer(), "\n";

	}

}

print "Done.\n";

