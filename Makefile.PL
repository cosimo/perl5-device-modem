use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Device::Modem',
    'VERSION_FROM'	=> 'Modem.pm', # finds $VERSION
    'PREREQ_PM'		=> { Device::SerialPort => '' } # e.g., Module::Name => 1.1

);
