# $Id: Syslog.pm,v 1.1.1.1 2002-03-20 21:13:49 cosimo Exp $
package Device::At::Log::Syslog;

$VERSION = '0.01';

use strict;
use warnings;

use Sys::Syslog ();

sub new {
	Sys::Syslog::setlogsock('unix');
	Sys::Syslog::openlog('Device::At', 'cons,pid', 'user');
	my $loglevel = 'info';
	bless \$loglevel, 'Device::At::Log::Syslog';
}

sub write($$) {
	my($self, $level, @msg) = @_;
	Sys::Syslog::syslog( $level, @msg );
}

sub close {
	my $self = shift();
	Sys::Syslog::closelog();
}



# Preloaded methods go here.

1;

__END__

=head1 NAME

Device::At::Log::Syslog - Device::At log hook class for logging devices activity to syslog 

=head1 SYNOPSIS

  use Device::At;

  my $at_box = Device::At->new( log => 'syslog', ... );
  ...

=head1 DESCRIPTION

This is meant for an example log class to be hooked to Device::At
to provide one's favourite logging mechanism.
You just have to implement your own `write()' method.

=head2 EXPORT

None by default.

=head1 AUTHOR

Cosimo Streppone, cosimo@streppone.it 

=head1 SEE ALSO

Device::At

=cut
