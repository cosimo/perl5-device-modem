# $Id: Syslog.pm,v 1.2 2002-03-21 06:40:50 cosimo Exp $
#
# Device::Modem log class that logs modem activity
# on common system log
#
package Device::Modem::Log::Syslog;
$VERSION = substr q$Revision: 1.2 $, 10;

use strict;
use warnings;

use Sys::Syslog ();

sub new {
	Sys::Syslog::setlogsock('unix');
	Sys::Syslog::openlog('Device::Modem', 'cons,pid', 'user');
	my $loglevel = 'info';
	bless \$loglevel, 'Device::Modem::Log::Syslog';
}

sub write($$) {
	my($self, $level, @msg) = @_;
	Sys::Syslog::syslog( $level, @msg );
}

sub close {
	my $self = shift();
	Sys::Syslog::closelog();
}



2703;

__END__

=head1 NAME

Device::Modem::Log::Syslog - Device::Modem log hook class for logging devices activity to syslog 

=head1 SYNOPSIS

  use Device::Modem;

  my $box = new Device::Modem( log => 'syslog', ... );
  ...

=head1 DESCRIPTION

Example log class for B<Device::Modem> that logs all
modem activity, commands, ... to B<syslog>

It is loaded automatically at B<Device::Modem> startup,
only if you specify C<syslog> value to C<log> parameter.

=head2 REQUIRES

Sys::Syslog

=head2 EXPORT

None

=head1 AUTHOR

Cosimo Streppone, cosimo@cpan.org

=head1 SEE ALSO

Device::Modem
Device::Modem::Log::File

=cut
