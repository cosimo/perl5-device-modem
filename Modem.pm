# Device::Modem - a Perl class to interface generic modems (AT-compliant)
#
# Copyright (C) 2002 Cosimo Streppone, cosimo@cpan.org
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Additionally, this is ALPHA software, still needs extensive
# testing and support for generic AT commads, so use it at your own risk,
# and without ANY warranty! Have fun.
#
# $Id: Modem.pm,v 1.24 2002-12-03 23:37:04 cosimo Exp $

package Device::Modem;
$VERSION = sprintf '%d.%02d', q$Revision: 1.24 $ =~ /(\d)\.(\d+)/;

BEGIN {

	if( $^O =~ /Win/io ) {

		require Win32::SerialPort;
		import  Win32::SerialPort;

		# Import line status constants from Win32::SerialPort module
		*Device::Modem::MS_CTS_ON  = *Win32::SerialPort::MS_CTS_ON;
		*Device::Modem::MS_DSR_ON  = *Win32::SerialPort::MS_DSR_ON;
		*Device::Modem::MS_RING_ON = *Win32::SerialPort::MS_RING_ON;
		*Device::Modem::MS_RLSD_ON = *Win32::SerialPort::MS_RLSD_ON;

	} else {

		require Device::SerialPort;
		import  Device::SerialPort;

		# Import line status constants from Device::SerialPort module
		*Device::Modem::MS_CTS_ON = *Device::SerialPort::MS_CTS_ON;
		*Device::Modem::MS_DSR_ON = *Device::SerialPort::MS_DSR_ON;
		*Device::Modem::MS_RING_ON = *Device::SerialPort::MS_RING_ON;
		*Device::Modem::MS_RLSD_ON = *Device::SerialPort::MS_RLSD_ON;

	}
}

use strict;

# Constants definition
use constant CTRL_Z => chr(26);

# TODO
# Allow to redefine CR to "\r", "\n" or "\r\n"
use constant CR => "\r";

# Connection defaults
$Device::Modem::DEFAULT_PORT = ( $^O =~ /Win/io ) ? 'COM1' : '/dev/modem';
$Device::Modem::BAUDRATE = 19200;
$Device::Modem::DATABITS = 8;
$Device::Modem::STOPBITS = 1;
$Device::Modem::PARITY   = 'none';
$Device::Modem::TIMEOUT  = 500;     # milliseconds;


# Setup text and numerical response codes
@Device::Modem::RESPONSE = ( 'OK', undef, 'RING', 'NO CARRIER', 'ERROR', undef, 'NO DIALTONE', 'BUSY' );
#%Device::Modem::RESPONSE = (
#	'OK'   => 'Command executed without errors',
#	'RING' => 'Detected phone ring',
#	'NO CARRIER'  => 'Link not established or disconnected',
#	'ERROR'       => 'Invalid command or command line too long',
#	'NO DIALTONE' => 'No dial tone, dialing not possible or wrong mode',
#	'BUSY'        => 'Remote terminal busy'
#);

# object constructor (prepare only object)
sub new {
	my($proto,%aOpt) = @_;                  # Get reference to object
	                                        # Options of object
	my $class = ref($proto) || $proto;      # Get reference to class

	$aOpt{'ostype'} = $^O;                  # Store OSTYPE in object
	$aOpt{'ostype'} =~ /Win/io and $aOpt{'ostype'} = 'windoze';

	# Initialize flags array
	$aOpt{'flags'} = {};

	$aOpt{'port'} ||= $Device::Modem::DEFAULT_PORT;

	# Instance log object
	$aOpt{'log'} ||= 'file';

	# Force logging to file if this is windoze and user requested syslog mechanism
	$aOpt{'log'} = 'file' if( $aOpt{'ostype'} eq 'windoze' && $aOpt{'log'} =~ /syslog/i );

	my($method, @options) = split ',', delete $aOpt{'log'};
	my $logclass = 'Device/Modem/Log/'.ucfirst(lc $method).'.pm';
	my $package = 'Device::Modem::Log::'.ucfirst lc $method;
	eval { require $logclass; };
	unless($@) {
		$aOpt{'_log'} = $package->new( $class, @options );
	}

	bless \%aOpt, $class;                   # Instance $class object
}

sub attention {
	my $self = shift;

	$self->log->write('info', 'sending attention sequence...');

	# Send attention sequence
	$self->atsend('+++');

	# Wait 200 milliseconds
	$self->wait(200);

	$self->answer();
}

