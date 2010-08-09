#!/usr/bin/perl -w

# Installing Titanium: tests succeeded but 3 dependencies missing (CGI::Application::Server,Test::WWW::Mechanize::CGIApp,Module::Starter::Plugin::CGIApp)
#
# create fulltext index termname on term (name);

package MimicDB;
use base 'Titanium';

#
# CONFIGURATION OPTIONS
#
my $myurl = 'http://130.237.207.130/cgi-bin/mimicDB.pl';
my $mycss = '/mimicDB/mimicDB.css';
my $mysqluser = 'mimicdb';
my $mysqlpasswd = 'w3bbpublIC';
#
# END CONFIGURATION OPTIONS -- you should not need to edit below.
#

=over 4

=item setup

The module provides three run modes, 

=cut

sub setup {
    my $self = shift;

    $self->start_mode('simple_go_search');
    $self->run_modes(['simple_go_search', 'output_hit_table', 'show_hit_details']);
    $self->mode_param('rm');

    # db connect
    $self->dbh_config('dbi:mysql:mygo', $mysqluser, $mysqlpasswd);
}

sub teardown {
    my $self = shift;

    #db drop connection
    my $dbh = $self->dbh();
    $dbh->disconnect();
}

sub simple_go_search {
    my $self = shift;

   # Get the CGI.pm query object
    my $q = $self->query();
    $self->header_add("Content-Style-Type"=> "text/css");

    my $output .= $q->start_html(-title => "mimicDB - putative host-pathogen molecular mimicry",
				 -head => $q->Link({-rel=>'stylesheet',-type=>'text/css',-href=>$mycss,-media=>'screen'}));

    $output .= "<p><a style=\"text-decoration: none\" href=\"$myurl\"><SPAN class=\"mi\">mi</SPAN><SPAN class=\"micDB\">mi</SPAN><SPAN class=\"micDB\">cDB</SPAN></a><SPAN class=\"version\"> - alpha version</SPAN></p>"; 
    $output .= $q->start_form();
    $output .= "<center>";
    $output .= $q->h2("Putative host-pathogen molecular mimicry candidates.");
    $output .= "\n";
    $output .= "<p><input type=\"hidden\" name=\"rm\" value=\"output_hit_table\" />\n";

    $output .= $q->textfield(-name=>'goterm',
			     -value=>'GO:0005887',
			     -size=>37,
			     -maxlength=>255);
    $output .= $q->submit(-name=>'go_search',
			  -value=>'Search');

    $output .= "\n";
    $output .= $q->p("Search the database to display mimicry candidates.");
    $output .= $q->p("Or try an example: <a href=\"$myurl?rm=output_hit_table&goterm=GO:0002376\">GO:0002376</a>, <a href=\"$myurl?rm=output_hit_table&goterm=GO:immune\">GO:immune</a>, <a href=\"$myurl?rm=output_hit_table&goterm=SPARC\">SPARC</a>, <a href=\"$myurl?rm=output_hit_table&goterm=Q8NBI4\">Q8NBI4</a>, <a href=\"$myurl?rm=output_hit_table&goterm=cytokine%20species:Homo%20sapiens\">cytokine species\:<i>Homo sapiens</i></a>, <a href=\"$myurl?rm=output_hit_table&goterm=cgd4_3550\">cgd4_3550</a>.");
    # GO:0000502
    $output .= $q->p("<ul><li>Use keywords prefixed by <b>GO:</b> to query the full <a target=go href=\"http://www.geneontology.org\">GO</a> tree and not only annotated leaf terms. <li>Use the <b>species:</b> prefix to restrict the species.</ul>");
    $output .= $q->p("By Philipp Ludin, <a href=\"mailto:daniel.nilsson\@izb.unibe.ch\">Daniel Nilsson</a> and Pascal M&auml;ser.");
    $output .= "</center>";

    $output .= $q->end_form();
    $output .= $q->end_html();

    return $output;
}

