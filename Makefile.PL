# $Id: Makefile.PL,v 1.2 2002-04-09 22:15:39 cosimo Exp $
use ExtUtils::MakeMaker;
WriteMakefile(
	'AUTHOR'        => 'Cosimo Streppone <cosimo@cpan.org>',
	'ABSTRACT_FROM' => 'Modem.pm',
    'NAME'	        => 'Device::Modem',
    'VERSION_FROM'	=> 'Modem.pm',
    'PREREQ_PM'		=> { Device::SerialPort => '' } 
);
