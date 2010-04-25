# Device::Modem::Protocol::Zmodem - Zmodem file transfer protocol for Device::Modem class

# Copyright (c) 2009-2010, Pascal Vizeli <pvizeli@yahoo.de>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, 
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice, 
#   this list of conditions and the following disclaimer in the documentation 
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.

# TODO:
#       - CRC Check by retrieve_message
#       - Multifile support
#       - Abort file tranfer
#
# Helps:
#       - http://pauillac.inria.fr/~doligez/zmodem/zmodem.txt
use bytes;

package Zmodem::Constants;

use strict;
no utf8;
use bytes;

sub ZPAD        () { 0x2a }
sub ZDLE        () { 0x18 }
sub ZDLEE       () { 0x58 }
sub ZBIN        () { 0x41 }
sub ZHEX        () { 0x42 }
sub ZBIN32      () { 0x43 }
sub ZBINR32     () { 0x44 }
sub ZRESC       () { 0x7E }
sub ZMAXHLEN    () { 16   }
sub ZMAXSPLEN   () { 1024 }
sub CANISTR     () { 24,24,24,24,24,24,24,24,8,8,8,8,8,8,8,8,8,8,0 }
sub XOFF        () { 0x13 }
sub XON         () { 0x11 }
sub ZEND        () { 0xff } # self defined

sub BLOCKSIZE   () { 1024 }

# Frame types
sub ZRQINIT     () { 0x00 }
sub ZRINIT      () { 0x01 }
sub ZSINIT      () { 0x02 }
sub ZACK        () { 0x03 }
sub ZFILE       () { 0x04 }
sub ZSKIP       () { 0x05 }
sub ZNAK        () { 0x06 }
sub ZABORT      () { 0x07 }
sub ZFIN        () { 0x08 }
sub ZRPOS       () { 0x09 }
sub ZDATA       () { 0x0a }
sub ZEOF        () { 0x0b }
sub ZFERR       () { 0x0c }
sub ZCRC        () { 0x0d }
sub ZCHALLENGE  () { 0x0e }
sub ZCOMPL      () { 0x0f }
sub ZCAN        () { 0x10 }
sub ZFREECNT    () { 0x11 }
sub ZCOMMAND    () { 0x12 }

# ZDLE Sequences
sub ZCRCE       () { 0x68 }
sub ZCRCG       () { 0x69 }
sub ZCRCQ       () { 0x6a }
sub ZCRCW       () { 0x6b }
sub ZRUB0       () { 0x6c }
sub ZRUB1       () { 0x6d }

# Bytes positions within header array
sub ZF0         () { 0x03 }
sub ZF1         () { 0x02 }
sub ZF2         () { 0x01 }
sub ZF3         () { 0x00 }
sub ZP0         () { 0x00 }
sub ZP1         () { 0x01 }
sub ZP2         () { 0x02 }
sub ZP3         () { 0x03 }

# ZRINIT Parameters for header
sub ZRPXWN      () { 0x08 }
sub ZRPXQQ      () { 0x09 }
# ZRINIT bit Masks ZF0
sub CANFDX      () { 0x01 }
sub CANOVIO     () { 0x02 }
sub CANBRK      () { 0x04 }
sub CANRLE      () { 0x08 }
sub CANLZW      () { 0x10 }
sub CANFC32     () { 0x20 }
sub ESCCTL      () { 0x40 }
sub ESC8        () { 0x80 }
# ZRINIT bit Masks ZF1
sub CANVHDR     () { 0x01 }
sub ZRRQWN      () { 0x08 }
sub ZRRQQQ      () { 0x10 }
sub ZRQNVH      () { &ZRRQWN | &ZRRQQQ }

# ZSINIT Parameters for header
sub ZATTNLEN    () { 0x20 }
sub ALTCOFF     () { &ZF1 }
# ZSINIT bit Masks ZF0
sub TESCCTL     () { 0x40 }
sub TESC8       () { 0x80}

# ZFILE Parameters for header
sub ZCBIN       () { 0x01 }
sub ZCNL        () { 0x02 }
sub ZCRESUM     () { 0x03 }
# ZFILE management options (one of these ored) ZF1
sub ZMSKNOLOC   () { 0x80 }
# ZFILE management options (one of these ored) ZF1
sub ZMMASK      () { 0x1f }
sub ZMNEWL      () { 0x01 }
sub ZMCRC       () { 0x02 }
sub ZMAPND      () { 0x03 }
sub ZMCLOB      () { 0x04 }
sub ZMNEW       () { 0x05 }
sub ZMDIFF      () { 0x06 }
sub ZMPROT      () { 0x07 }
sub ZMCHNG      () { 0x08 }
# ZFILE bit Masks (Transport options) ZF2
sub ZTLZW       () { 0x01 }
sub ZTRLE       () { 0x03 }
# ZFILE bit Masks (Exdended options) ZF3
sub ZXSPARS     () { 0x40 }
sub ZCANVHDR    () { 0x01 }
sub ZRWOUR      () { 0x04 }

