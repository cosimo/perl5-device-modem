# $Id: Makefile.PL,v 1.3 2002-04-29 16:56:42 cosimo Exp $
use ExtUtils::MakeMaker;
WriteMakefile(
	'AUTHOR'        => 'Cosimo Streppone <cosimo@cpan.org>',
	'ABSTRACT_FROM' => 'Modem.pm',
	'NAME'	        => 'Device::Modem',
	'VERSION_FROM'	=> 'Modem.pm',
	'PREREQ_PM'		=> $^O =~ /Win/i
                ? { Win32::SerialPort => '' }
                : { Device::SerialPort  => '' }
);
