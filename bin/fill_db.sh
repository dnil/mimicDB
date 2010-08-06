#!/bin/bash
# Daniel Nilsson, 090421 
# 
# daniel.nilsson@izb.unibe.ch, daniel.k.nilsson@gmail.com
#
# POD documentation to follow throughout the file - use e.g. perldoc to read
#
# (C) Daniel Nilsson, 2009-2010

: <<'POD_INIT'

=head1 NAME

fill_db.sh

=head1 AUTHOR

Daniel Nilsson, daniel.nilsson@izb.unibe.ch, daniel.nilsson@ki.se, daniel.k.nilsson@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2009, 2010 held by Daniel Nilsson. The package is realesed for use under the Perl Artistic License.

=head1 DESCRIPTION

Populates the mimicDB mysql database from mimicry csv table form data.
On the filtered hit sequences, fill_db.sh will run hmmer against PFAM,
and Phobius, and uploads the results.

=head1 SYNOPSIS

USAGE: C<fill_db.sh>

See README and INSTALL for more instructions. Briefly an initial setup
workflow would be as follows.

You will want a database backend:

=over 4

=item * 

Install e.g. the mysql server.

=item *

Download the GO term database, and install it.

=item * 

Run database creation script or manually, create a non-privilidged database user, install the GO term database and create additional needed tables (see separate documentation).

=back

Then obtain a release of the mimicDB data, or do the following:

=over 4

=item * 

Run Philipp Ludin's mimicry pipeline on your species of interes.t

=item *

Obtain hmmer and a copy of the pfam database, if you want to make additional protein motif annotations.

=item * 

Obtain phobius, if you want to run additional protein signal peptide and topology predictions.

=back

=over 4 

Then use this script to load the database.

=item * 

run fill_db.sh, which will run the additional protein annotation programs and populate the database.

=back

To visualise the results you will also need a web server setup.

=over 4

=item *

Install a web server (package tested with Apache).

=item *

Install the perl Titanium package.

=item * 

Copy the web interface files from the interface directory to wherever
you want them within your web server document tree.

=back

=head1 SHELL ENVIRONMENT VARIABLES

Several environment variables influence the pipeline behaviour.

=over 4

=cut

POD_INIT

# User defined ENV

: <<'POD_ENV'

=item IDCUTOFF [integer (11)]

Minimum number of identities required in matches to load entry to database.

=item BINDIR [path (~/mimicDB/interface)]          

Directory where the rest of the mimicDB pipeline lives.

=item DATADIR [path (~/mimicDB/data/091028)]

Directory where the mimicDB data to load lives. 

=item PFAMDB [path (~/mimicDB/data/pfam/Pfam_ls.bin)]

Directory where the pfam database lives. 

=item PHOBIUSBIN [path (~/install/phobius/phobius.pl)]

Path to the phobius binary.

=item TMP [path (~/mimicDB/tmp)]

Path to a directory where temporary files and intermediate results can be held/found.

=item MYSQLUSER [username (mygo)]

=item MYSQLPWD [password (m3g0_fo0)]

MySQL user name and password with select and insert rights on the mimicDB db.

=cut

POD_ENV

if [ -z "$IDCUTOFF" ]
then
    IDCUTOFF=11
fi

if [ -z "$BINDIR" ]
then
    BINDIR=~/sandbox/mimicDB/bin
fi

if [ -z "$DATADIR" ]
then
    DATADIR=~/sandbox/mimicDB/data/UpdProteomes
fi

if [ -z "$PFAMDB" ]
then
    PFAMDB=~/sandbox/mimicDB/data/pfam/Pfam-A.hmm
fi

if [ -z "$PHOBIUSBIN" ]
then
    PHOBIUSBIN=~/src/phobius/phobius.pl
fi

if [ -z "$HMMSCANBIN" ]
then
    # hmmpfam for hmmer-2
    HMMSCANBIN=~/src/hmmer-3.0/src/hmmscan
fi

if [ -z "$TMP" ]
then
    TMP=~/sabdbix/mimicDB/tmp
fi

if [ -z "$MYSQLUSER" ]
then
    MYSQLUSER="mygo"
fi 

if [ -z "$MYSQLPWD" ]
then
    MYSQLPWD="m3g0_fo0"
fi

export MYSQLUSER MYSQL

: << 'POD_ENV'

=item NN_TAXID [integer]

E.g. HS_TAXID=9696 for H. sapiens.

Hardcoded NCBI taxonomy ids - could be replaced with database lookups
from names or such, but we are still operating very much on a small
scale here, with only a few complete host-parasite-vector cycles
available and rather little need for automation yet.

=cut

POD_ENV

# hardcoded NCBI taxonomy ids

BM_TAXID=6279
HS_TAXID=9606

BT_TAXID=9913

AE_TAXID=7159

AG_TAXID=7165

PF_TAXID=5833
CP_TAXID=5807
TP_TAXID=5875
EC_TAXID=6035

TB_TAXID=5691
LM_TAXID=5664
TC_TAXID=5693

EH_TAXID=5759

SM_TAXID=6183

BB_TAXID=139
LMO_TAXID=1639
LP_TAXID=446
MT_TAXID=1773
SA_TAXID=1280
YP_TAXID=632

: <<'POD_ENV'

=item taxid [(list of taxid integers)]

A list of the taxonomy ids to be considered for loading. 

=item species [(list of species identifiers)]