# ZCOMMAND Parameters for header
## ZF0
sub ZCACK1      () { 0x01 }

# ----------------------------------------------------------------

package Zmodem::Misc;

use 5.010001;
use strict;
no utf8;
use bytes;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Zmodem ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.38';

require XSLoader;
XSLoader::load('Device::Modem::Protocol::Zmodem', $VERSION);

sub hexStr {
    my $str         = shift;
    my $ausgabe     = undef;

    # convert each character to hex value
    for (my $i = 0; $i < length($str); $i += 2) {
        $ausgabe    .= chr(hex(substr($str, $i, 2)));
    }

    return $ausgabe;
}

# ----------------------------------------------------------------

package Zmodem::Send;

use strict;
use File::stat;
use IO::File;
use Device::Modem::Protocol::ModemUtility;
no utf8;
use bytes;

#
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
   
    # set default modus 
    $opt{modus} = Zmodem::Constants::ZHEX if !exists $opt{modus};

    my $self = {
        _modem      => $opt{modem},
        _filename   => $opt{filename} || "test.dat",
        timeouts    => 0,
        modus       => $opt{modus} || Zmodem::Constants::ZHEX,
        zm_retrieve => $opt{zm_retrieve},
        sendname    => $opt{sendname},
      };

    # create Zmodem::Retrieve for retrieving message
    if (!exists $opt{zm_retrieve}) {
        $opt{zm_retrieve} = new Zmodem::Receiver(
                            modem   => $opt{modem}, 
                            modus   => $opt{modus},
                            zm_send => $self);
        $$self{zm_retrieve} = $opt{zm_retrieve};
    }

    bless $self, $class;
}

sub modem {
    return $_[0]->{_modem};
}

# escape special chars
sub send_esc {
    my $self            = shift;
    my $char            = shift;

    ModemUtility::Misc::log("[send_esc] run");

    $self->send_raw(chr(Zmodem::Constants::ZDLE));
    $self->send_raw($char ^ chr(0x40));
}

# send data with escape special chars
sub send {
    my $self            = shift;
    my $data            = shift;

    my $i               = 0;
    for ($i = 0; $i < length($data); ++$i) {

            my $char    = substr($data, $i, 1);

            if ($char eq chr(Zmodem::Constants::ZDLE)) {
               $self->send_esc($char); 
               next;
            }
            elsif ($char eq chr(0x10) or
                   $char eq chr(0x90) or
                   $char eq chr(0x11) or
                   $char eq chr(0x91) or
                   $char eq chr(0x13) or
                   $char eq chr(0x93)) {
                $self->send_esc($char);
                next;
           }

           # send org character
           $self->send_raw($char);
    }
}

# send characters without escape special chars
sub send_raw {
    my $self            = shift;
    my $data            = shift;
    
    my $count = $self->modem->port->write($data);
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
    # Never change this value, even if you think you know what    #
    # you're doing!                                               #
    # Without this value, the transfer is to fast for modems...   #
    ###############################################################
    $self->modem->wait(1);
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
    ###############################################################

    if ($count != length($data)) {
        ModemUtility::Misc::log("[send_raw] error, write only ", $count,
                                " from ", length($data));

    }
}

# send a 1k data block
sub send_dataBlock {
    my $self            = shift;
    my $data            = shift;
    my $type            = shift;
    my $count           = shift;
    my $crc             = undef;

    # create crc
    $crc = pack("L", Zmodem::Misc::crc32($data . $type, length($data) + 1));
    $crc = ~$crc;

    # send data block
    $self->send($data);
    $self->send_raw(chr(Zmodem::Constants::ZDLE) . $type);
    $self->send($crc);

    # isn't the last block
    if ($type eq chr(Zmodem::Constants::ZCRCG)) {
        ModemUtility::Misc::write_drain($self->modem);
    }


    ModemUtility::Misc::log("[send_dataBlock] Data: ", 
                            " crc:", unpack("H*", $crc),
                            " Type: ", unpack("H*", $type),
                            " lenght: ", length($data),
                            " count: ", $count);
}

