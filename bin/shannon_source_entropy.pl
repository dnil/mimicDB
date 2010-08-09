#!/usr/bin/perl

#my $proteome_file=$ARGV[0];
my $peptide_file=$ARGV[0];

# read proteome

#open PROTEOMEFILE, $proteome_file or die "Could not open $proteome_file.\nUsage: shannon_all_messages.pl proteome.fasta peptide.fasta\n";

#my $inseq = 0; 
#my $seq = "";
#my $name = "";

#my %aa;

#while (my $l = <PROTEOMEFILE>) {
#    chomp $l;
#    
#    if ($inseq) {

#  	if ($l =~ m/^>(\S+)/) { 
#  	    $inseq=1;

#  	    my @residues=split(/ */,$seq);
#  	    map { $aa{$_} = (exists($aa{$_}))?($aa{$_}+1):1 } @residues;
		  
#  	    $seq = "";
#  	} else {
#  	    $l =~ s/\s+//g;
#  	    $seq .= $l;	
#  	}	
#      } elsif ($l =~ m/^>(\S+)/) { 
#  	# first time around..
#  	$inseq=1; 
	
#  	$seq = "";
#      }
#  }

# # # last entry
# if($inseq==1) { 
#     my @residues=split(/ */,$seq);
#     map { $aa{$_} = exists($aa{$_})?$aa{$_}+1:1 } @residues;	  
# }

# close PROTEOMEFILE;

open PEPTIDEFILE, $peptide_file or die "Could not open $peptide_file.\n";

$inseq = 0; 
$seq = "";
$name = "";

while (my $l = <PEPTIDEFILE>) {
    chomp $l;
    
    if ($inseq) {

	if ($l =~ m/^>(\S+)/) { 
	    $inseq=1;

	    my @residues=split(/ */,$seq);

	    my %aa={};
  	    map { $aa{$_} = (exists($aa{$_}))?($aa{$_}+1):1 } @residues;

	    my $aas=0;
	    map { $aas+=$_ } values(%aa);

	    my %p={};
	    map { $p{$_} = $aa{$_}/$aas } keys(%aa);

	    my $H=0;

	    map { if (exists($p{$_}) && $p{$_}!=0) { $H -= $p{$_} * log($p{$_})/log(2) } } keys(%aa);

	    print $name."\t".$H."\n";

	    # new
	    $name = $1;
	    $seq = "";
	} else {
	    $l =~ s/\s+//g;
	    $seq .= $l;
	}
    } elsif ($l =~ m/^>(\S+)/) { 
	# first time around..
	$inseq=1;
	
	$name = $1;
	$seq = "";
    }
}

# last entry
if($inseq==1) { 
    my @residues=split(/ */,$seq);
    
    my %aa ={};
    map { $aa{$_} = (exists($aa{$_}))?($aa{$_}+1):1 } @residues;
    
    my $aas=0;
    map { $aas+=$_ } values(%aa);
    
    my %p={};
    map { $p{$_} = $aa{$_}/$aas } keys(%aa);
    
    my $H=0;
    map { if (exists($p{$_}) && $p{$_}!=0) { $H -= $p{$_} * log($p{$_})/log(2) } } keys(%aa);
    print $name."\t".$H."\n";
}

close PEPTIDEFILE;