sub output_hit_table {
    my $self = shift;
    
    my $q = $self->query();
    my $dbh = $self->dbh();
    
    my $goterm = $q->param('goterm');
    
#    put style-type etc in $q->header()
    $self->header_add("-Content-Style-Type"=>"text/css");
    my $output .= $q->start_html(-title => "mimicDB - query: ".$goterm,
				 -head => $q->Link({-rel=>'stylesheet',-type=>'text/css',-href=>$mycss,-media=>'screen'}));

    my %linkout_hash = ( 1 => "<a href=\"$myurl?rm=show_hit_details&name=linkPLACEholder\">linkPLACEholder</a><br><a  class=\"linkout\" href=\"http://www.uniprot.org/uniprot/linkPLACEholder\">UniProt</a>", 
			 4 => "<a href=\"$myurl?rm=output_hit_table&goterm=linkPLACEholder\">linkPLACEholder</a><br><a class=\"linkout\" href=\"http://amigo.geneontology.org/cgi-bin/amigo/term-details.cgi?term=linkPLACEholder\">AmiGO</a>",
			 9 => "<a href=\"$myurl?rm=show_hit_details&name=linkPLACEholder\">linkPLACEholder</a><br><a class=\"linkout\" href=\"http://www.ncbi.nlm.nih.gov/sites/entrez?db=gene&cmd=search&term=linkPLACEholder\">NCBI</a>");
    
    my $sth;
    $output .= "<p><a style=\"text-decoration: none\" href=\"$myurl\"><SPAN class=\"mi\">mi</SPAN><SPAN class=\"micDB\">mi</SPAN><SPAN class=\"micDB\">cDB</SPAN></a><SPAN class=\"version\"> - alpha version</SPAN></p>";

    my $select_species_statement = "";
    my $query_genus = "";
    my $query_species = "";
    
    if ( $goterm =~ /species:(\S+)\s+(\S+)/ ) { # unsafe
	$query_genus = $1;
	$query_species = $2;
	$select_species_statement .= "AND ((species.genus='$query_genus' AND species.species='$query_species') OR (subject_species.genus='$query_genus' AND subject_species.species='$query_species'))";
	$goterm =~ s/species:\S+\s+\S+//;
    }
    
    $output .= "<p>Query = $goterm";
    if($query_species ne "") {
	$output .= " in $query_genus $query_species";
    }
    $output .="</p>\n";
    if ( $goterm =~ /GO:\d+/ ) {
#	$sth = $dbh->prepare("SELECT term.acc, term.name, term.term_type, gene_product.symbol AS subject_symbol,mimic_sequence.name AS subject_acc, mimic_hit.subject_start,mimic_hit.subject_end, query_mimic_sequence.name AS query_name, mimic_hit.query_start, mimic_hit.query_end, mimic_hit.identities, mimic_hit.score FROM mimic_hit INNER JOIN mimic_sequence_with_go_association ON (mimic_sequence_with_go_association.mimic_sequence_id=mimic_hit.subject_id) INNER JOIN gene_product ON (mimic_sequence_with_go_association.gene_product_id = gene_product.id) INNER JOIN association ON (association.gene_product_id=gene_product.id) INNER JOIN term ON (term.id=association.term_id) INNER JOIN mimic_sequence ON (mimic_sequence.id=mimic_sequence_with_go_association.mimic_sequence_id) INNER JOIN mimic_sequence AS query_mimic_sequence ON (query_mimic_sequence.id = mimic_hit.query_id) WHERE term.acc = '$goterm' ORDER BY identities DESC, score DESC");
	$sth = $dbh->prepare("SELECT DISTINCT gene_product.symbol AS subject_symbol, mimic_sequence.name AS subject_acc, concat(subject_species.genus,' ', subject_species.species) AS host_species, mimic_sequence.description AS subject_desc, term.acc, term.name, term.term_type, mimic_hit.subject_start,mimic_hit.subject_end, query_mimic_sequence.name AS query_name, concat(species.genus,\" \", species.species) AS parasite_species, query_mimic_sequence.description as query_desc, mimic_hit.query_start, mimic_hit.query_end, mimic_hit.identities, mimic_hit.score FROM term INNER JOIN graph_path ON (term.id=graph_path.term1_id) INNER JOIN association ON (graph_path.term2_id=association.term_id) INNER JOIN gene_product ON (association.gene_product_id=gene_product.id) INNER JOIN mimic_sequence_with_go_association ON (mimic_sequence_with_go_association.gene_product_id = gene_product.id) INNER JOIN mimic_hit ON  (mimic_sequence_with_go_association.mimic_sequence_id=mimic_hit.subject_id) INNER JOIN mimic_sequence ON (mimic_sequence.id=mimic_sequence_with_go_association.mimic_sequence_id) INNER JOIN mimic_sequence AS query_mimic_sequence ON (query_mimic_sequence.id = mimic_hit.query_id) INNER join species ON (species.id = query_mimic_sequence.species_id) INNER JOIN species AS subject_species ON (subject_species.id = mimic_sequence.species_id) WHERE (term.acc=? AND association.is_not=0) $select_species_statement ORDER BY subject_symbol, query_name, identities DESC, score DESC, query_start, subject_start,name");

    } elsif ( $goterm =~ /GO:/ ) {
	$goterm=~s/GO://;

$sth = $dbh->prepare("SELECT DISTINCT gene_product.symbol AS subject_symbol, mimic_sequence.name AS subject_acc, concat(subject_species.genus,' ', subject_species.species) AS host_species, mimic_sequence.description AS subject_desc, term.acc, term.name, term.term_type, mimic_hit.subject_start,mimic_hit.subject_end, query_mimic_sequence.name AS query_name, concat(species.genus,' ', species.species) AS parasite_species, query_mimic_sequence.description as query_desc, mimic_hit.query_start, mimic_hit.query_end, mimic_hit.identities, mimic_hit.score FROM term INNER JOIN graph_path ON (term.id=graph_path.term1_id) INNER JOIN association ON (graph_path.term2_id=association.term_id) INNER JOIN gene_product ON (association.gene_product_id=gene_product.id) INNER JOIN mimic_sequence_with_go_association ON (mimic_sequence_with_go_association.gene_product_id = gene_product.id) INNER JOIN mimic_hit ON (mimic_sequence_with_go_association.mimic_sequence_id=mimic_hit.subject_id) INNER JOIN mimic_sequence ON (mimic_sequence.id=mimic_sequence_with_go_association.mimic_sequence_id) INNER JOIN mimic_sequence AS query_mimic_sequence ON (query_mimic_sequence.id = mimic_hit.query_id) INNER join species ON (species.id = query_mimic_sequence.species_id) INNER JOIN species AS subject_species ON (subject_species.id = mimic_sequence.species_id) WHERE (MATCH(term.name) AGAINST (?) AND association.is_not=0) $select_species_statement ORDER BY subject_symbol, query_name, identities DESC, score DESC, query_start, subject_start,name");

#select term.acc, term.name, term.type,gene_product.symbol,query_mimic_seq.name as query_name, subject_mimic_seq.name as subject_name, from gene_product inner join mimic_sequence_with_go_association on (mimic_sequence_with_go_association.gene_product_id = gene_product.id) inner join mimic_sequence as query_mimic_sequence on (mimic_sequence.id=mimic_sequence_with_go_association.mimic_seq_id) inner join mimice_sequence as subject_mimic_sequence on (mimic_sequence.id = mimic_sequence_with_go_association.gene_product.gene_product_id) inner join association on (association.gene_product_id=gene_product.id) inner join term on (term.id=association.term_id) where term.acc = $goterm");   
#select term.name, term.term_type, term.acc, dbxref.xref_key, gene_product.symbol from gene_product inner join dbxref on (dbxref.id = gene_product.dbxref_id) inner join association on (association.gene_product_id=gene_product.id) inner join term on (term.id=association.term_id) where term.acc='GO:0000502'
    } else {
    # only including direct annotations to the term, not hits against children..
	$sth = $dbh->prepare("SELECT DISTINCT gene_product.symbol AS subject_symbol, mimic_sequence.name AS subject_acc, concat(subject_species.genus,' ', subject_species.species) AS host_species, mimic_sequence.description AS subject_desc, term.acc, term.name, term.term_type, mimic_hit.subject_start,mimic_hit.subject_end, query_mimic_sequence.name AS query_name, concat(species.genus,' ', species.species) AS parasite_species, query_mimic_sequence.description as query_desc, mimic_hit.query_start, mimic_hit.query_end, mimic_hit.identities, mimic_hit.score FROM mimic_hit LEFT OUTER JOIN mimic_sequence ON (mimic_sequence.id=mimic_hit.subject_id) LEFT OUTER JOIN mimic_sequence AS query_mimic_sequence ON (query_mimic_sequence.id = mimic_hit.query_id) INNER join species ON (species.id = query_mimic_sequence.species_id) INNER JOIN species AS subject_species ON (subject_species.id = mimic_sequence.species_id) LEFT OUTER JOIN mimic_sequence_with_go_association ON (mimic_sequence_with_go_association.mimic_sequence_id=mimic_hit.subject_id) LEFT OUTER JOIN gene_product ON (mimic_sequence_with_go_association.gene_product_id = gene_product.id) LEFT OUTER JOIN association ON (association.gene_product_id=gene_product.id) LEFT OUTER JOIN term ON (term.id=association.term_id) WHERE (MATCH(term.name) AGAINST (?) OR MATCH(mimic_sequence.description) AGAINST ('$goterm') OR MATCH(mimic_sequence.name) AGAINST ('$goterm') OR MATCH(gene_product.symbol, gene_product.full_name) AGAINST ('$goterm') OR MATCH (query_mimic_sequence.description) AGAINST ('$goterm') OR MATCH(query_mimic_sequence.name) AGAINST ('+$goterm' IN BOOLEAN MODE)) $select_species_statement ORDER BY subject_symbol, query_name, identities DESC, score DESC, query_start, subject_start,name"); 
# unsafe! goterm occurs multiple times..

# SELECT FROM mimic_hit LEFT OUTER JOIN mimic_sequence ON (mimic_sequence.id=mimic_hit.subject_id) LEFT OUTER JOIN mimic_sequence AS query_mimic_sequence ON (query_mimic_sequence.id = mimic_hit.query_id) INNER join species ON (species.id = query_mimic_sequence.species_id) LEFT OUTER JOIN mimic_sequence_with_go_association ON (mimic_sequence_with_go_association.mimic_sequence_id=mimic_hit.subject_id) LEFT OUTER JOIN gene_product ON (mimic_sequence_with_go_association.gene_product_id = gene_product.id) LEFT OUTER JOIN association ON (association.gene_product_id=gene_product.id) LEFT OUTER JOIN term ON (term.id=association.term_id)  WHERE MATCH(term.name) AGAINST ('cytokine') OR MATCH(mimic_sequence.description) AGAINST ('cytokine') OR MATCH(mimic_sequence.name) AGAINST ('cytokine') OR MATCH(gene_product.symbol, gene_product.full_name) AGAINST ('cytokine') OR MATCH (query_mimic_sequence.description) AGAINST ('cytokine') OR MATCH(query_mimic_sequence.name) AGAINST ('+cytokine' IN BOOLEAN MODE) AND species.genus='Brugia' AND species.species='malayi' ;
    }

    $sth->execute($goterm);
    
    #header
    @header = ("Host symbol","Host acc", "Host species","Host protein description", "GO accession","GO term", "GO type", "Host start", "Host end", "Parasite name", "Parasite species", "Parasite protein description", "P start", "P end", "Ids", "Score");
    my @answer = $sth->fetchrow_array();
    
    my @last_answer = ();
    my @unfold_trigger_fields = (0,9,14);

    if(scalar(@answer) == 0) {
	$output .= "<h2>No mimicry found with the indicated search term.</h2>";
    } else { 
	
	$output .= "<table>";
	
	$output .= "\n<tr>";
	$output .= $self->_alternate_color_element_join("th",@header);
	$output .= "</tr>\n";

	my @temp_answer = @answer;
	$self->_remove_nonvarying_fields( \@unfold_trigger_fields, \@answer, \@last_answer ) unless @last_answer == ();
	@last_answer = @temp_answer;

	$self->_linkout_columns(\%linkout_hash, \@answer);

	$output .= "\n<tr>";
	$output .= $self->_alternate_color_element_join("td",@answer);
	#have link on each row for hit//query details, linkout to ncbi etc.
	$output .= "</tr>\n";
	
	while (@answer = $sth->fetchrow_array())
	{       
	    @temp_answer = @answer;
	    $self->_remove_nonvarying_fields( \@unfold_trigger_fields, \@answer, \@last_answer ) unless @last_answer == ();
	    @last_answer = @temp_answer;
	    $self->_linkout_columns(\%linkout_hash, \@answer);

	    $output .= "\n<tr>";
	    $output .= $self->_alternate_color_element_join("td",@answer);
	    #have link on each row for hit//query details, linkout to ncbi etc.
	    $output .= "</td></tr>\n";
	}
	$sth->finish();
	
	$output .= "</table>\n";
    }
     
    $output .= $q->end_html();

    return $output;
}

