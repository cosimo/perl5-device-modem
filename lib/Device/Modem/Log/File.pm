# Device::Modem::Log::File - Text files logging plugin for Device::Modem class
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
# $Id: File.pm,v 1.10 2003-05-18 14:57:48 cosimo Exp $
#
package Device::Modem::Log::File;
$VERSION = substr q$Revision: 1.10 $, 10;

use strict;
use File::Path     ();
use File::Basename ();

sub new {
	my( $class, $package, $filename ) = @_;

	# Get a decent default if no file available
	$filename ||= default_filename();

	my %obj = (
		file => $filename,
		loglevel => 'info'
	);

	my $self = bless \%obj, 'Device::Modem::Log::File';
	
	# Open file at the start and save reference	
	if( open( LOGFILE, '>>'.$self->{'file'} ) ) {

		$self->{'fh'} = \*LOGFILE;

		# Unbuffer writes to logfile
		my $oldfh = select $self->{'fh'};
		$| = 1;
		select $oldfh;

	} else {
		warn('Could not open '.$self->{'file'}.' to start logging');
	}

	return $self;
}

# provide a suitable filename default
sub default_filename() {
	my $cDir = '/var/log';

	# If this is windoze (XXX 2000/XP? WINBOOTDIR?)
	if( $^O =~ /Win/i ) {
		$cDir = $ENV{'WINBOOTDIR'} || '/windows';
		$cDir .= '/temp';
	}

	return $cDir.'/modem.log';
}

sub filename {
	my $self = shift();
	$self->{'file'} ||= $self->default_filename();

	if( ! -d File::Basename::dirname($self->{'file'}) ) {
		File::Path::mkpath( File::Basename::dirname($self->{'file'}), 0, 0755 );
	}

	return $self->{'file'};
}


{
	# Define log levels like syslog service
	my %levels = ( debug => 1, verbose => 10, info => 20, 'warn' => 30, error => 40, crit => 50 );

sub loglevel {
	my($self, $newlevel) = @_;

	if( defined $newlevel ) {
		if( ! exists $levels{$newlevel} ) {
			$newlevel = 'warn';
		}
		$self->{'loglevel'} = $newlevel;
	} else {
		return $self->{'loglevel'};
	}
}

sub write($$) {

	my($self, $level, @msg) = @_;

	# If log level mask allows it, log given message
	if( $levels{$level} >= $levels{$self->{'loglevel'}} ) {

		if( my $fh = $self->fh() ) {
			map { tr/\r\n/^M/s } @msg;
			print $fh join("\t", scalar localtime, $0, $level, @msg), "\n";
		} else {
			warn('cannot log '.$level.' '.join("\t",@msg).' to file: '.$! );
		}

	}

}

}

sub fh {
	my $self = shift;
	return $self->{'fh'};
}

# Closes log file opened in new() 
sub close {
	my $self = shift;
	my $fh = $self->{'FH'};
	close $fh;
	undef $self->{'FH'};
}

1;



__END__



=head1 NAME

Device::Modem::Log::File - Text files logging plugin for Device::Modem class

=head1 SYNOPSIS

  use Device::Modem;

  my $box = Device::Modem->new( log => 'file', ... );
  my $box = Device::Modem->new( log => 'file,name=/var/log/mymodem.log', ... );
  ...

=head1 DESCRIPTION

This is meant for an example log class to be hooked to C<Device::Modem>
to provide one's favourite logging mechanism.
You just have to implement your own C<new()>, C<write()> and C<close()> methods.

Default text file is C</var/log/modem.log>. On Windows platforms, this
goes into C<%WINBOOTDIR%/temp/modem.log>. By default, if the folder of the
log file does not exist, it is created.

This class is loaded automatically by C<Device::Modem> class when an object
is instantiated, and it is the B<default> logging mechanism for
C<Device::Modem> class.

Normally, you should B<not> need to use this class directly, because there
are many other zillions of modules that do logging better than this.

Also, it should be pondered whether to replace C<Device::Modem::Log::File>
and mates with those better classes in a somewhat distant future.

=head2 REQUIRES

Device::Modem

=head2 EXPORTS

None

=head1 AUTHOR

Cosimo Streppone, cosimo@cpan.org

=head1 COPYRIGHT

(C) 2002 Cosimo Streppone, <cosimo@cpan.org>

This library is free software; you can only redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Device::Modem>
L<Device::Modem::Log::Syslog>

=cut
