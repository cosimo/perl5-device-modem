# $Id: File.pm,v 1.1.1.1 2002-03-20 21:13:49 cosimo Exp $
package Device::Modem::Log::File;

$VERSION = '0.01';

use strict;
use warnings;

sub new {
	my( $class, $filename ) = @_;
	$filename ||= '/var/log/modem.log';

	my %obj = (
		file => $filename,
		loglevel => 'info'
	);

	bless \%obj, 'Device::Modem::Log::File';
}

sub write($$) {
	my($self, $level, @msg) = @_;
	if( open(LOGFILE, '>>'.$self->{'file'}) ) {
		map { tr/\r\n/^M/s } @msg;
		print LOGFILE join("\t", scalar localtime, $0, $level, @msg), "\n";
		close LOGFILE;
	} else {
		warn('cannot log '.$level.' '.join("\t",@msg).' to file: '.$! );
	}

}

sub close { 1 }

1;

__END__

=head1 NAME

Device::Modem::Log::File - Device::Modem log hook class for logging devices activity to text files

=head1 SYNOPSIS

  use Device::Modem;

  my $box = Device::Modem->new( log => 'file', ... );
  my $box = Device::Modem->new( log => 'file,name=/var/log/mymodem.log', ... );
  ...

=head1 DESCRIPTION

This is meant for an example log class to be hooked to Device::Modem
to provide one's favourite logging mechanism.
You just have to implement your own `new()', `write()' and `close()' methods.

Default text file is `/var/log/modem.log'.

=head2 EXPORT

None by default.

=head1 AUTHOR

Cosimo Streppone, cosimo@cpan.org 

=head1 SEE ALSO

Device::Modem

=cut
