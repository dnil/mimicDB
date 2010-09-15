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

You will first want a database backend running.

=over 4

=item * 

Install e.g. the mysql server.

=item *

Download the GO term database, and install it.

=item * 

Run database creation script or manually, create a non-privilidged database user, install the GO term database and create additional needed tables (see separate documentation).

=back

Obtain a release of the mimicDB data, or do the following:

=over 4

=item * 

Run Philipp Ludin's mimicry pipeline on your species of interest. 

=item *

Obtain hmmer and a copy of the pfam database, if you want to make additional protein motif annotations.

=item * 

Obtain phobius, if you want to run additional protein signal peptide and topology predictions.

=back

Use this F<fill_db.sh> script to load the database.

=over 4 

=item * 

run C<fill_db.sh>, which will in turn run the additional protein annotation
programs and populate the database.

=back

To visualise the results you will also need a web server setup.

=over 4

=item *

Install a web server (package tested with Apache).

=item *

Install the perl Titanium package.

=item * 

Copy the web interface files from the interface directory to wherever
you want them within your web server document tree, and optionally change 
some configuration variables in the MimicDB.pm module.

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

=item BINDIR [path (~/sandbox/mimicDB/bin)]

Directory where the rest of the mimicDB pipeline lives.

=item DATADIR [path (~/sandbox/mimicDB/data/091028)]

Directory where the mimicDB data to load lives.

=item PFAMDB [path (~/sandbox/mimicDB/data/pfam/pfam-A.hmm)]

Directory where the pfam database lives.

=item PHOBIUSBIN [path (~/src/phobius/phobius.pl)]

Path to the phobius binary.

=item HMMSCANBIN [path (~/src/hmmer-3.0/src/hmmscan)]

Path to the phobius binary.

=item TMP [path (~/sandbox/mimicDB/tmp)]

Path to a directory where temporary files and intermediate results can be held/found. 
This directoty will be created at runtime if it does not already exist.

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
    DATADIR=~/sandbox/mimicDB/data/proteomes100831
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
    TMP=~/sandbox/mimicDB/tmp
fi

if [ ! -e "$TMP" ]
then 
    mkdir $TMP
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

# uses pipelinefunk.sh for needsUpdate, registerFile etc.

. pipelinefunk.sh

: <<'POD_FILES'

=back

=head1 FILES

=over 4

=item C<*-final>

Tabular files from Philipp Ludin's pipeline. Place in your data
directory for loading. I would suggest creating a specific "release"
directory under data to keep track of versions and updates. File name
convention is Species_parasite-Species_host-final (or A_parasite-final
if the host is H_sapiens). The names are important for NCBI taxonomy
id lookup and so for proper connection to the go-term db. Abbreviation
of the genus is ok if this still allows unique lookup of ncbi taxa
id. If unsure, just use the full species name. Genus and species are
separated by an underscore "_", the parasite and host by a dash "-",
and the file name ends in "-final".

=cut

POD_FILES

# load tables
echo Loading tables...

# bash >= 4 has associative arrays built in.
declare -A taxid

for file in $DATADIR/*final
do 
    parasp=`basename $file |cut -f1 -d-`
    hostsp=`basename $file |cut -f2 -d-`
    if [ "$hostsp" == "final" ] 
    then
	hostsp=H_sapiens
    fi

    # debug
    echo $parasp $hostsp >&2 
    taxid_parasite=`$BINDIR/get_taxid.pl $parasp`
    taxid_host=`$BINDIR/get_taxid.pl $hostsp`

    $BINDIR/pludin_final_txt_to_mimic_mysql.pl $file $taxid_parasite $taxid_host $IDCUTOFF

    taxid[$parasp]=$taxid_parasite
    # test adding host, though it's actually rather likey to already be set.
    taxid[$hostsp]=$taxid_host
done

# extract lists of loaded sequence names (after filtering on load)
echo Extract lists...

for species in ${!taxid[*]}
do
    load_list=$TMP/${species}_sequences_loaded.list

    registerFile $load_list temp
    $BINDIR/get_sequence_names_for_species.pl -t ${taxid[$species]} > $load_list
    
    shasum $load_list > $load_list.sha.new

    if [ -e $load_list.sha ]
    then
	shasum --status -c $load_list.sha
	if [ $? -ne 0 ]
	then
	    mv $load_list.sha2.new $load_list.sha
	else
	    :
	    # keep old checksum file, indicating that the file was not changed.
	fi
    else
	mv $load_list.sha.new $load_list.sha
    fi
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
echo Extract fasta sequences...
for this_species in ${!taxid[*]}
do
    load_list=$TMP/${this_species}_sequences_loaded.list
    load_fasta_file=$TMP/${this_species}_loaded.fasta
    species_fasta_file=$DATADIR/${this_species}.fasta
    
    # Note: I do have considerably faster fasta_header_grep versions in other projects for exact matching...
    if needsUpdate $load_fasta_file $load_list.sha2 $species_fasta_file $BINDIR/fasta_header_grep.pl
    then
	registerFile $load_fasta_file result
	$BINDIR/fasta_header_grep.pl -w -f $load_list $species_fasta_file > $load_fasta_file	
    fi

    $BINDIR/load_sequences_from_fasta_file.pl $load_fasta_file
    
done

echo Calculate Shannon entropy and upload...

$BINDIR/load_shannon_entropy.pl

# pfam -- cut_tc is maybe a little cautious, but anyway, this is for a webpage display..
echo Run PFAM search...
for this_species in ${!taxid[*]}
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
echo Run Phobius...
for this_species in ${!taxid[*]}
do 
    load_fasta_file=$TMP/${this_species}_loaded.fasta
    phobius_results=$TMP/${this_species}_loaded.phobius
    if needsUpdate $phobius_results $load_fasta_file
    then
	$PHOBIUSBIN -long $load_fasta_file > $phobius_results
    fi

    registerFile $phobius_results result
    $BINDIR/load_phobius_long.pl $phobius_results
done

: <<'POD_FILES'

=back

=cut

POD_FILES