sub send_data {
    my $self            = shift;
    my $data            = shift;
    my $end             = shift;
    my $offset          = 0;
    my $count           = 0;

    $end                = $end || chr(Zmodem::Constants::ZCRCW);
  
    do {

        # generate block
        my $pack        = substr($data, $offset, Zmodem::Constants::BLOCKSIZE);
        $offset         += length($pack);
        my $type        = chr(Zmodem::Constants::ZCRCG);

        # last block
        if (length($pack) < Zmodem::Constants::BLOCKSIZE) {
            $type       = $end;
        }

        # send
        $self->send_dataBlock($pack, $type, $count);
        ++$count;

        # wait for write if it isn't ZCRCW
        if ($type eq $end and $type ne chr(Zmodem::Constants::ZCRCW)) {
            ModemUtility::Misc::write_drain($self->modem);
        }

    } until $offset >= length($data);

    ModemUtility::Misc::log("[send_data] Gesamt: ", $offset); 

    # send XON if it is ZCRCW
    if (chr(Zmodem::Constants::ZCRCW) eq $end) {
            $self->send_raw(chr(Zmodem::Constants::XON));  
            ModemUtility::Misc::log("[send_data] XON"); 
    }
}

# send a message to host/client
sub send_message {
    my $self            = $_[0];
    my $message         = $_[1];
    my $send            = undef;
    my $leadSend        = undef;
    my $data            = undef;
    my $count           = 0;
    my $done            = 0;

    # set defautl values
    $$message{f3p0} = chr(0) if !exists $$message{f3p0};
    $$message{f2p1} = chr(0) if !exists $$message{f2p1};
    $$message{f1p2} = chr(0) if !exists $$message{f1p2};
    $$message{f0p3} = chr(0) if !exists $$message{f0p3};

    ModemUtility::Misc::log("[send_message] run");

    # Send this as head without prio for crc
    $leadSend   = chr(Zmodem::Constants::ZPAD) .
                    chr(Zmodem::Constants::ZDLE) .
                    $$message{enc};

    # Create message data / also for crc
    $send       .= $$message{type};
    $send       .= $$message{f3p0};
    $send       .= $$message{f2p1};
    $send       .= $$message{f1p2};
    $send       .= $$message{f0p3};

    # Calculate the CRC sume CRC16
    if ($$message{enc} eq chr(Zmodem::Constants::ZHEX) or 
            $$message{enc} eq chr(Zmodem::Constants::ZBIN)) {

        $$message{crc} = pack("S", 
                            Zmodem::Misc::crc16($send . chr(0) . chr(0), 7));
    }
    # Calculate the CRC sume CRC32
    elsif ($$message{enc} eq chr(Zmodem::Constants::ZBIN32)) {
        
        $$message{crc} = pack("L",
                            Zmodem::Misc::crc32($send, length($send))); 

        $$message{crc} = ~$$message{crc};
    }

    # create and send header
    if ($$message{enc} eq chr(Zmodem::Constants::ZHEX)) {

        # hex
        $self->send_raw(chr(Zmodem::Constants::ZPAD) . $leadSend);
        $self->send_raw(ModemUtility::Misc::binToHex($send));
        $self->send_raw(ModemUtility::Misc::binToHex($$message{crc}));
        $self->send_raw(chr(ModemUtility::Constants::CR) . 
                        chr(ModemUtility::Constants::LF) .
                        chr(Zmodem::Constants::XON));
    }
    elsif ($$message{enc} eq chr(Zmodem::Constants::ZBIN) or 
            $$message{enc} eq chr(Zmodem::Constants::ZBIN32)) {

        # bin
        $self->send_raw($leadSend);
        $self->send($send);
        $self->send($$message{crc});
    }
    else {
        ModemUtility::Misc::log("[send_message] Unkown Type");
        return -1;
    }
   
    ModemUtility::Misc::log("[send_message] Enc: ". $$message{enc},
                            " Type: ", unpack("H*", $$message{type}),
                            " f3p0: ", unpack("H*", $$message{f3p0}),
                            " f2p1: ", unpack("H*", $$message{f2p1}),
                            " f1p2: ", unpack("H*", $$message{f1p2}),
                            " f0p3: ", unpack("H*", $$message{f0p3}),
                            " crc: ", unpack("H*", $$message{crc}));

    # send data
    if ($$message{type} eq chr(Zmodem::Constants::ZFILE)) {

            $self->send_data($$message{data});
    }
    elsif ($$message{type} eq chr(Zmodem::Constants::ZDATA)) {
            # ZDATA is a non stop tranfer without ZCRCW end frame
            $self->send_data($$message{data}, chr(Zmodem::Constants::ZCRCE));
    }

    # wait until all data are send
    ModemUtility::Misc::write_drain($self->modem);
}

