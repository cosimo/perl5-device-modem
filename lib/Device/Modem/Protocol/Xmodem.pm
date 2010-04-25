# Device::Modem::Protocol::Xmodem - Xmodem file transfer protocol for Device::Modem class
#
# Initial revision: 1 Oct 2003
#
# Copyright (C) 2003-2005 Cosimo Streppone, cosimo@cpan.org
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Additionally, this is ALPHA software, still needs extensive
# testing and support for generic AT commads, so use it at your own risk,
# and without ANY warranty! Have fun.
#
# This Xmodem protocol version is indeed very alpha code,
# probably does not work at all, so stay tuned...
#
# $Id: Xmodem.pm 182 2008-10-29 21:39:16Z Cosimo $

use Device::Modem::Protocol::ModemUtility;

package Xmodem::Constants;

sub XMODEM     () { 0x01 }
sub XMODEM_1K  () { 0x02 }
sub XMODEM_CRC () { 0x03 }


# ----------------------------------------------------------------

package Xmodem::Receiver;

# Define default timeouts for CRC handshaking stage and checksum normal procedure
sub TIMEOUT_CRC      () {  3 };
sub TIMEOUT_CHECKSUM () { 10 };

our $TIMEOUT = TIMEOUT_CRC;

sub abort_transfer {
    my $self = $_[0];

    # Send a cancel char to abort transfer
    ModemUtility::Misc::log('aborting transfer');
    $self->modem->atsend( chr(ModemUtility::Constants::can) );
    ModemUtility::Misc::write_drain($self->modem) unless $self->modem->ostype() eq 'windoze';
    $self->{aborted} = 1;
    return 1;
}

#
# TODO protocol management
#
sub new {
    my $proto = shift;
    my %opt   = @_;
    my $class = ref $proto || $proto;

    # Create `modem' object if does not exist
    ModemUtility::Misc::log('opt{modem} = ', $opt{modem});
    if( ! exists $opt{modem} ) {
        require Device::Modem;
        $opt{modem} = Device::Modem->new();
    }

    my $self = {
        _modem    => $opt{modem},
        _filename => $opt{filename} || 'received.dat',
        current_block => 0,
        timeouts  => 0,
        protocol  => $opt{protocol} || Xmodem::Constants::XMODEM,
      };

    bless $self, $class;
}

# Get `modem' Device::SerialPort member
sub modem {
    $_[0]->{_modem};
}

#
# Try to receive a block. If receive is correct, push a new block on buffer
#
sub receive_message {
    my $self                = $_[0];
    my $message_type;
    my $message_number      = 0;
    my $message_complement  = 0;
    my $message_data;
    my $message_checksum;
    my $count_in            = 0;
    my $done                = 0;
    my $error               = 0;
    my $received            = undef;
    my $read_size           = 132;
    my $sum_size            = 1;

    # XMODEM_CRC use 133 bytes retrieve
    if ($self->{protocol} == Xmodem::Constants::XMODEM_CRC) {
        $read_size          = 133;
        $sum_size           = 2;
    }

    # Receive answer
    #my $received = $self->modem->answer( undef, 1000 );
    #my $received = $self->modem->answer( "/.{132}/", 1000 );
    # Had problems dropping bytes from block messages  that caused the checksum
    # to be missing on rare occasions.
    my $receive_start_time = time;

    do {
        my $count_in_tmp    = 0;
        my $received_tmp    = undef;

        ($count_in_tmp, $received_tmp) = $self->modem->port->read($read_size);
        $received           .= $received_tmp;
        $count_in           += $count_in_tmp;

        if (ord(substr($received, 0, 1)) != 1 and $count_in > 0) {
            $done = 1;
        }
        elsif ($count_in >= $read_size) {
            $done = 1;
        }
        elsif (time > $receive_start_time + 2) {
            $error = 1;
        }

    } while (!$done and !$error);


    ModemUtility::Misc::log('[receive_message][', $count_in, '] received [', unpack('H*',$received), '] data');

    # Get Message Type
    $message_type = ord(substr($received, 0, 1));

    # If this is a block extract data from message
    if( $message_type eq ModemUtility::Constants::soh ) {

        # Check block number and its 2's complement
        ($message_number, $message_complement) = ( ord(substr($received,1,1)), ord(substr($received,2,1)) );

        # Extract data string from message
        $message_data = substr($received,3,128);

        # Extract checksum from message
        $message_checksum = ord(substr($received, 131, $sum_size));
    }

    my %message = (
        type       => $message_type,        # Message Type
        number     => $message_number,      # Message Sequence Number
        complement => $message_complement,  # Message Number's Complement
        data       => $message_data,        # Message Data String
        checksum   => $message_checksum,    # Message Data Checksum
      );

    return %message;
}