#
# Dial telephone number
#
# dial( number, timeout )
# example: dial( '0289011124', 45 ) (timeout in seconds)
#
# if number to dial is 1-digit, takes number from address book
# [ see store_number() ]
#
sub dial {
	my($self, $number, $timeout) = @_;
	my $lOk = 0;

	# Default timeout in seconds
	$timeout ||= 30;

	# Check if we have already dialed some number...
	if( $self->flag('CARRIER') ) {
		$self->log->write( 'warning', 'line is already connected, ignoring dial()' );
		return;
	}

	# Check if no number supplied
	if( ! defined $number ) {
		#
		# XXX Here we could enable ATDL command (dial last number)
		#
		$self->log->write( 'warning', 'cannot dial without a number!' );
		return;
	}

	# Remove all non number chars plus some others allowed
	$number =~ s/[^0-9,\(\)\*\-\s]//g;

	# Dial number and wait for response
	if( length $number == 1 ) {
		$self->log->write('info', 'dialing address book number ['.$number.']' );
		$self->atsend( 'ATDS' . $number . CR );
	} else {
		$self->log->write('info', 'dialing number ['.$number.']' );
		$self->atsend( 'ATDT' . $number . CR );
	}

	# XXX Check response times here (timeout!)
	my $ans = $self->answer(undef, $timeout * 1000 );

	if( index( $ans, 'CONNECT' ) > -1 ) {
		$lOk = 1;
	}

	# Turn on/off `CARRIER' flag
	$self->flag('CARRIER', $lOk);

	$self->log->write('info', 'dialing result = '.$lOk);
	return $lOk;
}

# Enable/disable local echo of commands (enabling echo can cause everything else to fail, I think)
sub echo {
	my($self, $lEnable) = @_;

	$self->log->write( 'info', ( $lEnable ? 'enabling' : 'disabling' ) . ' echo' );
	$self->atsend( ($lEnable ? 'ATE1' : 'ATE0') . CR );

	$self->answer('OK');
}

# Terminate current call (XXX not tested)
sub hangup {
	my $self = shift;

	$self->log->write('info', 'hanging up...');
	$self->attention();
	$self->atsend( 'ATH0' . CR );
	$self->_reset_flags();
	$self->answer();
}

# Checks if modem is enabled (for now, it works ok for modem OFF/ON case)
sub is_active {
	my $self = shift;
	my $lOk;

	$self->log->write('info', 'testing modem activity on port '.$self->options->{'port'} );

	# Modem is active if already connected to a line
	if( $self->flag('CARRIER') ) {


		$self->log->write('info', 'carrier is '.$self->flag('CARRIER').', modem is connected, it should be active');
		$lOk = 1;

	} else {

		# Try sending an echo enable|disable command
		$self->attention();
		$self->verbose(0);
		$lOk = $self->verbose(1);

		# If we have no success, try to reset
		if( ! $lOk ) {
			$self->log->write('warning', 'modem not responding... trying to reset');
			$lOk = $self->reset();
		}

	}

	$self->log->write('info', 'modem reset result = '.$lOk);

	return $lOk;
}

# Take modem off hook, prepare to dial
sub offhook {
	my $self = shift;

	$self->log->write('info', 'taking off hook');
	$self->atsend( 'ATH1' . CR );

	$self->flag('OFFHOOK', 1);

	return 1;
}

# Get/Set S* registers value:  S_register( number [, new_value] )
# returns undef on failure ( zero is a good value )
sub S_register {
	my $self = shift;
	my $register = shift;
	my $value = 0;

	return unless $register;

	my $ok;

	# If `new_value' supplied, we want to update value of this register
	if( @_ ) {

		my $new_value = shift;
		$new_value =~ s|\D||g;
		$self->log->write('info', 'storing value ['.$new_value.'] into register S'.$register);
		$self->atsend( sprintf( 'AT S%02d=%d' . CR, $register, $new_value ) );


		$value = ( index( $self->answer, 'OK' ) != -1 ) ? $new_value : undef;

	} else {

		$self->atsend( sprintf( 'AT S%d?' . CR, $register ) );
		($ok, $value) = $self->parse_answer();

		if( index($ok, 'OK') != -1 ) {
			$self->log->write('info', 'value of S'.$register.' register seems to be ['.$value.']');
		} else {
			$value = undef;
			$self->log->write('error', 'error reading value of S'.$register.' register');
		}

	}

	# Return updated value of register
	$self->log->write('info', 'S'.$register.' = '.$value);

	return $value;
}