sub run {
    my $self    = shift;
    my $modem   = $self->{_modem};
    my $file    = $_[1] || $self->{_filename};
    my $done    = 0;
    my $end     = 0;
    my $error   = 0;
    my $saveFlg = undef;

    ModemUtility::Misc::log('[run] checking modem[', $modem, '] or file[', $file, '] members');
    return 0 unless $modem and $file;

    # Initialize transfer
    $self->{timeouts}      = 0;

    # generate data information and pointer
    my $data    = undef;
    my $sb      = stat($file);
    if (!$sb) {
        return 0;
    }
    my $size	= $sb->size();
    my $in      = new IO::File($file, "r");

    # read data
    $in->binmode(":raw");
    $in->read($data, $size);
    ModemUtility::Misc::log("[run] FileSize: ", $size, " DataSize: ", 
	    			length($data));

    # Stage 1: send ZRQINIT
    $self->modem->atsend("rz" . Device::Modem::CR);
    $self->send_zrqinit();

    # Main receive cycle (subsequent timeout cycles)
    do {

        # Try to receive a message
        my %message = $self->{zm_retrieve}->receive_message();

        # save flag for nak or return to old flag
        if ($message{type} eq chr(Zmodem::Constants::ZNAK)) {
            $message{type}  = $saveFlg;
        }
        else {
            $saveFlg        = $message{type};
        }

        # CRC Error
        if (!$message{crc} and !$message{type}) {

            ModemUtility::Misc::log("[run] <ZNAK>");

            # Resend data
            $self->send_znak();
        }
        elsif ($message{type} eq chr(Zmodem::Constants::ZRINIT)) {

            ModemUtility::Misc::log("[run] <ZRINIT>");

            # create name for transaction
            my $transName       = undef;
            if (!$self->{sendname}) {
                # extract file name
                if ($file =~ /\/(.*?)$/) {
                    $transName      = $1;
                }
                else {
                    $transName      = $file;
                }
            }
            else {
                $transName      = $self->{sendname};
            }

            if (!$end) {
                my $fprint      = $transName . chr(0) . 
                                    $sb->size() . " " .# size
                                    $sb->mtime() . " " . # modify date
                                    $sb->mode() . " " .  # mode
                                    "0 " .               # serial number
                                    "1 " .               # anz files
                                    $sb->size() .        # file type
                                    chr(0);
                 
                ModemUtility::Misc::log("[run] <ZRINIT> FileInfo: ", $fprint);
                $self->send_zfile($fprint);
            }
            else {
                $self->send_zfin();
            }
        }
        elsif ($message{type} eq chr(Zmodem::Constants::ZRPOS)) {

            ModemUtility::Misc::log("[run] <ZRPOS>");

            my $pos = Zmodem::Misc::stringToLong($message{f3p0} . 
                                        $message{f2p1} .  $message{f1p2} . 
                                        $message{f0p3});
           
            # send data 
            $self->send_zdata(substr($data, $pos), $size);   
            $self->send_zeof($size);
            $end = 1;
        } 
        elsif ($message{type} eq chr(Zmodem::Constants::ZFIN)) {
             
            ModemUtility::Misc::log("[run] <ZFIN>");
            ModemUtility::Misc::log("[run] ENDE");

            $self->send_zend();
            $done = 1;
        }
        elsif ($message{type} eq chr(Zmodem::Constants::ZSKIP)) {
            ModemUtility::Misc::log("[run] <ZSKIP>");
           
            $self->send_zfin();
            $error  = 1;
            $end    = 1;
        }
        elsif ($message{type} eq chr(Zmodem::Constants::ZACK)) {
            ModemUtility::Misc::log("[run] <ZACK> / Ups");

        }
        elsif ($message{type} == chr(Zmodem::Constants::ZRQINIT)) {
            ModemUtility::Misc::log("[run] <ZRQINIT>");

            $self->send_zrqinit();
        }
        else {
            ModemUtility::Misc::log('[run] neither types found, sending timingout');
            ++$self->{timeouts};
        }

    } until $done or $self->timeouts() >= 10;

    if ($error > 0 or $self->timeouts() >= 10) {
        return 0;
    }

    return 1;
}

sub timeouts {
    return $_[0]->{timeouts};
}

sub send_zrinit {
    my $self        = shift;

    ModemUtility::Misc::log("[send_zrinit] run");

    my %message     = (
        enc     => chr($self->{modus}),
        type    => chr(Zmodem::Constants::ZRINIT),
        f0p3    => chr(Zmodem::Constants::CANOVIO | Zmodem::Constants::CANFDX | Zmodem::Constants::CANFC32),
    );

    $self->send_message(\%message);
}

sub send_zrpos {
    my $self        = shift;
    my $filePos     = shift;

    ModemUtility::Misc::log("[send_zrpos] run");
    my $val         = Zmodem::Misc::longToString($filePos);

    my %message     = (
        enc     => chr($self->{modus}),
        type    => chr(Zmodem::Constants::ZRPOS),
        f3p0    => substr($val, 0, 1) || chr(0),
        f2p1    => substr($val, 1, 1) || chr(0),
        f1p2    => substr($val, 2, 1) || chr(0),
        f0p3    => substr($val, 3, 1) || chr(0),
    );

    $self->send_message(\%message);
}

