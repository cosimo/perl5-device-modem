# Device::Modem
#
# Author: Cosimo Streppone <cosimo@cpan.org>
# Date  : 2000/10/13 (ported to CPAN in 2002)
#
# $Id: Modem.pm,v 1.2 2002-03-21 06:51:51 cosimo Exp $

package Device::Modem;
$VERSION = substr q$Revision: 1.2 $, 10; 

use strict;
use Device::SerialPort;


# Constants definition
use constant CTRL_Z => chr(26);

# TODO
# Allow to redefine CR to "\r", "\n" or "\r\n"
use constant CR => "\r";

# Connection defaults
$Device::Modem::DEFAULT_PORT = ( $^O =~ /win32/i ) ? 'COM1' : '/dev/modem';
$Device::Modem::BAUDRATE = 9600;
$Device::Modem::DATABITS = 8;
$Device::Modem::STOPBITS = 1;
$Device::Modem::PARITY   = 'none';
$Device::Modem::TIMEOUT  = 500;     # milliseconds;

#/**
# * @method       new
# *
# * AT compliant object constructor (prepare only object)
# * via serial port
# *
# * @param        reference to hash of options, that must contain:
# *     SERIAL    Which serial port the at is connected to (default = $DEFAULT_PORT)
# *     
# *     
# * @return       reference to new at object
# */
sub new {
	my($proto,%aOpt) = @_;                  # Get reference to object
	                                        # Options of object
	my $class = ref($proto) || $proto;      # Get reference to class

	$aOpt{'serial'} ||= $Device::Modem::DEFAULT_PORT;

	# Instance log object
	$aOpt{'log'} ||= 'file';
	my($method, $options) = split ',', delete $aOpt{'log'};
	my $logclass = 'Device/Modem/Log/'.ucfirst(lc $method).'.pm';
	my $package = 'Device::Modem::Log::'.ucfirst lc $method;
	eval { require $logclass; };
	unless($@) {
		$aOpt{'_log'} = $package->new( split ',', $options );
	}

	bless \%aOpt, $class;                   # Instance $class object
}

sub attention {
	my $self = shift;

	# Send attention sequence
	$self->atsend('+++');

	# Wait 1000 milliseconds
	$self->wait(1000);

	$self->answer();
}

sub echo {
	my($self, $lEnable) = @_;

	$self->log->write( 'info', ( $lEnable ? 'enabling' : 'disabling' ) . ' echo' );
	$self->atsend( ($lEnable ? 'ATE1' : 'ATE0') . CR );

	$self->answer();
}

sub hangup {
	my $self = shift;

	$self->log->write('info', 'hanging up...');
	$self->attention();
	$self->atsend( 'ATH0' . CR );

	$self->flag('OFFHOOK', 0);

	$self->answer();
}

sub offhook {
	my $self = shift;

	$self->log->write('info', 'tooking off hook');
	$self->atsend( 'ATH1' . CR );

	$self->flag('OFFHOOK', 1);

	return 1;
}

sub reset {
	my $self = shift;

	$self->log->write('warning', 'resetting modem on '.$self->{'serial'} );

	$self->hangup();

	$self->send_init_string();

	$self->reset_flags();

	return $self->answer();
}

sub wait {
	my( $self, $msec ) = @_;

	# TODO
	# Check if Time::HiRes module is loaded and available	
	#

	$self->log->write('info', 'waiting for '.$msec.' msecs');

	sleep( int($msec / 1000) );
	return 1;

}

# Set a named flag
# flags are now: OFFHOOK
sub flag {
	my($self, $cFlag) = @_;
	$cFlag = uc $cFlag;
	$self->{'_flags'}->{$cFlag} = shift() if @_;
	$self->{'_flags'}->{$cFlag};
}

sub reset_flags {
	my $self = shift();
	map { $self->flag($_, 0) } 'OFFHOOK';
}

sub send_init_string {
	my($self, $cInit) = @_;

	$self->attention();
	
	$self->atsend( 'ATZH0V1Q0E0' . CR );

	$self->answer();
}

sub log {
	shift()->{'_log'}
}

