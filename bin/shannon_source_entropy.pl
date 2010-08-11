#!/usr/bin/perl

=head1 NAME

shannon_source_entropy.pl

=head1 AUTHOR

Daniel Nilsson, daniel.nilsson@izb.unibe.ch, daniel.nilsson@ki.se, daniel.k.nilsson@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2009, 2010 held by Daniel Nilsson. The package is realesed for use under the Perl Artistic License.

=head1 SYNOPSIS

USAGE: C<shannon_source_entropy.pl peptides.fasta>

=head1 DESCRIPTION

Calculates Shannon source entropy from peptide fasta files.

=cut

my $peptide_file=$ARGV[0];

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
