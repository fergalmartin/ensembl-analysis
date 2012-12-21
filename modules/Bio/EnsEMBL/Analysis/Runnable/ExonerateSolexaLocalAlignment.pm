=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Analysis::Runnable::ExonerateSolexaLocalAlignment - 

=head1 SYNOPSIS

  my $runnable = 
    Bio::EnsEMBL::Analysis::Runnable::ExonerateSolexaLocalAlignment->new(
     -query_seqs     => \@q_seqs,
     -query_type     => 'dna',
     -target_seqs    => \@t_seqs,
     -options        => $options,
    );

 $runnable->run;
 my @results = $runnable->output;
 
=head1 DESCRIPTION

This module handles a specific use of the Exonerate (G. Slater) program, 
to realign RNA-Seq reads with a splice model and a short word length over
a small slice of DNA

=head1 METHODS

=cut

# $Source: /tmp/ENSCOPY-ENSEMBL-ANALYSIS/modules/Bio/EnsEMBL/Analysis/Runnable/ExonerateSolexaLocalAlignment.pm,v $
# $Revision: 1.4 $
package Bio::EnsEMBL::Analysis::Runnable::ExonerateSolexaLocalAlignment;

use warnings ;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::Analysis::Runnable::ExonerateAlignFeature;
use Bio::EnsEMBL::Pipeline::SeqFetcher::OBDAIndexSeqFetcher;
use Bio::EnsEMBL::Analysis::Tools::Utilities;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );

@ISA = qw(Bio::EnsEMBL::Analysis::Runnable::ExonerateAlignFeature);

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  my ( $reads, $genomic ) =
    rearrange( [qw(READS GENOMIC)],@args );
  $self->reads($reads);
  $self->genomic($genomic); 
  return $self;
}

=head2 run

  Args       : none
  Description: Fetches reads from an ODBC index based on read name
               Runs ExonerateSolexa using these reads against a slice of DNA
  Returntype : scalar

=cut 

sub run {
  my ($self) = @_;
  my $genomic = $self->genomic;
  my @reads = @{$self->reads};
  my %reads_by_analysis;
  my @fasta;
  # group the reads by analayis
  while ( scalar(@reads) > 0 ) {
    my $read = pop(@reads);
    push @{$reads_by_analysis{$read->analysis->logic_name}}, $read;
  }
  # pull the fasta sequences out of the indexed files
  my $config = read_config("Bio::EnsEMBL::Analysis::Config::ExonerateAlignFeature");
  foreach my $analysis ( keys %reads_by_analysis ) {
    my @reads = @{$reads_by_analysis{$analysis}};
    print "Got " . scalar(@reads) . " reads of type $analysis\n";
    # what is the location of the chunks directory for these reads?
    # read the exonerate align feature config file and get the 
    # location of the chunks 
    my $queryseqs = $config->{"EXONERATE_ALIGNFEAT_CONFIG"}->{uc($analysis)}{"QUERYSEQS"};
    my $seqfetcher =Bio::EnsEMBL::Pipeline::SeqFetcher::OBDAIndexSeqFetcher->new
      ( -db => ["$queryseqs/../index"],
	-format => 'fasta'
      );
    # sort by name?
    @reads = sort { $a->hseqname cmp $b->hseqname } @reads;
    my $count;
    foreach my $read ( @reads ) {
      # fetch fa
      my $name = $read->hseqname;
      if ( $name =~ /(\S+):(a$|b$|.*3p)/ ) {
	$name = $1;
      }
      
      my $seq = $seqfetcher->get_Seq_by_acc($name);
      # need to split the sequences in half to get the a and b read
      my $length = length($seq->seq) / 2;
      my $seqa = Bio::Seq->new ( -seq        => $seq->seq,
				 -display_id => $name,
			       );
      my $seqb =   Bio::Seq->new ( -seq        => $seq->seq,
				 -display_id => $name,
			       );
      $seqa->display_id($name .":a");
      $seqa->seq(substr($seq->seq,0,$length));
      $seqb->display_id($name .":b");
      $seqb->seq(substr($seq->seq,$length,$length));
      push @fasta,$seqa;
      push @fasta,$seqb;
      
      $count++;
    }
  }
  # make the file to do the analysis with
  my $query_seq = $self->create_filename("ELA_reads","fa");
  my $genomic_seq = $self->create_filename("ELA_genomic","fa");
  $self->write_seq_file(\@fasta,$query_seq);
  $self->write_seq_file($genomic,$genomic_seq);
  $self->files_to_delete($query_seq);
  $self->files_to_delete($genomic_seq);
  $self->query_file($query_seq);
  $self->target_file($genomic_seq);
  $self->SUPER::run;
  $self->delete_files;
}



sub reads {
  my ($self, $values) = @_;
  
  if ($values) {
    $self->{_reads} = $values;
  }
  return $self->{_reads};
}


sub genomic {
  my ($self, $values) = @_;
  
  if ($values) {
    $self->{_genomic} = $values;
  }
  return $self->{_genomic};
}