#/**
# * @method       connect
# *
# * Connect on serial port to at device
# * via serial port
# *
# * @param        reference to hash of options, that must contain:
# *     BAUDRATE  speed of communication (default 9600)
# *     DATABITS  byte length (default 8)
# *     STOPBITS  stop bits (default 1)
# *     PARITY    ... (default 'none')
# *
# * @return       success of connection
# */
sub connect {
	my ($me,%aOpt) = @_;

	my $lOk = 0;

	# Set default values if missing
	$aOpt{'baudrate'} ||= $Device::Modem::BAUDRATE;
	$aOpt{'databits'} ||= $Device::Modem::DATABITS;
	$aOpt{'parity'}   ||= $Device::Modem::PARITY;
	$aOpt{'stopbits'} ||= $Device::Modem::STOPBITS;

	# Store communication options in object
	$me->{'_comm_options'} = \%aOpt;
	
	# Connect on serial
	$me->port( new Device::SerialPort($me->{'serial'}) );

	# Check connection
	if( ref( $me->port ) ne 'Device::SerialPort' ) {
		$me->log->write( 'error', '*FAILED* connect on '.$me->{'serial'} );
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

	$me-> log -> write('info', 'Ok connected' );
	$me->{'CONNECTED'} = 1;

}


#/*
# * @method      options
# *
# * returns Device::SerialPort reference to hash options
# *
# * @return      hashref of options
# */
sub options {
	my $self = shift();
	@_ ? $self->{'_comm_options'} = shift()
	   : $self->{'_comm_options'};
}

#/*
# * @method      port
# *
# * returns Device::SerialPort object handle
# *
# * @return      Device::SerialPort object handle
# * @see         Device::SerialPort
# */
sub port {
	my $self = shift();
	@_ ? $self->{'_comm_object'} = shift()
	   : $self->{'_comm_object'};
}

#/**
# * @method       disconnect
# *
# * Disconnect serial port
# */
sub disconnect {
	my $me = shift;
	$me->port->close();
	$me->log->write('info', 'Disconnected from '.$me->{'serial'} );
}

#/**
# * @method       atsend
# *
# * Send AT command to device on serial port
# *
# * @param	msg
# *   message to send (for now must include CR)
# *
# */
sub atsend {
	my( $me, $msg ) = @_;
	my $cnt = 0;

	# Write message on port
	$me->port->purge_all();
	$cnt = $me->port->write($msg);
	$me->port->write_drain();

	$me->log->write('info', 'atsend: wrote '.$cnt.'/'.length($msg).' chars');

	# If wrote all chars of `msg', we are successful
	return $cnt == length $msg;
}

#/**
# * @method        answer
# *
# * Take strings from the device until a pattern
# * is encountered or a timeout happens.
# *
# */
sub answer {
	my $me = shift;
	my $buff;
	my $msec = 100; 

	my($howmany, $what) = $me->port->read($msec);
	$buff = $what;

	$me->log->write('info', 'answer: read ['.$buff.']' );

	# Flush receive and trasmit buffers
	$me->port->purge_all;

	# Trim result of beginning and ending CR+LF (XXX)
	$buff =~ s/^[\r\n]+//;
	$buff =~ s/[\r\n]+$//;

	$buff;
}

2703;


__END__

=head1 NAME

Device::Modem - Perl extension to talk to AT devices via serial ports

=head1 SYNOPSIS

  use Device::Modem;

  my $modem = new Device::Modem( port => '/dev/ttyS1', baud => 9600 )

  if( $modem->connect() ) {
      print "connected!\n";
  } else {
      print "sorry, no connection with serial port!\n';
  }

  $modem->attention();          # send `attention' sequence (+++)

  $modem->echo(1);              # enable local echo
  $modem->echo(0);              # disable it

  $modem->hangup();             # returns modem answer

  $modem->offhook();            # Take off hook (ready to dial)

  $modem->reset();              # hangup + attention + restore setting 0 (Z0)

  $modem->send_init_string();   # Send initialization string
                                # Now this is fixed to `ATZ0H0V1Q0E0'
  #
  # Some raw at commands
  #
  $modem->atsend( 'ATH0' );
  print $modem->answer();

  $modem->atsend( 'ATDT01234567' . Device::Modem::CR );
  print $modem->answer();

=head1 DESCRIPTION

Device::Modem class implements basic AT device abstraction. It is meant
to be inherited by sub classes (as Device::Gsm), which are
based on serial connections.

=head2 REQUIRES

=over 4

=item Device::SerialPort

=back

=head2 EXPORT

None

=head1 AUTHOR

Cosimo Streppone, cosimo@cpan.org

=head1 SEE ALSO

Device::SerialPort(3), perl(1).

=cut
