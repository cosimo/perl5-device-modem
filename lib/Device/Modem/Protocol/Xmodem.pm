# Device::Modem::Protocol::Xmodem - Xmodem file transfer protocol for Device::Modem class 
#
# Initial revision: 1 Oct 2003
#
# Copyright (C) 2003 Cosimo Streppone, cosimo@cpan.org
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
# $Id: Xmodem.pm,v 1.3 2003-10-15 23:48:01 cosimo Exp $

package Xmodem::Constants;

# Define constants used in xmodem blocks
sub soh        () { 0x01 }
sub stx        () { 0x02 }
sub eot        () { 0x04 }
sub ack        () { 0x06 }
sub nak        () { 0x15 }
sub can        () { 0x18 }
sub C          () { 0x43 }
sub ctrl_z     () { 0x1A }

sub CHECKSUM   () { 1 }
sub CRC16      () { 2 }
sub CRC32      () { 3 }

sub XMODEM     () { 0x01 }
sub XMODEM_1K  () { 0x02 }
sub XMODEM_CRC () { 0x03 }
#sub YMODEM     () { 0x04 }
#sub ZMODEM     () { 0x05 }

package Xmodem::Block;

use overload q[""] => \&to_string;

# Create a new block object
sub new {
	my($proto, $num, $data, $length) = @_;
	my $class = ref $proto || $proto;

	# Define block type (128 or 1k chars) if not specified
	$length ||= ( length $data > 128 ? 1024 : 128 );

	# Define structure of a Xmodem transfer block object
	my $self = {
		number  => defined $num ? $num : 1,
		type    => $type,
		'length'=> $length,
		data    => substr($data, 0, $length),      # Blocks are limited to 128 or 1024 chars
		'last'  => 0,
	};

	# Check if this is the last block
	$self->{'last'} = 1 if substr($data, 0, 1) eq chr(Xmodem::Constants::eot);

	bless $self, $class;
}

sub is_last {
	my $self = $_[0];
	return $self->{'last'} == 1;
}

# Calculate checksum of current block data
sub checksum {
	my $self = $_[0];
	my $sum  = 0;
	foreach my $c ( $self->data() ) {
		$sum += ord $c;
		$sum %= 256;
	}
	return $sum % 256;
}

# Calculate CRC 16 bit on block data
sub crc16 {
	my $self = $_[0];
	return unpack('%C16*' => $self->data()) % 65536;
}

# Calculate CRC 32 bit on block data
sub crc32 {
	my $self = $_[0];
	return unpack('%C32' => $self->data());
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

		$self->checksum()              # Final checksum (or crc16 or crc32)
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

	# TODO use new constants

	$type = 'checksum' unless defined $type;

	if( $type eq 'checksum' ) {
		$good_value = $self->checksum();
	} elsif( $type eq 'crc16' ) {
		$good_value = $self->crc16();
	} elsif( $type eq 'crc32' ) {
		$good_value = $self->crc32();
	} else {
		$good_value = $self->checksum();
	}

	return $good_value == $value;
}

# ----------------------------------------------------------------

package Xmodem::Buffer;

