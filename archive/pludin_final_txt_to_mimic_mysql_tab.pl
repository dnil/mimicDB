#!/usr/bin/perl -w

open FINALTAB, "<".$ARGV[0];
#open OUT_MIMIC_HIT, ">", $ARGV[0].".mimic_hit_tab";
#open OUT_MIMIC_SEQ, ">", $ARGV[0].".mimic_seq_tab";
#open OUT_MIMIC, ">", $ARGV[0].".mimic_hit_tab";

my %dumped_seq;

while($r=<FINALTAB>) {
    if($r=~/^Query\s+Description\.+Human\s*$/) {
	#title row
    } else {
	($query_name,$query_start,$query_desc,$subject_accession, $subject_symbol, $subject_start, $subject_end, $identities, $score, $subject_desc) = ($r=~/^(\S+)-AA:(\d+)\t+([^\t]+)\t+([^\|]+)\|(\S+)\s+(\d+)\s+(\d+)\s+\d+\s+[\d\.]+\s+(\d+)\s+([\d\.]+)\s+(.+)/);
	    $query_end = $query_start+14;
	

	if ( ! $dumped_seq{$query_name} ) {
	    
	    $dumped_seq{$query_name} = 1;
	}

	if ( ! $dumped_seq{$subject_accession} ) {

	    $dumped_seq{$subject_accession} = 1;
	}
	print OUT_MIMIC_HIT "\\N\t\\N\t$query_start\t$query_end\t\\N\t$subject_start\t$subject_end\t$score\t$identities\n";


    }

}