sub send_znak {
    my $self        = shift;

    ModemUtility::Misc::log("[send_znak] run");

    my %message     = (
        enc     => chr($self->{modus}),
        type    => chr(Zmodem::Constants::ZNAK),
    );

    $self->send_message(\%message);
}

sub send_zeof {
    my $self        = shift;
    my $sizeFile    = shift;

    my $val         = Zmodem::Misc::longToString($sizeFile);

    ModemUtility::Misc::log("[send_zeof] run / size: ", $sizeFile,
                            " Dump: " . unpack("H*", $val));

    my %message     = (
        enc     => chr(Zmodem::Constants::ZBIN32),
        type    => chr(Zmodem::Constants::ZEOF),
        f3p0    => substr($val, 0, 1) || chr(0),
        f2p1    => substr($val, 1, 1) || chr(0),
        f1p2    => substr($val, 2, 1) || chr(0),
        f0p3    => substr($val, 3, 1) || chr(0),
    );

    $self->send_message(\%message);
}

sub send_zfin {
    my $self        = shift;

    ModemUtility::Misc::log("[send_zfin] run");

    my %message     = (
        enc     => chr($self->{modus}),
        type    => chr(Zmodem::Constants::ZFIN),
    );

    $self->send_message(\%message);
}

sub send_zrqinit {
    my $self        = shift;

    ModemUtility::Misc::log("[send_zrqinit] run");

    my %message     = (
        enc     => chr($self->{modus}),
        type    => chr(Zmodem::Constants::ZRQINIT),
    );

    $self->send_message(\%message);
}

sub send_zend {
    my $self        = shift;

    $self->modem->atsend("OO");
}

sub send_zfile {
    my $self        = shift;
    my $data        = shift;

    ModemUtility::Misc::log("[send_zfile] run");

    my %message     = (
        enc     => chr(Zmodem::Constants::ZBIN32),
        type    => chr(Zmodem::Constants::ZFILE),
        data    => $data
    );

    $self->send_message(\%message);
}

sub send_zdata {
    my $self        = shift;
    my $data        = shift;
    my $size        = shift;

    my $val         = Zmodem::Misc::longToString($size - length($data));

    ModemUtility::Misc::log("[send_zdata] run / Offset: ", 
                            $size - length($data),
    			            " Dump: ", unpack("H*", $val),
                            " Size: ", $size);

    my %message     = (
        enc     => chr(Zmodem::Constants::ZBIN32),
        type    => chr(Zmodem::Constants::ZDATA),
        f3p0    => substr($val, 0, 1) || chr(0),
        f2p1    => substr($val, 1, 1) || chr(0),
        f1p2    => substr($val, 2, 1) || chr(0),
        f0p3    => substr($val, 3, 1) || chr(0),
        data    => $data
    );

    $self->send_message(\%message);
}

# ----------------------------------------------------------------
package Zmodem::Receiver;

use strict;
use Device::Modem::Protocol::ModemUtility;
use IO::File;
no utf8;
use bytes;

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

    $opt{modus} = Zmodem::Constants::ZHEX if !exists $opt{modus};

    my $self = {
        _modem      => $opt{modem},
        _filename   => $opt{filename} || "test.dat",
        timeouts    => 0,
        modus       => $opt{modus} || Zmodem::Constants::ZHEX,
        zm_send     => $opt{zm_send},
      };

    # create Zmodem::Send for retrieving message
    if (!exists $opt{zm_send}) {
        $opt{zm_send} = new Zmodem::Send(
                            modem       => $opt{modem}, 
                            modus       => $opt{modus},
                            zm_retrieve => $self);
        $$self{zm_send} = $opt{zm_send};
    }

    bless $self, $class;
}

# Get `modem' Device::SerialPort member
sub modem {
    $_[0]->{_modem};
}

# read one character from modem and
# reescape the character if it's a special char
sub receive_char {
    my $self        = shift;
    my $count_in    = 0;
    my $received    = undef;
    my $done        = 0;

    while (1) {

        do {
            ($count_in, $received) = $self->modem->port->read(1);

            if ($count_in == 1) {
                if ($received eq chr(Zmodem::Constants::ZDLE)) {
                    $done = 1;
                }
                elsif ($received eq chr(0x11) or
                       $received eq chr(0x91) or
                       $received eq chr(0x13) or
                       $received eq chr(0x93)) {
                    $done = 1;
                }
                else {
                    # is it no special char
                    return $received;
                }
            }
        } until $done;

        # it is a special char!
        $done = 0;
        do {
            ($count_in, $received) = $self->modem->port->read(1);
            
            if ($count_in == 1) {
                if ($received eq chr(0x11) or
                    $received eq chr(0x13) or
                    $received eq chr(0x91) or
                    $received eq chr(0x93) or
                    $received eq chr(Zmodem::Constants::ZDLE)) {

                    $done = 1;
                }
                # set to bytes to signal a ZCRC frame
                elsif ($received eq chr(Zmodem::Constants::ZCRCE) or
                       $received eq chr(Zmodem::Constants::ZCRCG) or
                       $received eq chr(Zmodem::Constants::ZCRCQ) or
                       $received eq chr(Zmodem::Constants::ZCRCW)) {
                    return chr(1) . $received;
                }
                else {
                    if (($received & chr(0x60)) == chr(0x40)) {
                        return $received ^ chr(0x40);
                    }
                }
            }
        } until $done;
    } 
}

