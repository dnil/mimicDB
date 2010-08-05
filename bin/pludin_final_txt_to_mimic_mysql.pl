#!/usr/bin/perl -w
# Daniel Nilsson, 2009

#usage: txt_to_mysql tabfilename parasite_taxa_id host_tax_id id_cutoff 
# ./interface/pludin_final_txt_to_mimic_mysql.pl data/brugia090130/B_malayi-090130-final.txt 6279 9606 11
# ./interface/pludin_final_txt_to_mimic_mysql.pl data/brugia-aedes-090204/B_malayi-final 6279 7159 11

use DBI;

my $DEBUG=0;

defined($ARGV[0]) || die "No file name given.\n";

open FINALTAB, "<".$ARGV[0];

my $parasite_ncbi_taxa_id = 6279; #default to brugia
my $host_ncbi_taxa_id = 9606; #default to human; aedes egypti ncbi_taxa_id=7159

if( @ARGV > 1 ) {
    $parasite_ncbi_taxa_id = $ARGV[1];
    $host_ncbi_taxa_id = $ARGV[2];
}    

my $id_cutoff = 0;
if( @ARGV > 3 ) {
    $id_cutoff = $ARGV[3];
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

# use dbh, insert rows instead to be able to query for autoincrement ids directly?
# lacks error handling..

my $dbh = DBI->connect('dbi:mysql:mygo', $mysqluser, $mysqlpwd) || die "Could not connect to database $DBI::errstr";

#obtain brugia species id
my $sth=$dbh->prepare("select id from species where ncbi_taxa_id=$parasite_ncbi_taxa_id");
$sth->execute() or die "Could not get species id for ncbi_taxa_id=$parasite_ncbi_taxa_id: $DBI::errstr\n";
my $result = $sth->fetchrow_hashref();
my $parasite_species_id = $result->{'id'};

$DEBUG && print STDERR "DEBUG: got parasite species id ".$parasite_species_id."\n"; #query species

#get target species id  

$sth = $dbh->prepare("select id from species where ncbi_taxa_id=$host_ncbi_taxa_id");
$sth->execute() or die "Could not get species id for ncbi_taxa_id=$host_ncbi_taxa_id: $DBI::errstr\n";
$result = $sth->fetchrow_hashref();
my $host_species_id = $result->{'id'};

$DEBUG && print STDERR "DEBUG: got host species id ".$host_species_id."\n"; #target species

my %dumped_seq;

while($r=<FINALTAB>) {
    chomp $r;

    if($r=~/^Query\s+Description/) {
	#title row
    } else {

	if ( $r=~/^\S+-(?:AA:)*(?:\d+|End)\t+[^\t]+\t+\S+\s+\d+\s+\d+\s+\d+\s+[\d\.]+\s+\d+\s+[\d\.]+\s+.+$/) {
	    ($query_name,$query_start,$query_desc,$subject_accession, $subject_start, $subject_end, $identities, $score, $subject_desc) = ($r=~/^(\S+)-(?:AA:)*(\d+|End)\t+([^\t]+)\t+(\S+)\s+(\d+)\s+(\d+)\s+\d+\s+[\d\.]+\s+(\d+)\s+([\d\.]+)\s+(.+)$/);
	} elsif ($r=~/^\S+-(?:AA:)*(?:\d+|End)\t+[^\t]+\t+\S+\s+\d+\s+\d+\s+\d+\s+.+$/) {
	    ($query_name,$query_start,$query_desc,$subject_accession, $subject_start, $subject_end, $identities, $subject_desc) = $r=~/^(\S+)-(?:AA:)*(\d+|End)\t+([^\t]+)\t+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/
	}


	if(!defined($score) or $score eq "") {
	    $score = 0;
	}

	if($query_name=~/^([^\|]+)\|.+/) {
	    $query_name = $1;
	}

	# obsoletes the above host_taxa_id hack...
	if($subject_accession=~/^([^\|]+)\|(.+)/) {
	    $subject_accession = $1;
	    $subject_symbol = $2;
	} else {
	    $subject_symbol=$subject_accession;
	}


	$query_desc =~ s/'/p/g;
	$subject_desc =~ s/'/p/g;

	$DEBUG && print STDERR "Got hit for $subject_accession: ", join(" ", $query_name,$query_start,$query_desc,$subject_accession, $subject_symbol, $subject_start, $subject_end, $identities, $score, $subject_desc), "\n";

	if($query_start eq "End") { 
	    $query_start = 9999999;
	}

	$query_end = $query_start+14-1; #well, in honesty, we don't known either start or end of query; alignment is actual alignlength, but peptide coordinate is 

	if($identities < $id_cutoff) {
	    $DEBUG && print STDERR "Ids $identities fewer than id_cutoff $id_cutoff for $query_name. Drop.\n";
	    next;
	}

	if ( exists($dumped_seq{$query_name}) && defined($dumped_seq{$query_name}) && $dumped_seq{$query_name} == 1) {
	    $DEBUG && print STDERR "No need to insert seq again for $query_name.\n";
	} else {
	    $dbh->do("insert into mimic_sequence (species_id, name, description) VALUES($parasite_species_id, '$query_name', '$query_desc')");
	    $dumped_seq{$query_name} = 1;

	    if($DBI::err) {
		warn "Problem encountered when attempting to insert parasite seq $query_name into mimic_sequence for species_id=$parasite_species_id: $DBI::errstr\nIn all likelihood this simply had homology to a previously loaded species as well, and is not to be considered an error.";
	    }
 	}
	
	$sth = $dbh->prepare("select id from mimic_sequence where name='$query_name' AND species_id='$parasite_species_id'");
	$sth->execute();
	$result = $sth->fetchrow_hashref();
	my $query_mimic_sequence_id = $result->{'id'};
	$DEBUG && print "Mimic seq id was $query_mimic_sequence_id for $query_name\t$query_desc.\n";
	if ( ! defined ($query_mimic_sequence_id )) {
	    die "Bailing out: Mimic seq id could not be retrieved for $query_name (desc: $query_desc) in $parasite_species_id.\n";
	}

	if ( exists( $dumped_seq{$subject_accession} ) && defined( $dumped_seq{$subject_accession} ) && ( $dumped_seq{$subject_accession} == 1 ) ) {
	    $DEBUG && print STDERR "No need to insert seq again for $subject_accession.\n";
	} else {
	    $DEBUG && print "Insert into mimic_seq $host_species_id, $subject_accession, $subject_desc while dumped flag ".$dumped_seq{$subject_accession}.".\n";
	    $dbh->do("insert into mimic_sequence (species_id, name, description) VALUES($host_species_id, '$subject_accession', '$subject_desc')");

	    if($DBI::err) {
		warn "Problem encountered when attempting to insert host sequence $subject_accession into mimic_sequence for species_id=$host_species_id: $DBI::errstr\nIn all likelihood this simply had homology to a previously loaded parasite species as well, and is not to be considered an error.";
	    }

	    $dumped_seq{$subject_accession} = 1;
	    
	    $sth = $dbh->prepare("select id from mimic_sequence where name='$subject_accession' AND species_id='$host_species_id'");
	    $sth->execute();
	    $result = $sth->fetchrow_hashref();
	    my $mimic_sequence_id = $result->{'id'};

	    $sth = $dbh->prepare("select distinct gene_product.id from gene_product inner join dbxref on (dbxref.id = gene_product.dbxref_id) inner join association on (association.gene_product_id=gene_product.id) where dbxref.xref_key = '$subject_accession'");
	    $sth->execute();
	    $result = $sth->fetchrow_hashref();
	    my $gene_product_id = $result->{'id'};
	    	    	    
	    if( defined($gene_product_id) && ($gene_product_id > 0) ) { 

		$dbh->do("insert into mimic_sequence_with_go_association (gene_product_id, mimic_sequence_id) VALUES($gene_product_id, $mimic_sequence_id)");

	    } else {
		# empty set, no go association for this accession.
	    }

	} 

	$sth = $dbh->prepare("select id from mimic_sequence where name='$subject_accession' AND species_id='$host_species_id'");
	$sth->execute();
	$result = $sth->fetchrow_hashref();
	my $subject_mimic_sequence_id = $result->{'id'};
	if( !defined($subject_mimic_sequence_id) ) {
	    print "Could not retrive id for $subject_accession\t$subject_desc.\nNo insert.\n";
	} else {
	    $dbh->do("INSERT INTO mimic_hit (query_id,query_start,query_end, subject_id,subject_start,subject_end,score,identities) VALUES($query_mimic_sequence_id, $query_start, $query_end, $subject_mimic_sequence_id,$subject_start,$subject_end,'$score',$identities)");
	}
    }
}

$sth->finish();
$dbh->disconnect();

#  LocalWords:  Dbh