sub new {
	my($proto, $num, $data) = @_;
	my $class = ref $proto || $proto;

	# Define structure of a Xmodem transfer buffer
	my $self = [];

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

# ----------------------------------------------------------------

package Xmodem::Receiver;

# Define default timeouts for CRC handshaking stage and checksum normal procedure
sub TIMEOUT_CRC      () {  3 };
sub TIMEOUT_CHECKSUM () { 10 };

our $TIMEOUT = TIMEOUT_CRC;
our $DEBUG   = 1;

sub abort_transfer {
	my $self = $_[0];
	# Send a cancel char to abort transfer
	_log('aborting transfer');
	$self->modem->atsend( chr(Xmodem::Constants::can) );
	$self->modem->port->write_drain() unless $self->modem->ostype() eq 'windoze';
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
	_log('opt{modem} = ', $opt{modem});
	if( ! exists $opt{modem} ) {
		require Device::Modem;
		$opt{modem} = Device::Modem->new();
	}

	my $self = {
		_modem    => $opt{modem},
		_filename => $opt{filename} || 'received.dat',
		current_block => 0,
		timeouts  => 0,
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
sub receive_block {
	my $self = $_[0];

	# Block correct receive flag
	my $ok = 0;

	# Receive answer
	my $received = $self->modem->answer( undef, TIMEOUT_CHECKSUM );

	_log('received [', unpack('H*',$received), '] data');

	# Check if we are in a block
	if( substr($received, 0, 1) ne chr(Xmodem::Constants::soh) ) {
		# No valid block
		return 0;
	}
	
	#
	# Check block header
	#

	# Check block number and its 2's complement
	my($n_block,$n_block_inv) = ( ord(substr($received,1,1)), ord(substr($received,2,1)) );

	_log('checking block number');

	if( (255 - $n_block) != $n_block_inv ) {
		# Error receiving block numbers, send a new timeout
		$self->send_timeout();
		return 0;
	}

	# Ok, block seems correct, check sequence
	if( $n_block < $self->{current_block} || $n_block > ($self->{current_block} + 1) ) {
		# Sorry, out of sequence! Block {current} missed
		$self->abort_transfer();
	}

	_log('creating a new block object (n.', $n_block, ')');

	# Instance a new "block" object
	my $new_block = Xmodem::Block->new( $n_block, substr($received,3,128) );

	# Update current block to the one received
	$self->{current_block} = $new_block;

	if( defined $new_block && $new_block->verify( 'checksum', substr($received, 131, 1)) ) {
		# Ok, block received correctly
		_log('block ', $n_block, ' received correctly');
		$ok = 1;
	} else {
		$ok = 0;
	}
	
	return $ok;	

}

sub run {
	my $self  = $_[0];
	my $modem = $self->{_modem};
	my $file  = $_[1] || $self->{_filename};
	my $protocol = $_[2] || Xmodem::Constants::XMODEM;

	_log('checking modem[', $modem, '] or file[', $file, '] members');
	return 0 unless $modem and $file;

	# Initialize transfer
	$self->{current_block} = 0;
	$self->{timeouts}      = 0;

	# Initialize a receiving buffer
	_log('creating new receive buffer');

	my $buffer = Xmodem::Buffer->new();

	# Stage 1: handshaking for xmodem standard version 
	_log('sending first timeout');
	$self->send_timeout();

	my $received      = '';
	my $file_complete = 0;

	$self->{current_block} = 0;

	# Open output file
	return undef unless open OUTFILE, '>'.$file;

	# Main receive cycle (subsequent timeout cycles)
	do {

		# Try to receive a block
		if( my $new_block = $self->receive_block() ) {

			_log('received block ', $new_block->number());

			$buffer->push($new_block);

			# Write received block on disk if this is not the last
			#if( substr($new_block->data(), 0, 1) ne chr(Xmodem::Constants::eot) ) {
			if( ! $new_block->is_last() ) {
				_log('writing block ', $new_block->number(), ' to disk');
				print(OUTFILE $new_block->data()) and $self->send_ack();
			} else {
				_log('receive completed');
				$file_complete = 1;
				close OUTFILE;
			}

		} else {

			$self->send_timeout();

		}

	} until $file_complete or $self->timeouts() >= 10;

}

sub send_ack {
	my $self = $_[0];
	_log('sending ack');
	$self->modem->atsend( chr(Xmodem::Constants::ack) );
	$self->modem->port->write_drain() unless $self->modem->ostype() eq 'windoze';
	$self->{timeouts} = 0;
	return 1;
}

sub send_timeout {
	my $self = $_[0];
	_log('sending timeout (', $self->{timeouts}, ')');
	$self->modem->atsend( chr(Xmodem::Constants::nak) );
	$self->modem->port->write_drain() unless $self->modem->ostype() eq 'windoze';
	$self->{timeouts}++;
	return 1;
}

sub timeouts {
	my $self = $_[0];
	$self->{timeouts};
}

sub _log {
	print STDERR @_, "\n";
}

1;


=head1 Xmodem::Block

Class that represents a single Xmodem data block.

=head2 Synopsis

	my $b = Xmodem::Block->new( 1, 'My Data...<until-128-chars>...' );
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

=head1 Xmodem::Buffer

Class that implements an Xmodem receive buffer of data blocks. Every block of data
is represented by a C<Xmodem::Block> object.

Blocks can be B<push>ed and B<pop>ped from the buffer. You can retrieve the B<last>
block, or the list of B<blocks> from buffer.

=head2 Synopsis

	my $buf = Xmodem::Buffer->new();
	my $b1  = Xmodem::Block->new(1, 'Data...');

	$buf->push($b1);

	my $b2  = Xmodem::Block->new(2, 'More data...');
	$buf->push($b2);

	my $last_block = $buf->last();

	print 'now I have ', scalar($buf->blocks()), ' in the buffer';

	# TODO document replace() function ???

=head1 Xmodem::Constants

Package that contains all useful Xmodem protocol constants used in handshaking and
data blocks encoding procedures

=head2 Synopsis

	Xmodem::Constants::soh ........... 'start of header'
	Xmodem::Constants::eot ........... 'end of trasmission'
	Xmodem::Constants::ack ........... 'acknowlegded'
	Xmodem::Constants::nak ........... 'not acknowledged'
	Xmodem::Constants::can ........... 'cancel'
	Xmodem::Constants::C   ........... `C' ASCII char

	Xmodem::Constants::XMODEM ........ basic xmodem protocol
	Xmodem::Constants::XMODEM_1K ..... xmodem protocol with 1k blocks
	Xmodem::Constants::XMODEM_CRC .... xmodem protocol with CRC checks

	Xmodem::Constants::CHECKSUM ...... type of block checksum
	Xmodem::Constants::CRC16 ......... type of block crc16
	Xmodem::Constants::CRC32 ......... type of block crc32
	
=head1 Xmodem::Receiver

Control class to initiate and complete a C<X-modem> file transfer in receive mode

=head2 Synopsis

	my $recv = Xmodem::Receiver->new(
 		modem    => {Device::Modem object},
		filename => 'name of file',
		XXX protocol => 'xmodem' | 'xmodem-crc', | 'xmodem-1k'
	);

	$recv->run();

=head2 Object methods

=over 4

=item abort_transfer()

Sends a B<cancel> char (C<can>), that signals to sender that transfer is aborted. This is
issued if we receive a bad block number, which usually means we got a bad line.

=item modem()

Returns the underlying L<Device::Modem> object.

=item receive_block()

Tries to receive a new block from sender and to initialize a new C<Xmodem::Block> object.
This fails if received data is not correct (bad header, bad block numbers, ...)

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

=back


