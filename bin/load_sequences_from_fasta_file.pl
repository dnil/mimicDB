#!/usr/bin/perl -w

=head1 NAME

load_sequences_from_fasta_file.pl

=head1 AUTHOR

Daniel Nilsson, daniel.nilsson@izb.unibe.ch, daniel.nilsson@ki.se, daniel.k.nilsson@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2009, 2010 held by Daniel Nilsson. The package is realesed for use under the Perl Artistic License.

=head1 SYNOPSIS

USAGE: C<load_sequences_from_fasta_file.pl fasta.file>

It is important to note that the program attempts to match fasta names with the corresponding database names.

=head1 DESCRIPTION

Loads protein fasta file into mimicDB.

=cut

use DBI;

my $DEBUG = 1;

my $fastafile = "";

while (my $arg = shift @ARGV) {

    if ($arg =~ /^-/) {	
	if ($arg eq '-f') {
	    my $next_arg = shift @ARGV; 
	    if($next_arg eq "") {
		print "-f requires an argument, but non given. Bailing out.\n";
		exit 1;
	    } else {		
		# duh?
	    }
	}
    } else {
	$fastafile = $arg;
    }
}

if($fastafile eq "") {
    print "No fasta file to search was given. Nothing to do!\n";
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

open FASTAFILE, $fastafile or die "Could not open $fastafile.\n";

my $inseq = 0; 
my $seq = "";
my $name = "";

while (my $l = <FASTAFILE>) {
    chomp $l;
    
    if ($inseq) {

	if ($l =~ m/^>(\S+)/) { 
	    $inseq=1; 

	    $seq{$name}=$seq;
	    
	    $name = $1;
	    if($name=~/^gi\|([^\|]+)\|.+/) {
		$name = $1;
	    } elsif($name=~/^([^\|]+)\|.+/) {
		$name = $1;
	    }

	    $seq = "";
	} else {
	    $l =~ s/\s+//g;
	    $seq .= $l;	
	}	
    } elsif ($l =~ m/^>(\S+)/) { 
	# first time around..
	$inseq=1; 
	
	$name = $1;
	if($name=~/^gi\|([^\|]+)\|.+/) {
	    $name = $1;
	} elsif($name=~/^([^\|]+)\|.+/) {
	    $name = $1;
	}

	$seq = "";
    }
}

if($inseq==1) { 
    $seq{$name}=$seq;
}

foreach $name (keys %seq) { 
    # query for seqid of name
        
    my $sth=$dbh->prepare("select id from mimic_sequence where name='$name';");
    $sth->execute();
    my $result = $sth->fetchrow_hashref();
    my $named_seq_id = $result->{'id'};

    if(!defined($named_seq_id) or $named_seq_id eq "" or $DBI::err) {	
	warn "Could not find name $name in mimic_sequence. Ignoring current entry.";
	next;
    }

    $DEBUG && print STDERR "Name: $name mimic_sequence_id: $named_seq_id.\n";

    my $seq_len=length($seq{$name});

    $dbh->do("insert into mimic_sequence_seq (mimic_sequence_id, seq_len, seq) VALUES($named_seq_id, $seq_len, '".$seq{$name}."');");
    
}
