#!/usr/bin/perl -w

use DBI;

my $DEBUG = 1;

=head1 NAME

load_pfam_file.pl

=head1 AUTHOR

Daniel Nilsson, daniel.nilsson@izb.unibe.ch, daniel.nilsson@ki.se, daniel.k.nilsson@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2009, 2010 held by Daniel Nilsson. The package is realesed for use under the Perl Artistic License.

=head1 SYNOPSIS

USAGE: C<load_pfam_file.pl results.phobius_long_outoput>

=head1 DESCRIPTION

Loads hmmer-3 PFAM search results file into mimicDB.
See F<archive/load_pfam_file.pl> for a hmmer-2 version.

=cut

my $pfamfile = "";

while (my $arg = shift @ARGV) {

    if ($arg =~ /^-/) {	
	if ($arg eq '-f') {
	    my $next_arg = shift @ARGV;
	    if($next_arg eq "") {
		print "-f requires an argument, but non given. Bailing out.\n";
		exit 1;
	    } else {
		$pfamfile = $next_arg;
	    }
	}
    } else {
	$pfamfile = $arg;
    }
}

if($pfamfile eq "") {
    print "No pfam file to search was given. Nothing to do!\n";
    exit 1;
}

open PFAMFILE, $pfamfile or die "Could not open $pfamfile.\n";

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

my $inentry = 0; 
my $name = "";
my $named_seq_id = 0;
my $identifier = "";
my ($seq_start,$seq_end,$score,$evalue) = (0,0,0,0);

my $desc = "";

while (my $l = <PFAMFILE>) {
    chomp $l;
    
    if ($inentry) {

	if( $indomain == 1) {

	    if ($l =~ /\-{5,}\s+\-{5,}/) {

	    } elsif ($l =~ /^\>\>\s+(\S+)\s+(.+)/) {
		    $identifier =$1;
		    $desc = $2;

	    } elsif ($l =~ m/^\/\//) { 
		$indomain=0;
		$inentry=0; 
		
		$name="";
		$identifier= "";
	    } else {
		# ignore any "?" flagged lines, below inclusion threshold
#		$DEBUG && print $l,"\n";

		# catch hmm score, i-Evalue, env from and env to from motif desc.
		if( $l =~ m/^\s*\d+\s+\!\s+([-\d\.]+)\s+[\d\.]+\s+[-e\d\.]+\s+([-e\d\.]+)\s+\d+\s+\d+\s+[\.\[\]]{2}\s+\d+\s+\d+\s+[\.\[\]]{2}\s+(\d+)\s+(\d+)\s+[\.\[\]]{2}\s+[\d\.]+/ ) {
		    ($score, $evalue, $seq_start,$seq_end) = ($1,$2,$3,$4);

		    $DEBUG && print join("\t", $name, $identifier, $desc,$seq_start,$seq_end,$score,$evalue), "\n";
		    $dbh->do("insert into mimic_sequence_motif (mimic_sequence_id, seq_start, seq_end,type, eval,score,identifier,description) VALUES(?,?,?,?,?,?,?,?);",undef, $named_seq_id, $seq_start,$seq_end,'PFAM_LS',$evalue,$score,$identifier,$desc);
		} else {
#		    $DEBUG && print "[[ line ignored ]].\n"
		}
	    }
	} elsif ($l =~ /^\>\>\s+(\S+)\s+(.+)/) {
	    $identifier =$1;
	    $desc = $2;
	    $indomain = 1;
	}

    } elsif ($l =~ m/^Query:\s+(\S+)/) { 
	# first time around..
	$inentry=1;
	$indomain=0;

	$name = $1;
	if($name=~/^gi\|([^\|]+)\|.+/) {
	    $name = $1;
	} elsif($name=~/^([^\|]+)\|.+/) {
	    $name = $1;
	}
	
	$DEBUG && print "query $name\n";

	my $sth=$dbh->prepare("select id from mimic_sequence where name='$name';");
	$sth->execute();
	my $result = $sth->fetchrow_hashref();
	$named_seq_id = $result->{'id'};
	
    }
}
