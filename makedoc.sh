#!/bin/sh
#
# $Id: makedoc.sh,v 1.2 2002-09-03 20:00:32 cosimo Exp $
#

mv README README.old
pod2text Modem.pm >README

mv Modem.html Modem.html.old
pod2html Modem.pm >Modem.html

perl -i.bak -pe 's/dev\.xproject\.org/cpan.org/g' Modem.html
