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

Bio::EnsEMBL::Analysis::RunnableDB::RepeatMasker - 

=head1 SYNOPSIS

  my $repeat_masker = Bio::EnsEMBL::Analysis::RunnableDB::RepeatMasker->
  new(
      -input_id => 'contig::AL805961.22.1.166258:1:166258:1',
      -db => $db,
      -analysis => $analysis,
     );
  $repeat_masker->fetch_input;
  $repeat_masker->run;
  $repeat_masker->write_output;

=head1 DESCRIPTION

This module provides an interface between the ensembl database and
the Runnable RepeatMasker which wraps the program RepeatMasker

This module can fetch appropriate input from the database
pass it to the runnable then write the results back to the database
in the repeat_feature and repeat_consensus tables 

=head1 METHODS

=cut

# $Source: /tmp/ENSCOPY-ENSEMBL-ANALYSIS/modules/Bio/EnsEMBL/Analysis/RunnableDB/RepeatMasker.pm,v $
# $Revision: 1.7 $
package Bio::EnsEMBL::Analysis::RunnableDB::RepeatMasker;

use strict;
use warnings;

use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Analysis::Runnable::RepeatMasker;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Analysis::RunnableDB);



=head2 fetch_input

  Arg [1]   : Bio::EnsEMBL::Analysis::RunnableDB::RepeatMasker
  Function  : fetch data out of database and create runnable
  Returntype: 1
  Exceptions: none
  Example   : 

=cut



sub fetch_input{
  my ($self) = @_;
  my $slice = $self->fetch_sequence;
  $self->query($slice);
  my %parameters;
  if($self->parameters_hash){
    %parameters = %{$self->parameters_hash};
  }
  my $runnable = Bio::EnsEMBL::Analysis::Runnable::RepeatMasker->new
    (
     -query => $self->query,
     -program => $self->analysis->program_file,
     -analysis => $self->analysis,
     %parameters,
    );
  $self->runnable($runnable);
  return 1;
}


=head2 get_adaptor

  Arg [1]   : Bio::EnsEMBL::Analysis::RunnableDB::RepeatMasker
  Function  : get repeatfeature adaptor
  Returntype: Bio::EnsEMBL::DBSQL::RepeatFeatureAdaptor
  Exceptions: none
  Example   : 

=cut


sub get_adaptor{
  my ($self) = @_;
  return $self->db->get_RepeatFeatureAdaptor;
}


1;