# Repeat the last commands (this comes gratis with `A/' at-command)
sub repeat {
	my $self = shift;

	$self->log->write('info', 'repeating last command' );
	$self->atsend( 'A/' . CR );

	$self->answer();
}

# Complete modem reset
sub reset {
	my $self = shift;

	$self->log->write('warning', 'resetting modem on '.$self->{'port'} );
	$self->hangup();
	$self->send_init_string();
	$self->_reset_flags();
	return $self->answer();
}

# Return an hash with the status of main modem signals
sub status {
	my $self = shift;
	$self->log->write('info', 'getting modem line status on '.$self->{'port'});

	# This also relies on Device::SerialPort
	my $status = $self->port->modemlines();

	# See top of module for these constants, exported by (Win32|Device)::SerialPort
	my %signal = (
		CTS  => $status & Device::Modem::MS_CTS_ON,
		DSR  => $status & Device::Modem::MS_DSR_ON,
		RING => $status & Device::Modem::MS_RING_ON,
		RLSD => $status & Device::Modem::MS_RLSD_ON
	);

	$self->log->write('info', 'modem on '.$self->{'port'}.' status is ['.$status.']');
	$self->log->write('info', "CTS=$signal{CTS} DSR=$signal{DSR} RING=$signal{RING} RLSD=$signal{RLSD}");

	return %signal;
}

# Of little use here, but nice to have it
# restore_factory_settings( profile )
# profile can be 0 or 1
sub restore_factory_settings {
	my $self = shift;
	my $profile = shift;
	$profile = 0 unless defined $profile;

	$self->log->write('warning', 'restoring factory settings '.$profile.' on '.$self->{'port'} );
	$self->atsend( 'AT&F'.$profile . CR);

	$self->answer();
}

# Store telephone number in modem's internal address book, to dial later
# store_number( position, number )
sub store_number {
	my( $self, $position, $number ) = @_;
	my $lOk = 0;

	# Check parameters
	unless( defined($position) && $number ) {
		$self->log->write('warn', 'store_number() called with wrong parameters');
		return $lOk;
	}

	$self->log->write('info', 'storing number ['.$number.'] into memory ['.$position.']');

	# Remove all non-numerical chars from position and number
	$position =~ s/\D//g;
	$number   =~ s/[^0-9,]//g;

	$self->atsend( sprintf( 'AT &Z%d=%s' . CR, $position, $number ) );

	if( index( $self->answer(), 'OK' ) != -1 ) {
		$self->log->write('info', 'stored number ['.$number.'] into memory ['.$position.']');
		$lOk = 1;
	} else {
		$self->log->write('warn', 'error storing number ['.$number.'] into memory ['.$position.']');
		$lOk = 0;
	}

	return $lOk;
}

# Enable/disable verbose response messages against numerical response messages
# XXX I need to manage also numerical values...
sub verbose {
	my($self, $lEnable) = @_;

	$self->log->write( 'info', ( $lEnable ? 'enabling' : 'disabling' ) . ' verbose messages' );
	$self->atsend( ($lEnable ? 'ATQ0V1' : 'ATQ0V0') . CR );

	$self->answer('OK');
}


sub wait {
	my( $self, $msec ) = @_;

	$self->log->write('info', 'waiting for '.$msec.' msecs');

	# Perhaps Time::HiRes here is not so useful, since I tested `select()' system call also on Windows
	select( undef, undef, undef, $msec / 1000 );
	return 1;

}

# Set a named flag. Flags are now: OFFHOOK, CARRIER
sub flag {
	my $self = shift;
	my $cFlag = uc shift;

	$self->{'_flags'}->{$cFlag} = shift() if @_;

	$self->{'_flags'}->{$cFlag};
}

# reset internal flags that tell the status of modem (XXX to be extended)
sub _reset_flags {
	my $self = shift();

	map { $self->flag($_, 0) }
		'OFFHOOK', 'CARRIER';
}

# initialize modem with some basic commands (XXX &C0)
sub send_init_string {
	my($self, $cInit) = @_;
	$self->attention();
	$self->atsend( 'AT H0 Z S7=45 S0=0 Q0 V1 E0 &C0 X4' . CR );
	#$self->atsend( 'AT Z' . CR );
	$self->answer();
}

# returns log object reference
sub log {
	shift()->{'_log'}
}

