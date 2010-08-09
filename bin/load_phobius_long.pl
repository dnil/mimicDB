#!/usr/bin/perl -w

use DBI;

my $DEBUG = 1;

=head1 NAME

load_phobius_long.pl

=head1 AUTHOR

Daniel Nilsson, daniel.nilsson@izb.unibe.ch, daniel.nilsson@ki.se, daniel.k.nilsson@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2009, 2010 held by Daniel Nilsson. The package is realesed for use under the Perl Artistic License.

=head1 SYNOPSIS

USAGE: C<load_phobius_long.pl results.phobius_long_outoput>

=head1 DESCRIPTION

Loads phobius results file in the long format output into mimicDB.

=cut

my $phobius_long="";

while (my $arg = shift @ARGV) {

    if ($arg =~ /^-/) {	
	if ($arg eq '-f') {
	    my $next_arg = shift @ARGV; 
	    if($next_arg eq "") {
		print "-f requires an argument, but non given. Bailing out.\n";
		exit 1;
	    } else {		
	    }
	}
    } else {
	$phobius_long = $arg;
    }
}

if($phobius_long eq "") {
    print "No Phobius results file to search was given. Nothing to do!\n";
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

my $name="";
my $id="";

open PHOB, "<".$phobius_long;
while(my $l = <PHOB>) {    
    chomp $l;

    if($l =~/ID\s+(\S+)/ ) {
	$name = $1;
	if($name=~/^gi\|([^\|]+)\|.+/) {
	    $name = $1;
	} elsif($name=~/^([^\|]+)\|.+/) {
	    $name = $1;
	}

	my $sth=$dbh->prepare("select id from mimic_sequence where name='$name';");
	$sth->execute();
	my $result = $sth->fetchrow_hashref();
	$id = $result->{'id'};

    }

    if($l =~/FT\s+SIGNAL\s+(\d+)\s+(\d+)/) {
	$seq_start=$1;
	$seq_end =$2;

	$DEBUG && print join("\t", $name, ($id), "SIGNAL",$seq_start,$seq_end,1,0), "\n";
	$dbh->do("insert into mimic_sequence_motif (mimic_sequence_id, seq_start, seq_end,type, eval,score,identifier,description) VALUES($id, $seq_start,$seq_end,'PHOBIUS',0,1,'SIGNAL','');");
    } elsif($l =~/FT\s+TOPO_DOM\s+(\d+)\s+(\d+)\s+(.+)/) {
	$seq_start=$1;
	$seq_end =$2;

	# don't add TOPO to start with. Maybe later.
	if ($3 eq "NON CYTOPLASMIC") { 
	} elsif ($3 eq "CYTOPLASMIC") {
	}
    } elsif($l =~/FT\s+TRANSMEM\s+(\d+)\s+(\d+)/) {
	$seq_start=$1;
	$seq_end =$2;

	$DEBUG && print join("\t", $id, "TRANSMEM",$seq_start,$seq_end,1,0), "\n";
	$dbh->do("insert into mimic_sequence_motif (mimic_sequence_id, seq_start, seq_end,type, eval,score,identifier,description) VALUES($id, $seq_start,$seq_end,'PHOBIUS',0,1,'TRANSMEM','');");
	
    }
}

close PHOB;
