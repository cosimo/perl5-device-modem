# Device::Modem::Log::Syslog - Syslog logging plugin for Device::Modem class
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
# $Id: Syslog.pm,v 1.6 2002-12-03 21:27:52 cosimo Exp $

package Device::Modem::Log::Syslog;
$VERSION = substr q$Revision: 1.6 $, 10;

use strict;
use Sys::Syslog ();

sub new {
	my($class, $package) = @_;
	Sys::Syslog::setlogsock('unix');
	Sys::Syslog::openlog($package, 'cons,pid', 'user');
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


1;

__END__

=head1 NAME

Device::Modem::Log::Syslog - Syslog logging plugin for Device::Modem class

=head1 SYNOPSIS

  use Device::Modem;

  my $box = new Device::Modem( log => 'syslog', ... );
  ...

=head1 DESCRIPTION

Example log class for B<Device::Modem> that logs all
modem activity, commands, ... to B<syslog>

It is loaded automatically at B<Device::Modem> startup,
only if you specify C<syslog> value to C<log> parameter.

If you don't have B<Sys::Syslog> additional module installed,
you will not be able to use this logging plugin, and you should
better leave the default logging (to text file).

=head2 REQUIRES

C<Sys::Syslog>

=head2 EXPORTS

None

=head1 AUTHOR

Cosimo Streppone, cosimo@cpan.org

=head1 COPYRIGHT

(C) 2002 Cosimo Streppone, cosimo@cpan.org

This library is free software; you can only redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

C<Device::Modem>
C<Device::Modem::Log::File>

=cut
