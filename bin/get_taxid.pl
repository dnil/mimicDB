#!/usr/bin/perl -w
# 
# daniel.nilsson@izb.unibe.ch, daniel.k.nilsson@gmail.com, daniel.nilsson@scilifelab.se, daniel.nilsson@ki.se
#
# POD documentation to follow throughout the file - use e.g. perldoc to read
#
# (c) Daniel Nilsson, 2009-2010
# 
# 
=head1 NAME

query_and_print.pl

=head1 AUTHOR

Daniel Nilsson, daniel.nilsson@izb.unibe.ch, daniel.nilsson@ki.se, daniel.k.nilsson@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2009, 2010 held by Daniel Nilsson. The package is realesed for use under the Perl Artistic License.

=head1 DESCRIPTION

Prototype database query script, using DBI against a mysql server with mygo/mimicDB loaded.

=cut

use DBI;

my $DEBUG=0;

my $species="";
my $taxa_id;

while (my $arg = shift @ARGV) {

    if ($arg =~ /^-/) {	
	if ($arg eq '-s') {
	    my $next_arg = shift @ARGV; 
	    if($next_arg eq "") {
		print "-t requires an argument, but non given. Bailing out.\n";
		exit 1;
	    } else {
		$species = $next_arg;
	    }
	}
	
#	if($arg eq '-v') { 
#	}

    } else {	
	$species = $arg;
    }
}

if ($species eq "") {
    print "No species name given. USAGE: get_taxid.pl A_species\n";
    exit 1;
}

# retrieve mysql username and password from ENVironment

my $mysqluser;

if(!exists($ENV{MYSQLUSER}) or $ENV{MYSQLUSER} eq "") {
    $mysqluser = "mygo";
} else {
    $mysqluser = $ENV{MYSQLUSER};
}

my $mysqlpw;

if(!exists($ENV{MYSQLPWD}) or $ENV{MYSQLPWD} eq "") {
    $mysqlpwd = "m3g0_fo0";
} else {
    $mysqlpwd = $ENV{MYSQLPWD};
}

# use dbh

my $dbh = DBI->connect('dbi:mysql:mygo', $mysqluser, $mysqlpwd) || die "Could not connect to database $DBI::errstr";

#obtain brugia species id
my $sth=$dbh->prepare("select ncbi_taxa_id from species where concat(substring(genus,1,1),'_',species)=? or concat(genus,'_',species)=?;"); 
$sth->execute($species,$species);
my $result = $sth->fetchrow_hashref();
my $ncbi_taxa_id = $result->{'ncbi_taxa_id'};

$DEBUG && print STDERR "DEBUG: got species id ".$ncbi_taxa_id."\n";

print "$ncbi_taxa_id\n";

$sth->finish();
$dbh->disconnect();
