#!/usr/bin/perl -w
#
# load_pfam_file.pl
#
# (c) Daniel Nilsson, 2009-2010
# 
# Released under the Perl Artistic License.
# 
# Version for use with hmmer2.
#

use DBI;

my $DEBUG = 1;

my $pfamfile = "";

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


my %description;

while (my $l = <PFAMFILE>) {
    chomp $l;
    
    if ($inentry) {

	if( $infamily == 1) {

	    if($l eq "") {
		$infamily =0;		
	    } elsif ($l =~ /\-{5,}\s+\-{5,}/) {
	    } else {
		
		($identifier, $desc) = ($l =~ m/(\S+)\s+(.+)\s+[\d\.]+\s+[-e\d\.]+\s+\d+$/);
		
		if(!defined($identifier) or $identifier eq "") {
		    $DEBUG && print "No hit.\n";
		} else {
		    $desc =~ s/'/p/g;
		    
		    $description{$identifier} = $desc;
		    $DEBUG && print $identifier, "\t", $desc, "\n";
		}
	    }
	}

	elsif( $indomain == 1) {

	    if ($l =~ /\-{5,}\s+\-{5,}/) {
		
	    } elsif ($l =~ m/^\/\//) { 
		$indomain=0;
		$inentry=0; 
		
		$name="";
		$identifier= "";
	    } else {
		
		($identifier,$seq_start,$seq_end,$score,$evalue) = ($l =~ m/^(\S+)\s+[\d\/]+\s+(\d+)\s+(\d+)\s+[\.\[\]]{2}\s+\d+\s+\d+\s+[\.\[\]]{2}\s+([\d\.]+)\s+([-e\d\.]+)/);
#		$DEBUG && print $l,"\n";
		if(!defined($identifier) or $identifier eq "") {
		    $DEBUG && print "No hit.\n";
		} else {
		    $DEBUG && print join("\t", $name, $identifier, $description{$identifier},$seq_start,$seq_end,$score,$evalue), "\n";
		    $dbh->do("insert into mimic_sequence_motif (mimic_sequence_id, seq_start, seq_end,type, eval,score,identifier,description) VALUES($named_seq_id, $seq_start,$seq_end,'PFAM_LS','$evalue','$score','$identifier','".$description{$identifier}."');");
		}
	    }
	    
	} elsif ($l =~ /Model\s+Description/) {
	    $infamily = 1;          	    
	} elsif ($l =~ /Model\s+Domain/) {
	    $indomain = 1;
	}

    } elsif ($l =~ m/^Query sequence:\s+(\S+)/) { 
	# first time around..
	$inentry=1; 

	$infamily=0;
	$indomain=0;

	$name = $1;
	if($name=~/^gi\|([^\|]+)\|.+/) {
	    $name = $1;
	} elsif($name=~/^([^\|]+)\|.+/) {
	    $name = $1;
	}

	my $sth=$dbh->prepare("select id from mimic_sequence where name='$name';");
	$sth->execute();
	my $result = $sth->fetchrow_hashref();
	$named_seq_id = $result->{'id'};
	
    }
}
