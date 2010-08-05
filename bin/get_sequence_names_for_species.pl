#!/usr/bin/perl -w

=head1 NAME

get_sequence_names_for_species.pl

=head1 AUTHOR

Daniel Nilsson, daniel.nilsson@izb.unibe.ch, daniel.nilsson@ki.se, daniel.k.nilsson@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2009, 2010 held by Daniel Nilsson. The package is realesed for use under the Perl Artistic License.

=head1 SYNOPSIS

USAGE: C<<get_sequence_names_for_species.pl [-t <ncbi_taxa_id (6279)>]>>

A test program to retrieve species names.

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

# obtain requested species id
my $sth=$dbh->prepare("select id from species where ncbi_taxa_id=$taxa_id");
$sth->execute();
my $result = $sth->fetchrow_hashref();
my $species_id = $result->{'id'};

$DEBUG && print STDERR "DEBUG: got species id ".$species_id."\n";

$sth=$dbh->prepare("select name from mimic_sequence where species_id=$species_id");
$sth->execute() or die "Could not list mimic_sequence where species_id=$species_id: $DBI::errstr\n";

while (my @answer = $sth->fetchrow_array()) {
    print $answer[0],"\n";
}

if($DBI::err) {
    warn "Error during fetch from mimic_sequence, species_id=$species_id: $DBI::errstr\n";
}

$sth->finish();
$dbh->disconnect();

#  LocalWords:  Dbh
