#!/bin/sh

mv README README.old
pod2text Modem.pm >README

mv Modem.html Modem.html.old
pod2html Modem.pm >Modem.html

