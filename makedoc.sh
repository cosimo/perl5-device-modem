#!/bin/sh
#
# $Id: makedoc.sh,v 1.3 2003-11-08 17:31:16 cosimo Exp $
#

#mv README README.old
#pod2text Modem.pm >README

mv Modem.html Modem.html.old
pod2html Modem.pm >docs/Modem.html

pod2html docs/FAQ.pod >docs/FAQ.html

perl -i.bak -pe 's/dev\.xproject\.org/cpan.org/g' docs/Modem.html
perl -i.bak -pe 's/dev\.xproject\.org/cpan.org/g' docs/FAQ.html
