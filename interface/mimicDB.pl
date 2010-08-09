#!/usr/bin/perl -w -I/var/www/localhost/cgi-bin

=head1 NAME

mimicDB.pl

=head1 AUTHOR

Daniel Nilsson, daniel.nilsson@izb.unibe.ch, daniel.nilsson@ki.se, daniel.k.nilsson@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2009, 2010 held by Daniel Nilsson. The package is realesed for use under the Perl Artistic License.

=head1 DESCRIPTION

When called, typically via the CGI interface of a web server,
F<mimicDB.pl> loads F<MimicDB.pm>, creates an instance of the class
and starts it. See F<MimicDB.pm> for details.

=cut

use MimicDB;

my $mimicDB = MimicDB->new();
$mimicDB->run();