sub run {
    my $self  = $_[0];
    my $modem = $self->{_modem};
    my $file  = $_[1] || $self->{_filename};

    # change used protocol
    if ($_[2] and $_[2] != $self->{protocol}) {
        $self->{protocol} = $_[2];
    }

    ModemUtility::Misc::log('[run] checking modem[', $modem, '] or file[', $file, '] members');
    return 0 unless $modem and $file;

    ModemUtility::Misc::log("[run] Protocol: ",  $self->{protocol});

    # Initialize transfer
    $self->{current_block} = 0;
    $self->{timeouts}      = 0;

    # Initialize a receiving buffer
    ModemUtility::Misc::log('[run] creating new receive buffer');

    my $buffer = ModemUtility::Buffer->new();

    # Stage 1: handshaking for xmodem standard version
    ModemUtility::Misc::log('[run] sending first timeout');
    if ($self->{protocol} != Xmodem::Constants::XMODEM_CRC) {
        $self->send_timeout();
    }
    else {
        $self->send_c();
    }

    my $file_complete = 0;

    $self->{current_block} = ModemUtility::Block->new(0);

    # Open output file
    return undef unless open OUTFILE, '>'.$file;

    # Main receive cycle (subsequent timeout cycles)
    do {

        # Try to receive a message
        my %message = $self->receive_message();

        if ( $message{type} eq ModemUtility::Constants::nul ) {

            # Nothing received yet, do nothing
            ModemUtility::Misc::log('[run] <NUL>', $message{type});
        } elsif ( $message{type} eq ModemUtility::Constants::eot ) {

            # If last block transmitted mark complete and close file
            ModemUtility::Misc::log('[run] <EOT>', $message{type});

            # Acknoledge we received <EOT>
            $self->send_ack();
            $file_complete = 1;

            # Write buffer data to file
            print(OUTFILE $buffer->dump());

            close OUTFILE;
        } elsif ( $message{type} eq ModemUtility::Constants::soh ) {

            # If message header, check integrity and build block
            ModemUtility::Misc::log('[run] <SOH>', $message{type});
            my $message_status = 1;

            # Check block number
            if ( (255 - $message{complement}) != $message{number} ) {
                ModemUtility::Misc::log('[run] bad block number: ', $message{number}, ' != (255 - ', $message{complement}, ')' );
                $message_status = 0;
            }

            # Check block numbers for out of sequence blocks
            if ( $message{number} < $self->{current_block}->number() || $message{number} > ($self->{current_block}->number() + 1) ) {
                ModemUtility::Misc::log('[run] bad block sequence');
                $self->abort_transfer();
            }

            # Instance a new "block" object from message data received
            my $new_block = ModemUtility::Block->new( $message{number}, $message{data} );

            # Set flag for checksum algo
            my $sum_flag = ModemUtility::Constants::CHECKSUM;
            if ($self->{protocol} == Xmodem::Constants::XMODEM_CRC) {
                $sum_flag = ModemUtility::Constants::CRC16;
            }

            # Check block against checksum
            if (!( defined $new_block && $new_block->verify($sum_flag, $message{checksum}) )) {
                ModemUtility::Misc::log('[run] bad block checksum');
                $message_status = 0;
            }

        # This message block was good, update current_block and push onto buffer
            if ($message_status) {
                ModemUtility::Misc::log('[run] received block ', $new_block->number());

                # Update current block to the one received
                $self->{current_block} = $new_block;

                # Push block onto buffer
                $buffer->push($self->{current_block});

                # Acknoledge we successfully received block
                $self->send_ack();

            } else {

                # Send nak since did not receive block successfully
                ModemUtility::Misc::log('[run] message_status = 0, sending <NAK>');
                $self->send_nak();
            }
        } else {
            ModemUtility::Misc::log('[run] neither types found, sending timingout');
            $self->send_timeout();
        }

      } until $file_complete or $self->timeouts() >= 10;
}

