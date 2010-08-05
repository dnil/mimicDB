#!/bin/bash
# Daniel Nilsson, 091116

species=(B_malayi P_falciparum T_brucei T_cruzi L_major H_sapiens B_taurus A_aegypti A_gambiae E_histolytica S_mansoni E_cuniculi C_parvum B_burgdorferi L_monocytogenes L_pneumophila M_tuberculosis S_aureus Y_pestis)

BINDIR=~/mimicDB/mimicDB/interface
DATADIR=~/mimicDB/mimicDB/data
THISTMP=~/mimicDB/mimicDB/tmp

for this_species in ${species[@]}
do 
    hmmpfam --cut_tc -A0 $DATADIR/pfam/Pfam_ls.bin $THISTMP/${this_species}_loaded.fasta > $THISTMP/${this_species}_loaded.pfam_ls
done
