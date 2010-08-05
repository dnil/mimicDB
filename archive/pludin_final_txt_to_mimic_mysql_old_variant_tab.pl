#!/usr/bin/perl -w

use DBI;

my $DEBUG=0;

defined($ARGV[0]) || die "No file name given.\n";

open FINALTAB, "<".$ARGV[0];

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
# lacks error handling..

my $dbh = DBI->connect('dbi:mysql:mygo', $mysqluser, $mysqlpwd) || die "Could not connect to database $DBI::errstr";

#obtain species id; taxid Tc 5693, Tb 5691, Lm 5664, Cp 5807, 
my $sth=$dbh->prepare("select id from species where ncbi_taxa_id=5693");
$sth->execute();
my $result = $sth->fetchrow_hashref();
my $brugia_malayi_species_id = $result->{'id'};

$DEBUG && print STDERR "DEBUG: got bm species id ".$brugia_malayi_species_id."\n";

$sth = $dbh->prepare("select id from species where common_name='human'");
$sth->execute();
$result = $sth->fetchrow_hashref();
my $human_species_id = $result->{'id'};

$DEBUG && print STDERR "DEBUG: got hs species id ".$human_species_id."\n";

my %dumped_seq;

while($r=<FINALTAB>) {
    chomp $r;

    if($r=~/^Query\s+Description/) {
	#title row
    } else {
	($query_name,$query_start,$query_desc,$subject_accession, $subject_symbol, $subject_start, $subject_end, $identities, $subject_desc) = ($r=~/^(\S+)-(?:AA:)*(\d+|End)\t+([^\t]+)\t+([^\|]+)\|(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/);

	$query_desc =~ s/'/p/g;
	$subject_desc =~ s/'/p/g;

	$DEBUG && print STDERR "Got hit for $subject_symbol: ", join(" ", $query_name,$query_start,$query_desc,$subject_accession, $subject_symbol, $subject_start, $subject_end, $identities, $subject_desc), "\n";
	$score = "";
	       
	if($query_start eq "End") { 
	    $query_start = 9999999;
	}

	$query_end = $query_start+14-1; #well, in honesty, we don't known either start or end of query; alignment is actual alignlength, but peptide coordinate is 
       	
	if ( defined($dumped_seq{$query_name}) && $dumped_seq{$query_name} == 1) {
	    $DEBUG && print STDERR "No need to insert seq again for $query_name.\n";
	} else {
	    $dbh->do("insert into mimic_sequence (species_id, name, description) VALUES($brugia_malayi_species_id, '$query_name', '$query_desc')");
	    $dumped_seq{$query_name} = 1;
	} 
	
	$sth = $dbh->prepare("select id from mimic_sequence where name='$query_name' AND description='$query_desc'");
	$sth->execute();
	$result = $sth->fetchrow_hashref();
	my $query_mimic_sequence_id = $result->{'id'};
	$DEBUG && print "Mimic seq id was $query_mimic_sequence_id for $query_name\t$query_desc.\n";

	if (defined( $dumped_seq{$subject_accession}) && ($dumped_seq{$subject_accession} == 1)) {
	    $DEBUG && print STDERR "No need to insert seq again for $subject_accession.\n";
	} else {

	    $dbh->do("insert into mimic_sequence (species_id, name, description) VALUES($human_species_id, '$subject_accession', '$subject_desc')");
	    $dumped_seq{$subject_accession} = 1;

	    $sth = $dbh->prepare("select id from mimic_sequence where name='$subject_accession' AND description='$subject_desc'");
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

	$sth = $dbh->prepare("select id from mimic_sequence where name='$subject_accession' AND description='$subject_desc'");
	$sth->execute();
	$result = $sth->fetchrow_hashref();
	my $subject_mimic_sequence_id = $result->{'id'};

	#no score available.
	$dbh->do("INSERT INTO mimic_hit	(query_id,query_start,query_end, subject_id,subject_start,subject_end, identities) VALUES($query_mimic_sequence_id, $query_start, $query_end, $subject_mimic_sequence_id,$subject_start,$subject_end,$identities)");
    }
}

$sth->finish();
$dbh->disconnect();

#  LocalWords:  Dbh