# retrieve a fixet value string
sub receive {
    my $self        = shift;
    my $count       = shift;
    my $data        = undef;
   
    do {
        $data .= $self->receive_char();

    }  until $count == length($data);

    return $data;
}

sub receive_dataBlock{
    my $self        = shift;
    my $done        = 0;
    my $received    = undef;
    my $type        = undef;
    my $data        = undef;
    my $crc         = undef;
    my $start_time  = time;
    my $crcOk       = 0;

    ModemUtility::Misc::log("[receive_dataBlock] read block");

    do {
        $received = $self->receive_char();

        # if it the last frame?
        if (length($received) == 2) { 
            $received = substr($received, 1, 1);
            if ($received eq chr(Zmodem::Constants::ZCRCW) or
                $received eq chr(Zmodem::Constants::ZCRCG) or
                $received eq chr(Zmodem::Constants::ZCRCE)) {

                $type   = $received;

                # read CRC / loop for slow connections
                do {
                    $received   = $self->receive_char();
                    $crc       .= $received;

                } until length($crc) == 4;

                $done   = 1;
            }
        }
        else {
            # set received data
            $data .= $received;
        }

        # time out
        if (time - $start_time > 10) {
            $done = 1;
            ModemUtility::Misc::log("[receive_message] TimeOut, no Zframe found!");
        }

    } until $done;

    # shift data is more than 1024 byte data
    if (length($data) > Zmodem::Constants::BLOCKSIZE) {
        ModemUtility::Misc::log("[receive_message] snip: ",
                        length($data) - Zmodem::Constants::BLOCKSIZE,
                        " Data: ", unpack("H*", substr($data, 0, 
                             length($data) - Zmodem::Constants::BLOCKSIZE)));

        $data = substr($data, length($data) - Zmodem::Constants::BLOCKSIZE);
    }

    # create crc
    my $my_crc  = pack("L", Zmodem::Misc::crc32($data . $type, 
                        length($data) + 1));
    $my_crc = ~$my_crc;

    ModemUtility::Misc::log("[receive_dataBlock] Length: ", length($data), 
                            " CRC: ", unpack("H*", $crc),
                            " MY CRC: ", unpack("H*", $my_crc));

    # crc false
    if ($my_crc ne $crc) {
        ModemUtility::Misc::log("[receive_dataBlock] !C: FFAALLSSEE");
    }
    else {
        $crcOk = 1;
    }

    # create data
    my %zcrc   = (
        data            => $data,
        type            => $type,
        crc             => $crcOk
    );

    return %zcrc;
}

# 
sub receive_data {
    my $self        = shift;
    my $done        = 0;
    my $crc         = 1;
    my $data        = undef;
    my %block       = ();
    my $count       = 0;
    my $false       = 0;

    do {
        # read next block
        %block      = $self->receive_dataBlock();

        ModemUtility::Misc::log("[receive_data] Read datablock: Type ",
                                unpack("H*", $block{type}), " ",
                                " size: ", length($block{data}),
                                " count: ", $count);

        if (!$block{crc}) {
            $crc    = 1;
            $false  = 1;
        }
        # if it the last frame?
        elsif ($block{type} eq chr(Zmodem::Constants::ZCRCW) or
                $block{type} eq chr(Zmodem::Constants::ZCRCE)) {
            $done   = 1;
        }

	    # if crc ok, use data
        if ($crc and !$false and length($block{data}) > 0) {
            $data .= $block{data};
        }

        ++$count;
    } until $done;

    # create data
    my %zcrcData   = (
        data            => $data,
        crc             => $crc,
    );

    return %zcrcData;
}