sub show_hit_details {
    my $self = shift;

    my $q = $self->query();
    my $dbh = $self->dbh();

    # header and logo
    my $queryname = $q->param('name');

    $self->header_add("-Content-Style-Type"=>"text/css");
    my $output .= $q->start_html(-title => "mimicDB - details: ".$queryname,
				 -head => $q->Link({-rel=>'stylesheet',-type=>'text/css',-href=>$mycss,-media=>'screen'}));
    
    $output .= "<p><a style=\"text-decoration: none\" href=\"$myurl\"><SPAN class=\"mi\">mi</SPAN><SPAN class=\"micDB\">mi</SPAN><SPAN class=\"micDB\">cDB</SPAN></a><SPAN class=\"version\"> - alpha version</SPAN></p>";
    
    # Sequence details

    # Retrieve Name, Species name, Sequence length, and Actual AA Sequence.
    $sth = $dbh->prepare("select name,concat(species.genus,\" \", species.species) AS species, description, seq_len, seq from mimic_sequence_seq inner join mimic_sequence on (mimic_sequence_seq.mimic_sequence_id=mimic_sequence.id) inner join species on (mimic_sequence.species_id=species.id) where mimic_sequence.name=?;");
    $sth->execute($queryname);

    # Immediately output the first info table. Postpone sequence output for later so we can add markup.
    my @answer = $sth->fetchrow_array();
    my $seq = $answer[scalar(@answer)-1];

    $output .= "<h3>Sequence details</h3><table>";
    @header = ("Name","Species", "Description", "Size (aa)");

    $output .= "\n<tr>";
    $output .= $self->_alternate_color_element_join("th",@header);
    $output .= "</tr>\n";

    $output .= "\n<tr>";
    $output .= $self->_alternate_color_element_join("td",@answer[0..(@answer-2)]);
    $output .="</tr></table>\n";

    $output.= "<br>"; #<span class=\"sequence\">";
#    $output .= $self->_linebreak(\$seq, 60,"<br>");
#    $output .="</span>";
  
    # Get motifs for query
    $sth = $dbh->prepare("select name,identifier,mimic_sequence_motif.description,seq_start,seq_end,score,eval,type from mimic_sequence_motif inner join mimic_sequence on (mimic_sequence_motif.mimic_sequence_id=mimic_sequence.id) where mimic_sequence.name=?;");
    $sth->execute($queryname);

    my @motifstart =();
    my @motifend =();

    if(@answer>0) {
    
	# Save motif table for query for later output
	$postpone_output .= "<h3>Motifs</h3><table>";
	@header = ("Name","Motif","Description","Start", "End", "Score","Eval","Type");
	$postpone_output .= "\n<tr>";
	$postpone_output .= $self->_alternate_color_element_join("th",@header);
	$postpone_output .= "</tr>\n";
	
	while (@answer = $sth->fetchrow_array()) {
	    # Save motif coordinates for main query for markup
	    push @motifstart,$answer[3];
	    push @motifend,$answer[4];
	    
	    $postpone_output .= "\n<tr>";
	    $postpone_output .= $self->_alternate_color_element_join("td",@answer);
	    $postpone_output .= "\n</tr>";
	}
	$postpone_output .="</table>\n"; # main query motif table end
    }

    # Get hit information for query

    # Postponed output of query hit table
    $postpone_output .= "<h3>Hits</h3><table>"; # main query hit table start

    @header = ("Parasite name","P start", "P end", "Host name","H start", "H end","Score","Identities");
    $postpone_output .= "\n<tr>";
    $postpone_output .= $self->_alternate_color_element_join("th",@header);
    $postpone_output .= "</tr>\n";

    $sth = $dbh->prepare("select query_sequence.name, query_start, query_end, subject_sequence.name, subject_start, subject_end, score, identities from mimic_hit inner join mimic_sequence as query_sequence on (mimic_hit.query_id =query_sequence.id) inner join mimic_sequence as subject_sequence on (mimic_hit.subject_id = subject_sequence.id) where (query_sequence.name =? or subject_sequence.name = ?);");

    $sth->execute($queryname,$queryname);
    my @hits = ();
    my @hitstart= ();
    my @hitend= ();

    while (@answer = $sth->fetchrow_array()) {	
	
	my $query_sequence_name = $answer[0]; 
	my $subject_sequence_name = $answer[3];

	if ($queryname eq $query_sequence_name) {
	    # Save coordinates for later markup

	    push @hits, $subject_sequence_name;
	    # query, ie parasite = page querysequence
	    push @hitstart, $answer[1];
	    push @hitend, $answer[2];

	    push @hithitstart, $answer[4];
	    push @hithitend, $answer[5];

	} elsif ( $queryname eq $subject_sequence_name) {
	    # Save coordinates for later markup

	    push @hits, $query_sequence_name;
	    # subject, ie host = page querysequence
	    push @hitstart, $answer[4];
	    push @hitend, $answer[5];

	    push @hithitstart, $answer[1];
	    push @hithitend, $answer[2];
	}

	$postpone_output .= "\n<tr>";
	$postpone_output .= $self->_alternate_color_element_join("td",@answer);
	$postpone_output .= "\n</tr>";
    }
    $postpone_output .="</table>\n"; # ends main query hits table
    
    $postpone_output .= "<table>"; # begin list-of-hits subtable

    # main query hits table done and added to postponed output. Now only display details once per hit sequence..

    my @displayed_hits = ();

    foreach my $hitname (@hits) {

	# ensure each hit detail is only displayed once 
	my $unique=1;
	foreach my $displayed_hit (@displayed_hits) {
	    if($displayed_hit eq $hitname) {
		$unique=0;
	    } 
	}
	if($unique == 1) {
	    push @displayed_hits, $hitname;
	} else {
	    next;
	}

	$sth = $dbh->prepare("select name,concat(species.genus,\" \", species.species) AS species, description, seq_len, seq from mimic_sequence_seq inner join mimic_sequence on (mimic_sequence_seq.mimic_sequence_id=mimic_sequence.id) inner join species on (mimic_sequence.species_id=species.id) where mimic_sequence.name='$hitname';");
	$sth->execute();
	@answer = $sth->fetchrow_array();
	$hitseq = $answer[scalar(@answer)-1];
	
	$postpone_output .= "<h4>Hit sequence details</h4><table>"; # start hit sequence details table
	@header = ("Name","Species", "Description", "Size (aa)");
	
	$postpone_output .= "\n<tr>";
	$postpone_output .= $self->_alternate_color_element_join("th",@header);
	$postpone_output .= "</tr>\n";

	$postpone_output .= "\n<tr>";
	$postpone_output .= $self->_alternate_color_element_join("td",@answer[0..(@answer-2)]);
	$postpone_output .="</tr></table>\n"; # end hit sequence details table

#	$postpone_output.= "<br><span class=\"sequence\">";
#	$postpone_output .= $self->_linebreak(\$hitseq, 60,"<br>");      
#	$postpone_output .="</span>";
       	
	$sth = $dbh->prepare("select name,identifier,mimic_sequence_motif.description,seq_start,seq_end,score,eval,type from mimic_sequence_motif inner join mimic_sequence on (mimic_sequence_motif.mimic_sequence_id=mimic_sequence.id) where mimic_sequence.name='$hitname';");
	$sth->execute();
	
	$more_postponed_output="";
	$more_postponed_output .= "<h4>Hit sequence motifs</h4><table>"; #start hit sequence motifs table
	@header = ("Name","Motif","Description","Start", "End", "Score","Eval","Type");
	$more_postponed_output .= "\n<tr>";
	$more_postponed_output .= $self->_alternate_color_element_join("th",@header);
	$more_postponed_output .= "</tr>\n";

	my @hitmotifstart = ();
	my @hitmotifend = ();

	while (@answer = $sth->fetchrow_array()) {
	    $more_postponed_output .= "\n<tr>";
	    $more_postponed_output .= $self->_alternate_color_element_join("td",@answer);
	    $more_postponed_output .= "\n</tr>";

	    push @hitmotifstart,$answer[3];
	    push @hitmotifend,$answer[4];
	}
	$more_postponed_output .="</table>\n"; #end hit sequence motifs table

	$postpone_output.= "<br>";

	my @hitseq= split(/ */,$hitseq);
	my @hit_motif_markup = split(/ */,'0'x@hitseq);
	my @hit_hit_markup = split(/ */,'0'x@seq);
#    $output .= "<br> There were ".scalar(@motifstart)." motifs and ".scalar(@hitstart)." hits.<br>\n";
	
	for (my $i=0; $i<@hitmotifstart; $i++) {
	    for (my $j=$hitmotifstart[$i]-1; $j < $hitmotifend[$i]; $j++) {
		$hit_motif_markup[$j]=1;	    
	    }
	}
	
	for (my $i=0; $i<@hithitstart; $i++) {
	    if($hits[$i] eq $hitname) {
		for (my $j=$hithitstart[$i]-1; $j < $hithitend[$i]; $j++) {
		    $hit_hit_markup[$j]=1;
		}
	    }
	}
	
	my $linewidth = 60;    
	for (my $i=0; $i<@hitseq; $i++) {
	    if( $i != 0 && ($i % $linewidth) == 0 ) {
		$postpone_output.="<br>\n";
	    }
	    
	    $postpone_output .= "<span class=\"";
	    if( $hit_hit_markup[$i] == 1 && $hit_motif_markup[$i] == 1) {
		$postpone_output .= "seqhitmotif\">";
	    } elsif ( $hit_hit_markup[$i]==1 && $hit_motif_markup[$i] == 0) {
		$postpone_output .= "seqhit\">";
	    } elsif ( $hit_hit_markup[$i]==0 && $hit_motif_markup[$i] == 1) {
		$postpone_output .= "seqmotif\">";
	    } else {
		$postpone_output .= "sequence\">";
	    }
	    $postpone_output .=$hitseq[$i]."</span>";
	}

	$postpone_output .= $more_postponed_output;
    }
    $postpone_output .="</table>\n";

#    $output .= "<h3>$queryname hit and motif markup</h3>";
    
    my @seq= split(/ */,$seq);
    my @motif_markup = split(/ */,'0'x@seq);
    my @hit_markup = split(/ */,'0'x@seq);
#    $output .= "<br> There were ".scalar(@motifstart)." motifs and ".scalar(@hitstart)." hits.<br>\n";

    for (my $i=0; $i<@motifstart; $i++) {
	for (my $j=$motifstart[$i]-1; $j < $motifend[$i]; $j++) {
	    $motif_markup[$j]=1;	    
	}
    }

    for (my $i=0; $i<@hitstart; $i++) {
	for (my $j=$hitstart[$i]-1; $j < $hitend[$i]; $j++) {
	    $hit_markup[$j]=1;
	}
    }

    my $linewidth = 60;    
    for (my $i=0; $i<@seq; $i++) {
	if( $i != 0 && ($i % $linewidth) == 0 ) {
	    $output.="<br>\n";
	}

	$output .= "<span class=\"";
	if( $hit_markup[$i] == 1 && $motif_markup[$i] == 1) {
	    $output .= "seqhitmotif\">";
	} elsif ( $hit_markup[$i]==1 && $motif_markup[$i] == 0) {
	    $output .= "seqhit\">";
	} elsif ( $hit_markup[$i]==0 && $motif_markup[$i] == 1) {
	    $output .= "seqmotif\">";
	} else {
	    $output .= "sequence\">";
	}
	$output .=$seq[$i]."</span>";
    }
    $output .= "<br><br>Seqeunce markup legend: <span class=\"seqmotif\">MOTIF</span>, <span class=\"seqhit\">HIT</span> and <span class=\"seqhitmotif\">BOTH</span>.<br>\n";

    $output .= $postpone_output;

    return $output;
}


