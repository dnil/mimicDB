#!/usr/bin/perl -w -I/var/www/localhost/cgi-bin

use MimicDB;

my $mimicDB = MimicDB->new();
$mimicDB->run();
