# Device::Modem::Protocol::ModemUtility - (xyz)Modem Utility for file transfer protocol Device::Modem::Protocol::(XYZ)modem class
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
# This Zmodem protocol version is indeed very alpha code,
# probably does not work at all, so stay tuned...
# 

use Digest::CRC;

package ModemUtility::Misc;

our $DEBUG   = 1;

sub write_drain {
    my $modem = shift @_;

    # Windows dosn't have write_drain, it use write_done
    if (index($^O, 'Win') >= 0) {
        $modem->port->read_char_time(6);
        $modem->port->write_char_time(6);
        $modem->port->write_settings();
        $modem->port->write_done(1);
        $modem->wait(400);
    }
    else {
        $modem->port->write_drain();
    }
}

sub log {
    print STDERR @_, "\n" if $DEBUG
}

sub binToHex {
    return unpack("H*", $_[0]);
}

sub hexToBin {
    return hex($_[0]);
}

# Calculate checksum of current block data
sub checksum {
    my $data = $_[0];
    my $sum  = 0;
    foreach my $c ($data) {
        $sum += ord $c;
        $sum %= 256;
    }
    return $sum % 256;
}

# Calculate CRC 16 bit on block data
sub crc16 {
    my $crc = new Digest::CRC(type => "crc16");

    $crc->add($_[0]);
    return $crc->digest;
}

# Calculate CRC 32 bit on block data
sub crc32 {
    my $crc = new Digest::CRC(type => "crc32");

    $crc->add($_[0]);
    return pack("L*", $crc->digest);
}

package ModemUtility::Constants;

# Define constants used in xmodem blocks
sub nul        () { 0x00 } # ^@
sub soh        () { 0x01 } # ^A
sub stx        () { 0x02 } # ^B
sub eot        () { 0x04 } # ^D
sub ack        () { 0x06 } # ^E
sub nak        () { 0x15 } # ^U
sub can        () { 0x18 } # ^X
sub C          () { 0x43 }
sub ctrl_z     () { 0x1A } # ^Z
sub CR         () { 0x0d } # ^R
sub LF         () { 0x0a } # ^L

sub CHECKSUM   () { 1 }
sub CRC16      () { 2 }
sub CRC32      () { 4 }

package ModemUtility::Block;

use overload q[""] => \&to_string;

# Create a new block object
sub new {
    my($proto, $num, $data, $length) = @_;
    my $class = ref $proto || $proto;

    # Define block type (128 or 1k chars) if not specified
    $length ||= ( length $data > 128 ? 1024 : 128 );

    # Define structure of a Xmodem transfer block object
    my $self = {
        number  => defined $num ? $num : 0,
        'length'=> $length,
        data    => defined $data ? substr($data, 0, $length) : "",      # Blocks are limited to 128 or 1024 chars
      };

    bless $self, $class;
}