# instances (Device|Win32)::SerialPort object and initializes communications
sub connect {
	my $me = shift();

	my %aOpt = ();
	if( @_ ) {
		%aOpt = @_;
	}

	my $lOk = 0;

	# Set default values if missing
	$aOpt{'baudrate'} ||= $Device::Modem::BAUDRATE;
	$aOpt{'databits'} ||= $Device::Modem::DATABITS;
	$aOpt{'parity'}   ||= $Device::Modem::PARITY;
	$aOpt{'stopbits'} ||= $Device::Modem::STOPBITS;

	# Store communication options in object
	$me->{'_comm_options'} = \%aOpt;

	# Connect on serial (use different mod for win32)
	if( $me->ostype eq 'windoze' ) {
		$me->port( new Win32::SerialPort($me->{'port'}) );
	} else {
		$me->port( new Device::SerialPort($me->{'port'}) );
	}

	# Check connection
	unless( ref $me->port ) {
		$me->log->write( 'error', '*FAILED* connect on '.$me->{'port'} );
		return $lOk;
	}

	# Set communication options
	my $oPort = $me->port;
	$oPort -> baudrate ( $me->options->{'baudrate'} );
	$oPort -> databits ( $me->options->{'databits'} );
	$oPort -> stopbits ( $me->options->{'stopbits'} );
	$oPort -> parity   ( $me->options->{'parity'}   );

	# Non configurable options
	$oPort -> buffers         ( 10000, 10000 );
	$oPort -> handshake       ( 'none' );
	$oPort -> read_const_time ( 100 );           # was 500
	$oPort -> read_char_time  ( 10 );

	$oPort -> are_match       ( 'OK' );
	$oPort -> lookclear;

	$oPort -> write_settings;
	$oPort -> purge_all;

	$me-> log -> write('info', 'sending init string...' );

	$me-> send_init_string();
	$me-> _reset_flags();

	# Disable local echo
	$me-> echo(0);

	$me-> log -> write('info', 'Ok connected' );
	$me-> {'CONNECTED'} = 1;

}

# $^O is stored into object
sub ostype {
	my $self = shift;
	$self->{'ostype'};
}

# returns Device::SerialPort reference to hash options
sub options {
	my $self = shift();
	@_ ? $self->{'_comm_options'} = shift()
	   : $self->{'_comm_options'};
}

# returns Device::SerialPort object handle
sub port {
	my $self = shift();
	@_ ? $self->{'_comm_object'} = shift()
	   : $self->{'_comm_object'};
}

# disconnect serial port
sub disconnect {
	my $me = shift;
	$me->port->close();
	$me->log->write('info', 'Disconnected from '.$me->{'port'} );
}

# Send AT command to device on serial port (command must include CR for now)
sub atsend {
	my( $me, $msg ) = @_;
	my $cnt = 0;

	# Write message on port
	$me->port->purge_all();
	$cnt = $me->port->write($msg);
	$me->port->write_drain() unless $me->ostype eq 'windoze';

	$me->log->write('verbose', 'atsend: wrote '.$cnt.'/'.length($msg).' chars');

	# If wrote all chars of `msg', we are successful
	return $cnt == length $msg;
}

# answer() takes strings from the device until a pattern
# is encountered or a timeout happens.
sub answer {
	my $me = shift;
	my($expect, $timeout) = @_;

	$timeout ||= 200;                           # default wait (ms)
	my $time_slice = 100;                       # single cycle wait time

	my $max_idle_cycles = $timeout / $time_slice;

	# If we expect something, we must first match against serial input
	my $done = (defined $expect and $expect ne '');

	$time_slice /= 1000;

	$me->log->write('verbose', 'answer: expecting ['.($expect||'').'] or timeout ['.$timeout.']' );

	# Main read cycle
	my $idle_cycles = 0;
	my $answer;
	do {
		my($howmany, $what) = $me->port->read(100);

		# Timeout count incremented only on empty readings
		if( defined $what && $howmany > 0 ) {
			$answer .= $what;
			$idle_cycles = 1;
		} else {
			$idle_cycles++;
		}

		# Check if buffer matches "expect string"
		#$done = $expect
		#	? $answer =~ /$expect/
		#	: $idle_cycles == $max_idle_cycles;
		$done++ if $expect && $answer =~ /$expect/;
		$done++ if $idle_cycles == $max_idle_cycles;

		$me->log->write('debug', 'answer: idle_c='.$idle_cycles.'/'.$max_idle_cycles.' read_till_now='.($answer||'').' matched='.$done);

		select(undef, undef, undef, $time_slice) unless $done;

	} while( not $done );

	$me->log->write('debug', 'answer: read ['.($answer||'').']' );

	# Flush receive and trasmit buffers
	$me->port->purge_all;

	# Trim result of beginning and ending CR+LF (XXX)
	if( defined $answer ) {
		$answer =~ s/^[\r\n]+//;
		$answer =~ s/[\r\n]+$//;
	}

	$me->log->write('info', 'answer: `'.($answer||'').'\'' );

	return $answer;
}


