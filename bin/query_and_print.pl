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

my $taxa_id = 6279;

while (my $arg = shift @ARGV) {

    if ($arg =~ /^-/) {	
	if ($arg eq '-t') {
	    my $next_arg = shift @ARGV; 
	    if($next_arg eq "") {
		print "-t requires an argument, but non given. Bailing out.\n";
		exit 1;
	    } else {
		$taxa_id = $next_arg;
	    }
	}
	
#	if($arg eq '-v') { 
#	}

    } else {	

    }
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
my $sth=$dbh->prepare("select id from species where ncbi_taxa_id=$taxa_id");
$sth->execute();
my $result = $sth->fetchrow_hashref();
my $species_id = $result->{'id'};

$DEBUG && print STDERR "DEBUG: got species id ".$species_id."\n";

$sth=$dbh->prepare("select query_sequence.name, subject_sequence.name, identities from mimic_hit inner join mimic_sequence as query_sequence on (mimic_hit.query_id =query_sequence.id) inner join mimic_sequence as subject_sequence on (mimic_hit.subject_id = subject_sequence.id) where subject_sequence.species_id=$species_id;");
#select name from mimic_sequence ");
$sth->execute();

while (my @answer = $sth->fetchrow_array()) {
    print join (" ", @answer),"\n";
}

# dump names to tempfile
# fasta_header_grep
# pfam
# extract motifs
# upload

$sth->finish();
$dbh->disconnect();

#  LocalWords:  Dbh