A list of species identifiers carefully ensure the same order in species and taxid.

Known problem: this is inelegant and works only for small sets of
organisms.  A more clever way of dealing with the TAXID and cvs
pairings is perhaps to let the user give the taxids as part of the
filenames?

=cut

POD_ENV

# carefully ensure the same order in species and taxid
species=(B_malayi P_falciparum T_brucei T_cruzi L_major T_parva H_sapiens B_taurus A_aegypti A_gambiae E_histolytica S_mansoni E_cuniculi C_parvum B_burgdorferi L_monocytogenes L_pneumophila M_tuberculosis S_aureus Y_pestis)
taxid=($BM_TAXID $PF_TAXID $TB_TAXID $TC_TAXID $LM_TAXID $TP_TAXID $HS_TAXID $BT_TAXID $AE_TAXID $AG_TAXID $EH_TAXID $SM_TAXID $EC_TAXID $CP_TAXID $BB_TAXID $LMO_TAXID $LP_TAXID $MT_TAXID $SA_TAXID $YP_TAXID)

# END ENV

# uses pipelinefunk.sh for needsUpdate, registerFile etc.

. pipelinefunk.sh

nr_of_species=${#species[@]}

# a more clever way of dealing with the TAXID and cvs pairings/triad resolutions for loading is
# perhaps to let the user give the taxids as part of the filenames?

: <<'POD_FILES'

=back

=head1 FILES

=over 4

=item C<*-final>

Tabular files from Philipp Ludin's pipeline. Place in your data
directory for loading. I would suggest creating a specific "release"
directory under data to keep track of versions and updates. 

=cut

POD_FILES

o# load tables
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/B_malayi-final $BM_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/B_malayi-aedes-final $BM_TAXID $AE_TAXID $IDCUTOFF

$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/P_falciparum-final $PF_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/P_falciparum-anopheles-final $PF_TAXID $AG_TAXID $IDCUTOFF

# $BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/T_brucei-final $TB_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/T_brucei-B_taurus-final $TB_TAXID $BT_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/T_parva-B_taurus-final $TP_TAXID $BT_TAXID $IDCUTOFF

$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/T_cruzi-final $TC_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/L_major-final $LM_TAXID $HS_TAXID $IDCUTOFF

$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/E_histolytica-final $EH_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/S_mansoni-final $SM_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/E_cuniculi-final $EC_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/C_parvum-final $CP_TAXID $HS_TAXID $IDCUTOFF

#bacterial
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/B_burgdorferi-final $BB_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/L_monocytogenes-final $LMO_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/L_pneumophila-final $LP_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/M_tuberculosis-final $MT_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/S_aureus-final $SA_TAXID $HS_TAXID $IDCUTOFF
$BINDIR/pludin_final_txt_to_mimic_mysql.pl $DATADIR/Y_pestis-final $YP_TAXID $HS_TAXID $IDCUTOFF

# extract lists of loaded sequence names (after filtering on load)

for speciesnr in ${!species[*]}
do 
    load_list=$TMP/${species[$speciesnr]}_sequences_loaded.list

    registerFile $load_list temp
    $BINDIR/get_sequence_names_for_species.pl -t ${taxid[$speciesnr]} > $load_list

done

: << 'POD_FILES'

=item C<species.fasta>

Species specific peptide fasta files, containing (at least) the mimic
hit candidates. Any sequence without an accepted hit will not be
loaded to the database. We do provide linkout to uniprot/genbank, the
sequence data is mainly for visualisation.

=cut

POD_FILES

# extract fasta sequences
for this_species in ${species[@]}
do
    load_list=$TMP/${this_species}_sequences_loaded.list
    load_fasta_file=$TMP/${this_species}_loaded.fasta
    species_fasta_file=$DATADIR/${this_species}.fasta
    
    # Note: I do have considerably faster fasta_header_grep versions in other projects for exact matching...
    if needsUpdate $load_fasta_file $load_list $species_fasta_file $BINDIR/fasta_header_grep.pl
	registerFile $load_fasta_file result
	$BINDIR/fasta_header_grep.pl -w -f $load_list $species_fasta_file > $load_fasta_file	
    fi

    $BINDIR/load_sequences_from_fasta_file.pl $load_fasta_file

done

# pfam -- cut_tc is maybe a little cautious, but anyway, this is for a webpage display..
for this_species in ${species[@]}
do 
    load_fasta_file=$TMP/${this_species}_loaded.fasta
    pfam_results=$TMP/${this_species}_loaded.pfam_ls
    if needsUpdate $pfam_results $load_fasta_file $PFAMDB
    then
	registerFile $pfam_results result
#	$HMMSCANBIN --cut_tc -A0 $PFAMDB $load_fasta_file > $pfam_results
	$HMMSCANBIN --cut_tc --noali $PFAMDB $load_fasta_file > $pfam_results
    fi
    
    $BINDIR/load_pfam_file.pl $pfam_results

done

# phobius
for this_species in ${species[@]}
do 
    load_fasta_file=$TMP/${this_species}_loaded.fasta
    phobius_results=$TMP/${this_species}_loaded.phobius
    if needsUpdate $phobius_results $load_fasta_file
	$PHOBIUSBIN -long $load_fasta_file > $phobius_results
    fi

    registerFile $phobius_results result
    $BINDIR/load_phobius_long.pl $phobius_results
done

: <<'POD_FILES'

=back

=cut

POD_FILES