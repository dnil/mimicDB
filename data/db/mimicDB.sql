--
-- mimicDB - mySQL db modification script
-- Daniel Nilsson, 2009-2010
--
-- Released under the Perl Artistic License.
--
-- The db schema is an add-on to the GeneOntology database.
-- See http://www.geneontology.org/ for details.
--

create table mimic_sequence ( id integer AUTO_INCREMENT not null PRIMARY KEY, species_id integer, foreign key (species_id) references species(id), name varchar(255) not null, description varchar(255), UNIQUE (species_id, name) );

create table mimic_sequence_with_go_association ( mimic_sequence_id integer, foreign key(mimic_sequence_id) references mimic_sequence(id), gene_product_id integer, foreign key(gene_product_id) references gene_product(id) );

create table mimic_hit ( id integer AUTO_INCREMENT not null PRIMARY KEY, query_id integer, foreign key (query_id) references mimic_sequence(id), query_start integer, query_end integer, subject_id integer, foreign key (subject_id) references mimic_sequence(id), subject_start integer, subject_end integer, score decimal, identities integer );

create table mimic_sequence_seq ( id integer AUTO_INCREMENT not null PRIMARY KEY, mimic_sequence_id integer, foreign key (mimic_sequence_id) references mimic_sequence(id), seq_len integer, seq text ); 

create table mimic_sequence_motif ( id integer AUTO_INCREMENT not null PRIMARY KEY, mimic_sequence_id integer, foreign key (mimic_sequence_id) references mimic_sequence(id), seq_start integer, seq_end integer, type varchar(8), eval float, score float, identifier varchar(55), description varchar(128) );

create table mimic_hit_entropy ( id integer AUTO_INCREMENT not null PRIMARY KEY, mimic_hit_id integer, foreign key (mimic_hit_id) references mimic_hit(id), query_H float, subject_H float);

create fulltext index termname on term (name);

-- How about indexes for mimic_sequence.description, query_mimic_sequence.description, query_mimic_sequence.name, mimic_sequence.name, (gene_product.symbol, gene_product.full_name)? OK?

CREATE USER 'mygo'@'localhost' IDENTIFIED BY 'm3g0_fo0';
GRANT INSERT,UPDATE,DELETE,SELECT ON mygo.* TO 'mygo'@'localhost' IDENTIFIED BY 'm3g0_fo0';

CREATE USER 'mimicdb'@'localhost' IDENTIFIED BY 'w3bbpublIC';
GRANT SELECT ON mygo.* TO 'mimicdb'@'localhost' IDENTIFIED BY 'w3bbpublIC';