#
# Receive in stream mode. ZModem can change the format of message between
# request
#
sub receive_message {
    my $self                = shift;
    my $message_type        = undef;
    my $message_data        = undef;
    my $message_crc         = undef;
    my $message_crcValid    = undef;
    my $message_crcType     = undef;
    my $message_param1      = undef;
    my $message_param2      = undef;
    my $message_param3      = undef;
    my $message_param4      = undef;
    my $message_enc         = undef;
    my $message_number      = undef;
    my $count_in            = 0;
    my $received            = undef;
    my $done                = 0;
    my $frame               = 0;
    my $error               = 0;
    my $errstr              = undef;

    # Receive answer
    my $receive_start_time = time;

    ModemUtility::Misc::log("[receive_message] read Zframe");

    # read untile the frame of zmodem begins
    $done = $frame = 0;
    do {
        ($count_in, $received) = $self->modem->port->read(1);

        # Frame begin
        # Never change the frame! It use later for calculations
        if ($count_in == 1 and $received eq chr(Zmodem::Constants::ZPAD)) {
            $frame += 1;
        }

        # Header begin
        if ($count_in == 1 and $received eq chr(Zmodem::Constants::ZDLE) 
                and $frame) {
            $done = 1;
        }

        # time out
        if (time - $receive_start_time > 5) {
            $done = $error = 1;
            ModemUtility::Misc::log("[receive_message] TimeOut, no Zframe found!");
        }
        
        # print symbol
        if ($count_in > 0) {
            ModemUtility::Misc::log
                        ("[receive_message] Read character: $received (",                                    unpack("H*", $received), ") [$count_in]",
                                    " Frame: $frame");
        }

        # Connect end?
        if ($count_in == 1 and $received eq "O") {

            ($count_in, $received) = $self->modem->port->read(1);
            if ($received eq "O") {
                $done               = 1;
                $error              = 1;
                $message_crcValid   = 1;

                # set end
                $message_type       = chr(Zmodem::Constants::ZEND);
            }
        }

    } until $done;

    ModemUtility::Misc::log("[receive_message] parse message");

    # Read the message
    if (!$error) {
           
        # read type and enc
        ($count_in, $received) = $self->modem->port->read(1);
        $message_enc  = $received;

        $message_type = $self->receive($frame);
        if ($message_enc eq chr(Zmodem::Constants::ZHEX)) {
            $message_type = chr(hex($message_type));
        }

        # create information for CRC
        if ($message_enc eq chr(Zmodem::Constants::ZBIN) or 
                $message_enc eq chr(Zmodem::Constants::ZHEX)) {
           $message_crcType = ModemUtility::Constants::CRC16; 
        }
        else {
            $message_crcType = ModemUtility::Constants::CRC32;
        }

        # read parameters
        $received = $self->receive($frame * 4);
        if ($message_enc eq chr(Zmodem::Constants::ZHEX)) {
            $received = Zmodem::Misc::hexStr($received);
        }
        
        $message_param1 = substr($received, 0, 1);
        $message_param2 = substr($received, 1, 1);
        $message_param3 = substr($received, 2, 1);
        $message_param4 = substr($received, 3, 1);

        # read crc
        $received = $self->receive($frame * $message_crcType);
        if ($message_enc eq chr(Zmodem::Constants::ZHEX)) {
            $received = Zmodem::Misc::hexStr($received);
        }
        $message_crc            = $received;
        $message_crcValid       = 1;

        # read zcrc
        if ($message_type eq chr(Zmodem::Constants::ZFILE) or
            $message_type eq chr(Zmodem::Constants::ZDATA)) {
            
            ModemUtility::Misc::log("[receive_message] read ZCRC");
            
            my %data = $self->receive_data();

            if (!$data{crc}) {
                $message_crcValid  = 0;
            }
            else {
                $message_data = $data{data};
                ModemUtility::Misc::log("[receive_message] read ZCRC: ",
                                            length($data{data}));
            }
        }
    }

    my %message = (
        enc         => $message_enc,        # Message Type
        type        => $message_type,
        f3p0        => $message_param1,
        f2p1        => $message_param2,
        f1p2        => $message_param3,
        f0p3        => $message_param4,
        crc         => $message_crcValid,
        data        => $message_data,        # Message Data String
        number      => $message_number,      # Message Sequence Number
        error       => $error,
        errstr      => $errstr,
      );

    # log
    ModemUtility::Misc::log("[receive_message] Read follow data:",
                                " enc: ", $message{enc},
                                " type: ", unpack("H*", $message{type}),
                                " f3p0: ", unpack("H*", $message{f3p0}),
                                " f2p1: ", unpack("H*", $message{f2p1}),
                                " f1p2: ", unpack("H*", $message{f1p2}),
                                " f0p3: ", unpack("H*", $message{f0p3}),
                                " crc: ", unpack("H*", $message_crc),
                                " Valid: ", $message{crc},
                                " data lenght: ", length($message{data}));

    return %message;
}

