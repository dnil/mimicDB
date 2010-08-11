#!/usr/bin/perl -w

use DBI;

my $DEBUG = 1;

=head1 NAME

load_shannon_entropy.pl

=head1 AUTHOR

Daniel Nilsson, daniel.nilsson@izb.unibe.ch, daniel.nilsson@ki.se, daniel.k.nilsson@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2009, 2010 held by Daniel Nilsson. The package is realesed for use under the Perl Artistic License.

=head1 SYNOPSIS

USAGE: C<load_shannon_entropy.pl>

=head1 DESCRIPTION

Computes and uploads Shannon source entropy for the mimicDB hits.

=cut

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

my $dbh = DBI->connect('dbi:mysql:mygo', $mysqluser, $mysqlpwd) || die "Could not connect to database $DBI::errstr";

my $name = "";
my $named_seq_id = 0;
my $identifier = "";
my ($seq_start,$seq_end,$score,$evalue) = (0,0,0,0);

my %description;

my $sth=$dbh->prepare("SELECT mimic_hit.id AS mimic_hit_id, mimic_hit.query_id AS query_id, mimic_hit.query_start AS query_start, mimic_hit.query_end AS query_end, mimic_hit.subject_id AS subject_id, mimic_hit.subject_start AS subject_start, mimic_hit.subject_end AS subject_end, query_mimic_sequence_seq.seq AS query_seq, subject_mimic_sequence_seq.seq AS subject_seq FROM mimic_hit INNER JOIN mimic_sequence_seq AS query_mimic_sequence_seq ON (query_mimic_sequence_seq.mimic_sequence_id=query_id) INNER JOIN mimic_sequence_seq AS subject_mimic_sequence_seq ON (subject_mimic_sequence_seq.mimic_sequence_id=subject_id);");
#select name from mimic_sequence ");
$sth->execute();

while (my $answer = $sth->fetchrow_hashref()) {
#    print join (" ", @answer),"\n";

    my $query_seq = $answer->{'query_seq'};
    my $query_start = $answer->{'query_start'};
    my $query_pep_len = $answer->{'query_end'} - $query_start + 1;
    my $query_pep = substr($query_seq, $query_start, $query_pep_len);
    
    my $query_H = shannon_source_entropy( $query_pep );

    my $subject_seq = $answer->{'subject_seq'};
    my $subject_start = $answer->{'subject_start'};
    my $subject_pep_len = $answer->{'subject_end'} - $subject_start + 1;
    my $subject_pep = substr($subject_seq, $subject_start, $subject_pep_len);
    
    my $subject_H = shannon_source_entropy( $subject_pep );

    my $mimic_hit_id = $answer->{'mimic_hit_id'};
    
    my $insertq="insert into mimic_hit_entropy (mimic_hit_id, query_H, subject_H) VALUES($mimic_hit_id, $query_H, $subject_H);";
#    $DEBUG && print "DEBUG: $insertq\n";
    $dbh->do($insertq);
}

sub shannon_source_entropy {

    my $seq = shift;

    my @residues=split(/ */,$seq);

    my %aa=();
    map { $aa{$_} = (exists($aa{$_}))?($aa{$_}+1):1 } @residues;

    my $aas=0;
    map { $aas+=$_ } values(%aa);

    my %p=();
    map { $p{$_} = $aa{$_}/$aas } keys(%aa);

    my $H=0;

    map { if (exists($p{$_}) && $p{$_}!=0) { $H -= $p{$_} * log($p{$_})/log(2) } } keys(%aa);

    return $H;

}