# Return data one char at a time
sub data {
    my $self = $_[0];
    return wantarray
      ? split(//, $self->{data})
      : substr($self->{data}, 0, $self->{'length'})
}

sub number {
    my $self = $_[0];
    return $self->{number};
}

# Calculate checksum/crc for the current block and stringify block for transfer
sub to_string {
    my $self = $_[0];
    my $block_num = $self->number();

    # Assemble block to be transferred
    my $xfer = pack(

        'cccA'.$self->{'length'}.'c',

        $self->{'length'} == 128
        ? Xmodem::Constants::soh   # Start Of Header (block size = 128)
        : Xmodem::Constants::stx,  # Start Of Text   (block size = 1024)

        $block_num,                    # Block number

        $block_num ^ 0xFF,             # 2's complement of block number

        scalar $self->data,            # Data chars

        Misc::checksum($self->data())  # Final checksum (or crc16 or crc32)
          # TODO crc16, crc32 ?
      );

    return $xfer;
}

#
# verify( type, value )
# ex.: verify( 'checksum', 0x7F )
# ex.: verify( 'crc16', 0x8328 )
#
sub verify {
    my($self, $type, $value) = @_;

    # Detect type of value to be checked

    $type = Constants::CHECKSUM unless defined $type;

    if( $type == Constants::CHECKSUM ) {
        $good_value = ModemUtility::Misc::checksum->($self->data());
    } elsif( $type == ModemUtility::Constants::CRC16 ) {
        $good_value = ModemUtility::Misc::crc16->($self->data());
    } elsif( $type == ModemUtility::Constants::CRC32 ) {
        $good_value = Modem::Utility::Misc::crc32->($self->data());
    } else {
        $good_value = ModemUtility::checksum($self->data());
    }

    return $good_value == $value;
}

# ----------------------------------------------------------------

package ModemUtility::Buffer;

sub new {
    my($proto, $num, $data) = @_;
    my $class = ref $proto || $proto;

    # Define structure of a Xmodem transfer buffer
    my $self = [];
    bless($self);
    return $self;
}

# Push, pop, operations on buffer
sub push {
    my $self  = $_[0];
    my $block = $_[1];
    push @$self, $block;
}

sub pop {
    my $self = $_[0];
    pop @$self
}

# Get last block on buffer (to retransmit / re-receive)
sub last {
    my $self = $_[0];
    return $self->[ $#$self ];
}

sub blocks {
    return @{$_[0]};
}

#
# Replace n-block with given block object
#
sub replace {
    my $self  = $_[0];
    my $num   = $_[1];
    my $block = $_[2];

    $self->[$num] = $block;
}

sub dump {
    my $self = $_[0];
    my $output;

    # Join all blocks into string
    for (my $pos = 0; $pos < scalar($self->blocks()); $pos++) {
        $output .= $self->[$pos]->data();
    }

    # Clean out any end of file markers (^Z) in data
    $output =~ s/\x1A*$//;

    return $output;
}

1;

=head1 NAME

Device::Modem::Protocol::ModemUtility

=head1 ModemUtility::Block

Class that represents a single data block for (X,Y,Z)Modem.

=head2 Synopsis

	my $b = ModemUtility::Block->new( 1, 'My Data...<until-128-chars>...' );
	if( defined $b ) {
		# Ok, block instanced, verify its checksum
		if( $b->verify( 'checksum', <my_chksum> ) ) {
			...
		} else {
			...
		}
	} else {
		# No block
	}

	# Calculate checksum, crc16, 32, ...
	$crc16 = $b->crc16();
	$crc32 = $b->crc32();
	$chksm = $b->checksum();

=head1 ModemUtility::Buffer

Class that implements an Xmodem receive buffer of data blocks. Every block of data
is represented by a C<ModemUtility::Block> object.

Blocks can be B<push>ed and B<pop>ped from the buffer. You can retrieve the B<last>
block, or the list of B<blocks> from buffer.

=head2 Synopsis

	my $buf = ModemUtility::Buffer->new();
	my $b1  = ModemUtility::Block->new(1, 'Data...');

	$buf->push($b1);

	my $b2  = ModemUtility::Block->new(2, 'More data...');
	$buf->push($b2);

	my $last_block = $buf->last();

	print 'now I have ', scalar($buf->blocks()), ' in the buffer';

	# TODO document replace() function ???

=head1 ModemUtility::Constants

Package that contains all useful Xmodem protocol constants used in handshaking and
data blocks encoding procedures

=head2 Synopsis

	ModemUtility::Constants::soh ........... 'start of header'
	ModemUtility::Constants::eot ........... 'end of trasmission'
	ModemUtility::Constants::ack ........... 'acknowlegded'
	ModemUtility::Constants::nak ........... 'not acknowledged'
	ModemUtility::Constants::can ........... 'cancel'
	ModemUtility::Constants::C   ........... `C' ASCII char

	ModemUtility::Constants::CHECKSUM ...... type of block checksum
	ModemUtility::Constants::CRC16 ......... type of block crc16
	ModemUtility::Constants::CRC32 ......... type of block crc32
	
=back

=head2 See also

=over 4

=item - L<Device::Modem>
=item - L<Device::Modem::Protocol::Xmodem>
=item - L<Device::Modem::Protocol::Zmodem>

=back