sub run {
    my $self    = shift;
    my $modem   = $self->{_modem};
    my $file    = $_[1] || $self->{_filename};
    my $done    = 0;

    ModemUtility::Misc::log('[run] checking modem[', $modem, '] or file[', $file, '] members');
    return 0 unless $modem and $file;

    # Initialize transfer
    $self->{timeouts}      = 0;

    # Stage 1: send ZRINIT
    $self->{zm_send}->send_zrinit();

    # open file
    my $out         = new IO::File($file, "w");
    my $fileSize    = 0;
    my $fileSizeSet = 0;

    # raw
    $out->binmode(":raw");

    # Main receive cycle (subsequent timeout cycles)
    do {

        # Try to receive a message
        my %message = $self->receive_message();

        # CRC Error
        if (!$message{crc}) {
            ModemUtility::Misc::log("[run] <ZNAK>");

            # Resend data
            $self->{zm_send}->send_znak();
        }
        elsif ($message{type} eq chr(Zmodem::Constants::ZRINIT)) {
            ModemUtility::Misc::log("[run] <ZRINIT>");

            # resend init
            $self->{zm_send}->send_zrinit();
        }
        elsif ($message{type} eq chr(Zmodem::Constants::ZFILE)) {
            ModemUtility::Misc::log("[run] <ZFILE> ", $message{data});

            # Send ZRPOS for retrieve data
            $self->{zm_send}->send_zrpos(0);

        }
        elsif ($message{type} eq chr(Zmodem::Constants::ZDATA)) {
            ModemUtility::Misc::log("[run] <ZDATA>");
           
            $out->write($message{data}, length($message{data}));
            $fileSize += length($message{data});
        } 
        elsif ($message{type} eq chr(Zmodem::Constants::ZEOF)) {
            ModemUtility::Misc::log("[run] <ZEOF>");
            
            my $endSize = Zmodem::Misc::stringToLong($message{f3p0} . 
                                        $message{f2p1} .  $message{f1p2} . 
                                        $message{f0p3});
            
            # if the zeof biger than the trans file
            # send data 
            if ($fileSize != $endSize) {
            	ModemUtility::Misc::log("[run] <ZEOF> FileSize: ", $fileSize,
						" EndSize: ", $endSize);
                $self->{zm_send}->send_zrpos($fileSize);
            }
            # send finish
            else {
                $self->{zm_send}->send_zrinit();
            }
        }
        elsif ($message{type} eq chr(Zmodem::Constants::ZFIN)) {
            ModemUtility::Misc::log("[run] <ZFIN>");

            $self->{zm_send}->send_zfin();
        }
        elsif ($message{type} eq chr(Zmodem::Constants::ZEND)) {
            ModemUtility::Misc::log("[run] ENDE");

            $done = 1;
        }
        else {
            ModemUtility::Misc::log('[run] neither types found, sending timingout');
            ++$self->{timeouts};
        }

    } until $done or $self->timeouts() >= 10;

    undef $out;

    if ($self->timeouts() >= 10) {
        return 0;
    }

    return 1;
}

sub timeouts {
    my $self = $_[0];
    $self->{timeouts};
}

sub abort_transfer {
    my $self = $_[0];

    # Send a cancel chars to abort transfer
    ModemUtility::Misc::log('aborting transfer');
    $self->modem->atsend(unpack("A*", Zmodem::Constants::CANISTR));
    ModemUtility::Misc::write_drain($self->modem) unless $self->modem->ostype() eq 'windoze';
    $self->{aborted} = 1;
    return 1;
}



1;

=head1 NAME

Device::Modem::Protocol::Zmodem

=head1 Xmodem::Constants

Package that contains all useful Zmodem protocol constants used in 
handshaking and data blocks encoding procedures.

Follow constants important for new function in the other objects. Default are 
ZHEX. Only for Data transfer will be use ZBIN32.

=head2 Synopsis

    Zmodem::Constants::ZBIN .......... Binary header with 16 bit CRC
	Zmodem::Constants::ZHEX .......... ASCII hex encoded header with 16 bit CRC
	Zmodem::Constants::ZBIN32 ........ Binary header with 32 bit CRC 

=head1 Xmodem::Send

=head2 Synopsis

	my $send = Zmodem::Send->new(
 		modem    => {Device::Modem object},
		filename => 'name of file',
        [modus   => {Zmodem::Constants},]
	);

	$send->run();


=head1 Xmodem::Receiver

=head2 Synopsis

	my $recv = Zmodem::Receiver->new(
 		modem    => {Device::Modem object},
		filename => 'name of file',
        [modus   => {Zmodem::Constants},]
	);

	$recv->run();

=head2 Object methods

=over 4

=item abort_transfer()

Sends a B<cancel> C<string>), that signals to sender that transfer is aborted. This is
issued if we receive a bad block number, which usually means we got a bad line.

=item modem()

Returns the underlying L<Device::Modem> object.

=item run()

Starts a new transfer until file receive is complete. The only parameter accepted
is the (optional) local filename to be written.

=back

=head2 See also

=over 4

=item - L<Device::Modem>
=item - L<Device::Protocol::ModemUtility>
=item - L<Device::Protocol::Xmodem>

=back