sub _linebreak {
    my $self =shift;
    my $stringref = shift;
    my $n = shift;
    my $breakstr = shift;

    my @string = split(/ */, $$stringref);

    my $outstring = "";
    for (my $i=0; $i < scalar(@string); $i++) {
#	$outstring .= $i;
	if( $i != 0 && ($i % $n) == 0 ) {	    
	    $outstring .= $breakstr;
	    $outstring .= $string[$i];
	} else { 
	    $outstring .= $string[$i];
	}
    }
   
    # join(" ", @string) 
    return $outstring;
}

sub _linkout_columns {

    my $self = shift;
    
    my $linkout_hash = shift;
    my $fields = shift;
    
    for my $pos (keys %{$linkout_hash}) {

	if (${$fields}[$pos] ne "") {
	    my $oldfield = ${$fields}[$pos];
	    ${$fields}[$pos] = ${$linkout_hash}{$pos};
	    ${$fields}[$pos] =~ s/linkPLACEholder/$oldfield/g;
	}
    }
}


sub _remove_nonvarying_fields {

    my $self = shift;

    my $unfold_trigger_fields = shift;    
    my $fields = shift;   
    my $oldfields = shift;

    my @unfold_trigger_fields = @{$unfold_trigger_fields};
#    my @fields = @{$fields};
    my @oldfields = @{$oldfields};

    my $fold=1;   
    foreach my $pos (0..@oldfields-1) {
	foreach my $unfold_pos (@unfold_trigger_fields) {
	    if ($pos == $unfold_pos && $oldfields[$pos] ne ${$fields}[$pos] ) {
		$fold=0;
	    }
	}
    }
    
    foreach my $pos (0..@oldfields-1) {
	if ($fold && $oldfields[$pos] eq ${$fields}[$pos]) {
	    ${$fields}[$pos] = "";
	}
    }
        
    return;
}

sub _alternate_color_element_join {
    my $self = shift;
    my $element = shift;
    my @in = @_;

    my $out ="";

    $out = "<$element class=\"even\">";

    my $count = 1;
    $out .= shift @in;
    foreach $alternating_color_tds (@in) {

	if($count%2==1) {
	    $class = "odd";
	} else {
	    $class = "even";
	}

	$out .= "</$element><$element class=\"$class\">".$alternating_color_tds;
	$count++;
    }

    $out .= "</$element>";

    return $out;
}


1;


#  LocalWords:  Outstring
