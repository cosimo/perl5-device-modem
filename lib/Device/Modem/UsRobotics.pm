# Device::Modem::UsRobotics - control USR modems self mode
#
# Copyright (C) 2004 Cosimo Streppone, cosimo@cpan.org
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Additionally, this is ALPHA software, still needs extensive
# testing and support for generic AT commads, so use it at your own risk,
# and without ANY warranty! Have fun.
#
# $Id: UsRobotics.pm,v 1.3 2004-11-22 23:07:03 cosimo Exp $

package Device::Modem::UsRobotics;
$VERSION = sprintf '%d.%02d', q$Revision: 1.3 $ =~ /(\d)\.(\d+)/;

use strict;
use Device::Modem;
@Device::Modem::UsRobotics::ISA = 'Device::Modem';

sub mcc_get {

    my $self = $_[0];
    $self->atsend('AT+MCC?'.Device::Modem::CR);
    my @time;
    my($ok, @data) = $self->parse_answer();
    if( index($ok, 'OK') >= 0 )
    {
        @time = split ',', $data[0];
        $self->log->write('info', sprintf('MCC: %d days, %02d hrs, %02d mins, %02d secs after last clock reset', @time) );
        return wantarray ? @time : join(',',@time);
    }
    else
    {
        $self->log->write('warning', 'MCC: failed to get clock value');
        return undef;
    }

}

#
# Takes days,hrs,mins values and obtains a real time value
#
sub mcc_merge {
    my($self, $d, $h, $m) = @_;
    $_ += 0 for $d, $h, $m ;

    if( $d == $h && $h == $m && $m == 255 )
    {
        $self->log->write('warning', 'invalid time 255,255,255');
        return(time());
    }

    my $mcc_last = $self->mcc_last_saved();
    $mcc_last += 86400 * $d + 3600 * $h + 60 * $m;

    $self->log->write('info', "$d days, $h hours, $m mins is real time ".localtime($mcc_last));
    return($mcc_last);
}

sub mcc_last_saved {
    my $self = $_[0];
    my $dir = $self->_createSettingsDir();
    my $mcc_basetime = undef;

    if( ! -d $dir )
    {
        return undef;
    }
    elsif( open SETTINGS, "$dir/mcc_timer" )
    {
        chomp($mcc_basetime = <SETTINGS>);
    }

    $self->log->write('info', 'last mcc timer saved at '.localtime($mcc_basetime));
    return($mcc_basetime);
}

sub mcc_reset {
    my $self = $_[0];
    $self->atsend('AT+MCC'.Device::Modem::CR);
    my($ok, $ans) = $self->parse_answer();
    $self->log->write('info', 'internal timer reset to 00 days, 00 hrs, 00 mins');
    if( index($ok, 'OK') >= 0 )
    {
        # Create settings dir
        my $dir = $self->_createSettingsDir();
        if( -d $dir )
        {
            if( open SETTINGS, "> $dir/mcc_timer" )
            {
                print SETTINGS time(), "\n";
                $ok = close SETTINGS;
            }
        }
        else
        {
            $self->log->write('warning', 'Failed writing mcc timer settings in ['.$dir.']');
        }

    }
}

sub msg_status {
    my($self, $index) = @_;

    $self->atsend('AT+MSR=0'.Device::Modem::CR);
    my($ok, @data) = $self->parse_answer();
    if( index($ok,'OK') >= 0 ) {
        $self->log->write('info', 'MSR: '.join('/ ', @data));
        return wantarray ? @data : join("\n", @data);
    }
    else
    {
        $self->log->write('warning', 'MSR: Error in querying status');
        return undef;
    }
}

sub clear_memory
{
    my($self, $memtype) = @_;
    $memtype = 2 unless defined $memtype;
    my $cmd  = '';

    if( $memtype == 0 || $memtype eq 'all' )
    {
        $cmd = '+MEA';
    }
    elsif( $memtype == 1 || $memtype eq 'user' )
    {
        $cmd = '+MEU';
    }
    elsif( $memtype == 2 || $memtype eq 'messages' )
    {
        $cmd = '+MEM';
    }

    $cmd = 'AT+' . $cmd . Device::Modem::CR;
    $self->atsend($cmd);
    $self->wait(500);
    $self->log->write('info', 'cleared memory type '.$memtype);
    return(1);
}

sub fax_id_string
{
    my $self   = shift;
    my $result = '';

    if( @_ )
    {
        $self->atsend( sprintf('AT+MFI="%s"',$_[0]) . Device::Modem::CR );
        $self->wait(250);
        my($ok, $ans) = $self->parse_answer(); 
        $self->log->write('info', 'New Fax ID string set to ['.$_[0].']');
        $result = $ok;
    }
    else
    {
        # Retrieve current fax id string
        $self->atsend('AT+MFI?' . Device::Modem::CR);
        $self->wait(250);
        my($ok, $ans) = $self->parse_answer();
        $self->log->write('info', 'Fax ID string is ['.$ans.']');
        # Remove double quotes chars if present
        $ans = substr($ans, 1, -1) if $ans =~ /^".*"$/;
        $result = $ans;
    }

    $self->log->write('debug', 'fax_id_string answer is ['.$result.']');
    return($result);
}

sub _createSettingsDir {
    my $self = $_[0];
    my $ok = 1;
    require File::Path;
    my $dir = $self->_settingsDir();
    if( ! -d $dir )
    {
        $ok = File::Path::mkpath( $dir, 0, 0700 );
    }
    return($ok ? $dir : undef);
}

sub _settingsDir {
    "$ENV{HOME}/.usrmodem"
}

1;

=head1 NAME

Device::Modem::UsRobotics - USR modems extensions to control self-mode

=head1 SYNOPSIS

  use Device::Modem::UsRobotics;

  my $modem = new Device::Modem::UsRobotics( port => '/dev/ttyS1' );

  if( $modem->connect( baudrate => 9600 ) ) {
      print "connected!\n";
  } else {
      print "sorry, no connection with serial port!\n";
  }

=head1 TO BE COMPLETED FROM NOW.....

=head1 DESCRIPTION

C<Device::Modem> class implements basic B<AT (Hayes) compliant> device abstraction.
It can be inherited by sub classes (as C<Device::Gsm>), which are based on serial connections.

=head1 METHODS

=head2 clear_memory()

Used to permanently clear the memory space of the modem. There are separate memory
spaces, one for voice/fax messages and one for user settings. Examples:

	$modem->clear_memory('user');     # or $modem->clear_memory(1)
    $modem->clear_memory('messages'); # or $modem->clear_memory(2)

To clear both, you can use:

    $modem->clear_memory('all');      # or $modem->clear_memory(0);

Parameters:

=over 4

=item C<$memtype>

String or integer that selects the type of memory to be cleared,
where C<0> is for C<all>, C<1> is for C<user> memory, C<2> is for C<messages>
memory.

=back


=head1 FAQ

There is a minimal FAQ document for this module online at
L<http://www.streppone.it/cosimo/work/perl/CPAN/Device-Modem/FAQ.html>

=head1 SUPPORT

Please feel free to contact me at my e-mail address L<cosimo@cpan.org>
for any information, to resolve problems you can encounter with this module
or for any kind of commercial support you may need.

=head1 AUTHOR

Cosimo Streppone, L<cosimo@cpan.org>

=head1 COPYRIGHT

(C) 2002-2004 Cosimo Streppone, L<cosimo@cpan.org>

This library is free software; you can only redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

Device::SerialPort,
Win32::SerialPort,
Device::Gsm,
perl

=cut

# vim: set ts=4 sw=4 tw=120 nowrap nu
