# $Id: Xmodem.pm,v 1.1 2003-10-01 22:34:08 cosimo Exp $
#
# Xmodem file transfer protocol perl implementation
# Cosimo Streppone  01/10/2003
#

package Xmodem::Constants;

# Define constants used in xmodem blocks
sub soh () { 0x01 }
sub eot () { 0x04 }
sub ack () { 0x06 }
sub nak () { 0x15 }
sub can () { 0x18 }
sub C   () { 0x43 }


package Xmodem::Block;

use overload q[""] => \&to_string;

# Create a new block object
sub new {
	my($proto, $num, $data) = @_;
	my $class = ref $proto || $proto;

	# Define structure of a Xmodem transfer block object
	my $self = {
		number => defined $num ? $num : 1,
		data   => substr($data, 0, 128),      # Blocks are limited to 128 chars
	};

	bless $self, $class;
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
		? split(//, $self->{'data'})
		: substr($self->{'data'}, 0, 128)
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
		'cccA128c',
		Xmodem::Constants::soh,  # Start Of Header
		$block_num,              # Block number
		$block_num ^ 0xFF,       # 2's complement of block number
		scalar $self->data,      # 128 chars of data
		$self->checksum()        # Final checksum (or crc16 or crc32)
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

# ----------------------------------------------------------------

package Xmodem::Receiver;

# Define default timeouts for CRC handshaking stage and checksum normal procedure
sub TIMEOUT_CRC      () {  3 };
sub TIMEOUT_CHECKSUM () { 10 };

our $TIMEOUT = TIMEOUT_CRC;

#
# TODO protocol management
#
sub new {
	my $proto = $_[0];
	my %opt   = $_[1..$#$_];
	my $class = ref $proto || $proto;

	# Create `modem' object if does not exist
	if( ! exists $opt{modem} ) {
		require Device::Modem;
		$opt{modem} = Device::Modem->new();
	}

	my $self = {
		_modem    => $opt{modem},
		_filename => $opt{filename} || 'received.dat',
	};

	bless $self, $class;
}

sub run {
	my $self  = $_[0];
	my $modem = $self->{_modem};
	my $file  = $_[1] || $self->{_filename};

	return 0 unless $modem and $file;

	# Initialize a receiving buffer
	my $buffer = Xmodem::Buffer->new();

	# Stage 1: handshaking for xmodem/crc "advanced" feature

	# XXX PROBLEMA! non e' cosi' che va gestito!!!!
#	eval {
#		local $SIG{ALRM} = sub { die 'timeout' };
#		# XXX Start first timeout cycle, declaring we accept Xmodem/CRC16
#		# Start first timeout cycle, declaring we accept only original Xmodem
#		alarm $TIMEOUT;
#		$modem->atsend( Xmodem::Constants::C );
#		$modem->answer();
#	};
#	if( ! $@ ) {
#
#	}

	# Main receive cycle (subsequent timeout cycles)

	# Write blocks

}

sub firstTimeout {
		
}


1;



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


=head1 Xmodem::Receiver

Control class to initiate and complete a C<X-modem> file transfer in receive mode

=head2 Synopsis

	my $recv = Xmodem::Receiver->new(
 		modem    => {Device::Modem object},
		filename => 'name of file',
		XXX protocol => 'xmodem' | 'xmodem-crc', | 'xmodem-1k'
	);

=head2 See also

=over 4

=item *

Device::Modem

=back


=head2 run()

Start receiving a file

=head3 Parameters

=over 4

=item -

[optional] filename

=back

=head3 See also

=over 4

=item *

Device::Modem

=back