# parse_answer() cleans out answer() result as response code +
# useful information (useful in informative commands, for example
# Gsm command AT+CGMI)
sub parse_answer {
	my $me = shift;

	my $buff = $me->answer( @_ );

	# Separate response code from information
	my @response = split CR, $buff;

	# Remove all empty lines before/after response
	shift @response while( $response[0] eq CR() );
	pop   @response while( $response[-1] eq CR() );

	# Extract responde code
	my $code = pop @response;

	return
		wantarray
		? ($code, @response)
		: $buff;

}



2703;


__END__

=head1 NAME

Device::Modem - Perl extension to talk to modem devices connected via serial port

=head1 WARNING

   This is B<BETA> software, still needs extensive testing and
   support for generic AT commands, so use it at your own risk,
   and without B<ANY> warranty! Have fun.

=head1 SYNOPSIS

  use Device::Modem;

  my $modem = new Device::Modem( port => '/dev/ttyS1' );

  if( $modem->connect( baudrate => 9600 ) ) {
      print "connected!\n";
  } else {
      print "sorry, no connection with serial port!\n";
  }

  $modem->attention();          # send `attention' sequence (+++)

  $modem->dial('02270469012');  # dial phone number
  $modem->dial(3);              # 1-digit parameter = dial number stored in memory 3

  $modem->echo(1);              # enable local echo (0 to disable)

  $modem->offhook();            # Take off hook (ready to dial)
  $modem->hangup();             # returns modem answer

  $modem->is_active();          # Tests whether modem device is active or not
                                # So far it works for modem OFF/ modem ON condition

  $modem->reset();              # hangup + attention + restore setting 0 (Z0)

  $modem->restore_factory_settings();  # Handle with care!
  $modem->restore_factory_settings(1); # Same with preset profile 1 (can be 0 or 1)

  $modem->send_init_string();   # Send initialization string
                                # Now this is fixed to 'AT H0 Z S7=45 S0=0 Q0 V1 E0 &C0 X4'

  # Get/Set value of S1 register
  my $S1 = $modem->S_register(1);
  my $S1 = $modem->S_register(1, 55); # Don't do that if you definitely don't know!

  # Get status of managed signals (CTS, DSR, RLSD, RING)
  my %signal = $modem->status();
  if( $signal{DSR} ) { print "Data Set Ready signal active!\n"; }

  # Stores this number in modem memory number 3
  $modem->store_number(3, '01005552817');

  $modem->repeat();             # Repeat last command

  $modem->verbose(1);           # Normal text responses (0=numeric codes)

  # Some raw AT commands
  $modem->atsend( 'ATH0' );
  print $modem->answer();

  $modem->atsend( 'ATDT01234567' . Device::Modem::CR );
  print $modem->answer();


=head1 DESCRIPTION

Device::Modem class implements basic AT (Hayes) compliant device abstraction. It is meant
to be inherited by sub classes (as Device::Gsm), which are based on serial connections.

In the `examples' directory, there are some scripts that should work without big problems,
that you can take as (yea) examples:

=over 4

=item `examples/active.pl'

Tests if modem is alive

=item `examples/dial.pl'

Dials a phone number and display result of call

=item `examples/shell.pl'

(Very) poor man's minicom/hyperterminal utility

=back


=head2 REQUIRES

=over 4

=item Device::SerialPort (Win32::SerialPort for Windows machines)

=back

=head2 EXPORT

None



=head1 TO-DO

=over 4

=item *

AutoScan

An AT command script with all interesting commands is run
when `autoscan' is invoked, creating a `profile' of the
current device, with list of supported commands, and database
of brand/model-specific commands

=item *

Many more to come!

=back



=head1 AUTHOR

Cosimo Streppone, L<cosimo@cpan.org|mailto:cosimo@cpan.org>

=head1 COPYRIGHT

(C) 2002 Cosimo Streppone, L<cosimo@cpan.org|mailto:cosimo@cpan.org>

This library is free software; you can only redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

Device::SerialPort,
Device::Gsm,
Win32::SerialPort,
perl

=cut