sub send_ack {
    my $self = $_[0];
    ModemUtility::Misc::log('sending ack');
    $self->modem->atsend( chr(ModemUtility::Constants::ack) );
    ModemUtility::Misc::write_drain($self->modem);
    $self->{timeouts} = 0;
    return 1;
}

sub send_c {
    my $self = $_[0];
    ModemUtility::Misc::log('sending C');
    $self->modem->atsend( chr(ModemUtility::Constants::C) );
    ModemUtility::Misc::write_drain($self->modem);
    $self->{timeouts} = 0;
    return 1;
}

sub send_nak {
    my $self = $_[0];
    ModemUtility::Misc::log('sending timeout (', $self->{timeouts}, ')');
    $self->modem->atsend( chr(ModemUtility::Constants::nak) );

    ModemUtility::Misc::write_drain($self->modem);
    $self->{timeouts}++;
    return 1;
}

sub send_timeout {
    my $self = $_[0];
    ModemUtility::Misc::log('sending timeout (', $self->{timeouts}, ')');
    $self->modem->atsend( chr(ModemUtility::Constants::nak) );
    ModemUtility::Misc::write_drain($self->modem);
    $self->{timeouts}++;
    return 1;
}

sub timeouts {
    my $self = $_[0];
    $self->{timeouts};
}

1;

=head1 NAME

Device::Modem::Protocol::Xmodem

=head1 Xmodem::Constants

Package that contains all useful Xmodem protocol constants used in handshaking and
data blocks encoding procedures

=head2 Synopsis

	Xmodem::Constants::XMODEM ........ basic xmodem protocol
	Xmodem::Constants::XMODEM_1K ..... xmodem protocol with 1k blocks
	Xmodem::Constants::XMODEM_CRC .... xmodem protocol with CRC checks

=head1 Xmodem::Receiver

Control class to initiate and complete a C<X-modem> file transfer in receive mode. XMODEM_1k dosn't support jet.

=head2 Synopsis

	my $recv = Xmodem::Receiver->new(
 		modem    => {Device::Modem object},
		filename => 'name of file',
		protocol => Xmodem::Constants::XMODEM | Xmodem::Constants::XMODEM_CRC 
	);

	$recv->run();

=head2 Object methods

=over 4

=item abort_transfer()

Sends a B<cancel> char (C<can>), that signals to sender that transfer is aborted. This is
issued if we receive a bad block number, which usually means we got a bad line.

=item modem()

Returns the underlying L<Device::Modem> object.

=item receive_message()

Retreives message from modem and if a block is detected it breaks it into appropriate
parts.

=item run()

Starts a new transfer until file receive is complete. The only parameter accepted
is the (optional) local filename to be written.

=item send_ack()

Sends an acknowledge (C<ack>) char, to signal that we received and stored a correct block
Resets count of timeouts and returns the C<Xmodem::Block> object of the data block
received.

=item send_timeout()

Sends a B<timeout> (C<nak>) char, to signal that we received a bad block header (either
a bad start char or a bad block number), or a bad data checksum. Increments count
of timeouts and at ten timeouts, aborts transfer.

=back

=head2 See also

=over 4

=item - L<Device::Modem>
=item - L<Device::Protocol::ModemUtility>
=item - L<Device::Protocol::Zmodem>

=back
