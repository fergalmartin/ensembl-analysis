package Bio::EnsEMBL::Analysis::RunnableDB::lincRNAEvaluator;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Analysis::RunnableDB::lincRNAFinder; 
use Bio::EnsEMBL::Analysis::RunnableDB::BaseGeneBuild;
use Bio::EnsEMBL::Analysis::Config::GeneBuild::lincRNAEvaluator; 
use Bio::EnsEMBL::Analysis::Runnable::lincRNAEvaluator; 
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Argument qw (rearrange); 
use Bio::EnsEMBL::Analysis::RunnableDB; 
use Bio::EnsEMBL::Analysis::Tools::Logger;
use Bio::EnsEMBL::Analysis::Runnable::GeneBuilder;
use Bio::EnsEMBL::Analysis::Tools::GeneBuildUtils qw(id coord_string lies_inside_of_slice);
use Bio::EnsEMBL::Analysis::Tools::Algorithms::ClusterUtils;; 

@ISA = qw (
           Bio::EnsEMBL::Analysis::RunnableDB::BaseGeneBuild
           Bio::EnsEMBL::Analysis::RunnableDB
           );



=head2 new

  Arg [1]   : Bio::EnsEMBL::Analysis::RunnableDB::lincRNAEvaluator
  Function  : instatiates a lincRNAEvaluator object and reads and checks the config
  file
  Returntype: Bio::EnsEMBL::Analysis::RunnableDB::lincRNAEvaluator 
  Exceptions: 
  Example   : 

=cut



sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);  

  $self->read_and_check_config($LINCRNA_EVAL_CONFIG_BY_LOGIC);   
  return $self;
}



sub fetch_input{
  my ($self) = @_;
  #fetch sequence/slice 
  $self->query($self->fetch_sequence); 

  my $lincrna_genes = $self->get_genes_of_biotypes_by_db_hash_ref($self->LINCRNA_DB);
  
  my @single_transcript_lincrna_genes = @{$self->create_single_transcript_genes($lincrna_genes)}; 
  print scalar(@single_transcript_lincrna_genes) . " single_transcript genes\n" ;  

  # get ensembl human genes to validate and check overlap  
  
  my $validation_genes = $self->get_genes_of_biotypes_by_db_hash_ref($self->VALIDATION_DBS);  

  my $db = $self->get_dbadaptor($self->UPDATE_SOURCE_PROTEIN_CODING_DB);   
  my $update_analysis = $db->get_AnalysisAdaptor->fetch_by_logic_name($self->ENSEMBL_HAVANA_LOGIC_NAME);     
  
  unless ( defined $update_analysis && ref($update_analysis)=~m/Bio::EnsEMBL::Analysis/ ) {  
   throw ( " Analysis with logic_name " . $self->ENSEMBL_HAVANA_LOGIC_NAME . " can't be found in " . $db->dbname . "\@".$db->host . "\n" );
  }    

  $self->update_analysis($update_analysis); 

  my $runnable = Bio::EnsEMBL::Analysis::Runnable::lincRNAEvaluator->new(
          -query => $self->query,
          -analysis => $self->analysis,
          -linc_rna_genes => \@single_transcript_lincrna_genes , 
          -ensembl_genes => $validation_genes,  
          -ensembl_havana_analysis=> $update_analysis, 
           );
  $self->single_runnable($runnable); 
};


sub run {
  my ($self) = @_;  
  #$self->SUPER::run();
  $self->single_runnable->run();  # don't inherit as we don't want to collect all data ..

  #my @genes_to_ignore = @{$self->runnable->genes_to_ignore} ; 



  #my @result = @{$self->output} ;  
  #my (@genes_to_ignore, @genes_for_build,@clust_proctrans) ;  

  #my @genes_to_ignore = @{$self->genes_to_ignore} ; 
#  my @clust_proctrans = @{$self->runnable->clusters_with_processed_transcript};

  
#  for my $g ( @result ) {  
    #if ( $g->biotype=~m/clusters_with_prot_dom/ ) {
        #push @genes_to_ignore, $g;
#    } elsif ( $g->biotype=~m/clusters_proc_trans/ ) {
#        push @clust_proctrans, $g; 
    #} elsif ( $g->biotype=~m/clusters_w_ensembl/ ) {
    #    push @genes_to_ignore, $g; 
    #} elsif ( $g->biotype=~m/clusters_with_diff_biotypes/ ) {
    #    push @genes_to_ignore, $g; 
    #} elsif ( $g->biotype=~m/same_as_ensembl/ ) {
    #    push @genes_to_ignore, $g; 
#    } else { 
#        print "adding gene for genebiulder run : " . $g->biotype . "\n" ; 
#        push @genes_for_build, $g; # self->runnable->unclustered_ncrnas
#   } 
#  } 

#  print " got " .@genes_for_build . " gens for genebuilder\n" ;  
#  print " got " .@genes_to_ignore. "  genes to ignore\n"; 

  # we only want genes of certain biotype first 



  # I hacked GeneBuilderos i don't need to filter translations for now.    
  
  # NOW filter out genes which don't have translations   
 # my ( $g_with_transl, $no_transl_g ) = @{ filter_genes_by_translation(\@genes_for_build) } ;  

 # for ( @$no_transl_g ) {  
 #    $_->biotype($_->biotype()."_nt"); 
 # }   
  # cluster them again and vs the other set and only use the oness which are unclustered  
 # my %types_hash = %{ make_types_hash($g_with_transl, $no_transl_g,  'TRANSLATION','NO_TRANSL')} ;
  #my ($step1_clusters, $step1_unclustered) = cluster_Genes( [@$g_with_transl, @$no_transl_g] , \%types_hash ) ;

  # I am looking for gene which do not cluster with any translation-genes 
  #my @unclust_no_translation = (  
  #                              @{get_oneway_clustering_genes_of_set($step1_clusters,"NO_TRANSL")},
  #                              @{get_oneway_clustering_genes_of_set($step1_unclustered,"NO_TRANSL")}
  #                             );
  #for ( @unclust_no_translation ) {  
  #   $_->biotype($_->biotype()."_uncl"); 
  #}   
# for ( @genes_for_build) {  
   #print scalar(@{$_->get_all_Transcripts}) . " transcripts \n";
#  }  

  my @output_clustered;  

  #
  # First genebuilder run with unclustered lincRNAs 
  #
  print "Got " . scalar(@{$self->single_runnable->unclustered_ncrnas}). " unclustered lincRNAs for Genebuilder \n" ;  

  my $gb = Bio::EnsEMBL::Analysis::Runnable::GeneBuilder->new(
          -query => $self->query,
          -analysis => $self->analysis,
          #-genes => $g_with_transl, 
          -genes => $self->single_runnable->unclustered_ncrnas, #  \@genes_for_build, 
          -output_biotype => $self->FINAL_OUTPUT_BIOTYPE, 
          -max_transcripts_per_cluster => 3, 
          -min_short_intron_len => 1,
          -max_short_intron_len => 15,
          -blessed_biotypes => {} , 
         );
   $gb->run();  
   my @output_genes = @{$gb->output()};
   for my $og ( @output_genes ) {   
     for my $ot ( @{ $og->get_all_Transcripts } ) {  
       $ot->biotype($self->FINAL_OUTPUT_BIOTYPE);
     }
   } 
   push @output_clustered, @output_genes ;  

   print " GB returned  " .@output_clustered . " unclustered genes for genebuilder run\n" ;   


  # 
  # second genebuilder run with lincRNAs which cluster with processed transcript. might change that and just update the analysis of the 
  # gene which cluster with processed transcript. 
  # 

  if ( $self->WRITE_NCRNAS_WHICH_CLUSTER_WITH_PROCESSED_TRANSCRIPTS == 1 ) { 
     print "Got " . scalar(@{$self->single_runnable->ncrna_clusters_with_processed_transcript}). 
      " lincRNAs for Genebuilder which cluster with processed transcript\n" ; 

     $gb = Bio::EnsEMBL::Analysis::Runnable::GeneBuilder->new(
            -query => $self->query,
            -analysis => $self->analysis,
            -genes => $self->single_runnable->ncrna_clusters_with_processed_transcript, # @clust_proctrans, 
            -output_biotype => "ncrna_clusters_with_processed_transcript", 
            -max_transcripts_per_cluster => 3, 
            -min_short_intron_len => 1,
            -max_short_intron_len => 15,
            -blessed_biotypes => {} , 
           );
     $gb->run(); 
     push @output_clustered, @{$gb->output()} ;   
   }
   print " GB returned  " .@output_clustered . " genes in total\n" ;  
   $self->genes_to_write( \@output_clustered );
}


sub write_output{
  my ($self) = @_; 

  # update genes in the source db which cluster with processed_transcripts 
  my @genes_to_update = @{ $self->single_runnable->genes_to_update} ;   
  print " have " .scalar(@genes_to_update ) . " genes_to_update \n" ;  

  if ( $self->PERFORM_UPDATES_ON_SOURCE_PROTEIN_CODING_DB == 1  ) { 
    my $ga = $self->get_dbadaptor($self->UPDATE_SOURCE_PROTEIN_CODING_DB)->get_GeneAdaptor();
    
    for my $ug ( @genes_to_update ) {      
      # before we update the analysis we check if the analysis of gene processed_transcript
      # is 'havana' ..  
      
      if ( $ug->analysis->logic_name =~m/$self->havana_old_analysis/ ) { 
          $ug->analysis($self->update_analysis); 
          $ga->update($ug);  
          print "updated gene " . $ug->dbID . "\n";  
      }else {  
        warning("not updating gene " . $ug->biotype . " with dbID " . $ug->dbID . " as it has the wrong analysis " 
        . $ug->analysis->logic_name . " ( to update, it should be of analysis " . $self->HAVANA_LOGIC_NAME . ")"); 
      } 
    }
  }


  my $lincrna_ga = $self->output_db->get_GeneAdaptor;

  my @genes_to_write = @{$self->genes_to_write}; 

  if ( $self->WRITE_REJECTED_NCRNAS == 1 ) {   
    logger_info("Writing rejected genes\n"); 
    print "mutliple bt " . scalar(@{$self->single_runnable->ncrna_clusters_with_multiple_biotypes}) . " genes \n";
    print "protein dom " . scalar(@{$self->single_runnable->ncrna_clusters_with_protein_domain}) . " genes \n";
    push @genes_to_write, @{$self->single_runnable->ncrna_clusters_with_multiple_biotypes}; 
    push @genes_to_write, @{$self->single_runnable->ncrna_clusters_with_protein_domain};
  }  

  logger_info("Have ".@genes_to_write." genes to write in total");  

  my $sucessful_count = 0 ; 
  foreach my $gene(@genes_to_write){  
    for ( @{$gene->get_all_Transcripts} ) {  
       print "$_ : ".$_->seq_region_start . " " . $_->biotype . "\n"; 
    }
    $gene->status(undef); 
    $gene->analysis($self->analysis);   
    eval{
      $lincrna_ga->store($gene);
    };
    if($@){
      warning("Failed to write gene ".id($gene)." ".coord_string($gene)." $@");
    }else{
      $sucessful_count++;
      logger_info("STORED LINCRNA GENE ".$gene->dbID);
    }
  } 
     print $sucessful_count ." genes written to " . $self->output_db->dbname . " @ ".
     $self->output_db->host . "\n"  ;   

  if($sucessful_count != @genes_to_write ) { 
    throw("Failed to write some genes");
  }
}

sub output_db{
  my ($self, $db) = @_; 

  if(defined $db && ref($db)=~m/Bio::EnsEMBL::DBSQL/ ){
    $self->{output_db} = $db;
  }
  if(!$self->{output_db}){
    $db = $self->get_dbadaptor($self->FINAL_OUTPUT_DB); 
    $self->{output_db} = $db; 
  }
  return $self->{output_db};
}



sub get_gene_sets {
  my ($self) = @_;
  my @genes; 

   my %sets_to_cluster = %{$self->CLUSTERING_INPUT_GENES};  

    if ( keys %sets_to_cluster != 2 ) { 
        throw ("you should only have 2 sets to cluster against - you can't cluster against more sets \n" ); 
    } 
 
  # check if hash-key name is correct : 
  unless ( exists $sets_to_cluster{"SET_1_CDNA"} && 
            exists $sets_to_cluster{"SET_2_PROT"}) {  
   throw( " configuration error - I expect to get 2 sets of genes with names \"SET_1_CDNA\" and \"SET_2_PROT\" - check your config - you can't change these names!!!! \n" ) ; 
  }  
 
  foreach my $set ( keys %sets_to_cluster) { 

    my %this_set = %{$sets_to_cluster{$set}};      

    my @genes_in_set; 
    foreach my $database_db_name ( keys ( %this_set)) {  
       my $set_db = $self->get_dbadaptor($database_db_name);
       #$set_db->disconnect_when_inactive(1);  
       my $slice = $self->fetch_sequence($self->input_id, $set_db);  
       my @biotypes = @{$this_set{$database_db_name}}; 
       for my $biotype  ( @biotypes ) { 
          my $genes = $slice->get_all_Genes_by_type($biotype,undef,1);
          if ( @$genes == 0 ) {  
            warning("No genes of biotype $biotype found in $set_db\n"); 
          } 
          print "Retrieved ".@$genes." of type ".$biotype."\n";
          push @genes_in_set, @$genes; 
      }  
    } 
    my @single_transcript_genes = @{$self->create_single_transcript_genes(\@genes_in_set)};
   $self->all_gene_sets($set,\@genes_in_set); 
  }   
}


sub create_single_transcript_genes{
  my ($self, $genes) = @_; 

  print "Creating single_transcript genes ....\n" ;
  my @single_transcript_genes; 

 GENE:foreach my $gene(@$genes){ 
    my @tr = @{$gene->get_all_Transcripts}; 
    if ( @tr == 1 ) {  
      push @single_transcript_genes, $gene ; 
    } else { 
      foreach my $transcript(@tr ) { 
        my $ng = Bio::EnsEMBL::Gene->new();  
        $ng->add_Transcript($transcript); 
        push @single_transcript_genes, $ng ; 
      }
    }
  }
  return \@single_transcript_genes; 
}

#CONFIG METHODS


=head2 read_and_check_config

  Arg [1]   : Bio::EnsEMBL::Analysis::RunnableDB::GeneBuilder
  Arg [2]   : hashref from config file
  Function  : call the superclass method to set all the varibles and carry
  out some sanity checking
  Returntype: N/A
  Exceptions: throws if certain variables arent set properlu
  Example   : 

=cut

sub read_and_check_config{
  my ($self, $hash) = @_;
  $self->SUPER::read_and_check_config($hash); 

  #######
  #CHECKS
  ####### 
  foreach my $var(qw(LINCRNA_DB FINAL_OUTPUT_DB FINAL_OUTPUT_BIOTYPE VALIDATION_DBS WRITE_REJECTED_NCRNAS )){ 
    throw("RunnableDB::lincRNAEvaluator $var config variable is not defined") if (!defined $self->$var ) ; 
  }
}


=head2 CONFIG_ACCESSOR_METHODS

  Arg [1]   : Bio::EnsEMBL::Analysis::RunnableDB::GeneBuilder
  Arg [2]   : Varies, tends to be boolean, a string, a arrayref or a hashref
  Function  : Getter/Setter for config variables
  Returntype: again varies
  Exceptions: 
  Example   : 

=cut

#Note the function of these variables is better described in the
#config file itself Bio::EnsEMBL::Analysis::Config::GeneBuild::GeneBuilder

sub FINAL_OUTPUT_DB{
  my ($self, $arg) = @_;
  if(defined $arg){
    $self->{'FINAL_OUTPUT_DB'} = $arg;
  }
  return $self->{'FINAL_OUTPUT_DB'};
}  


sub FINAL_OUTPUT_BIOTYPE{
  my ($self, $arg) = @_;
  if(defined $arg){
    $self->{'FINAL_OUTPUT_BIOTYPE'} = $arg;
  }
  return $self->{'FINAL_OUTPUT_BIOTYPE'};
}  


sub VALIDATION_DBS{
  my ($self, $arg) = @_;
  if(defined $arg){
    $self->{'VALIDATION_DBS'} = $arg;
  }
  return $self->{'VALIDATION_DBS'};
} 

sub WRITE_REJECTED_NCRNAS{
  my ($self, $arg) = @_;
  if(defined $arg){
    $self->{'WRITE_REJECTED_NCRNAS'} = $arg;
  }
  return $self->{'WRITE_REJECTED_NCRNAS'};
}  


sub UPDATE_SOURCE_PROTEIN_CODING_DB{
  my ($self, $arg) = @_;
  if(defined $arg){
    $self->{'UPDATE_SOURCE_PROTEIN_CODING_DB'} = $arg;
  }
  return $self->{'UPDATE_SOURCE_PROTEIN_CODING_DB'};
} 

sub WRITE_NCRNAS_WHICH_CLUSTER_WITH_PROCESSED_TRANSCRIPTS{
  my ($self, $arg) = @_;
  if(defined $arg){
    $self->{'WRITE_NCRNAS_WHICH_CLUSTER_WITH_PROCESSED_TRANSCRIPTS'} = $arg;
  }
  return $self->{'WRITE_NCRNAS_WHICH_CLUSTER_WITH_PROCESSED_TRANSCRIPTS'};
} 

sub PERFORM_UPDATES_ON_SOURCE_PROTEIN_CODING_DB{
  my ($self, $arg) = @_;
  if(defined $arg){
    $self->{'PERFORM_UPDATES_ON_SOURCE_PROTEIN_CODING_DB'} = $arg;
  }
  return $self->{'PERFORM_UPDATES_ON_SOURCE_PROTEIN_CODING_DB'};
} 


sub LINCRNA_DB{
  my ($self, $arg) = @_;
  if(defined $arg){
    $self->{'LINCRNA_DB'} = $arg;
  }
  return $self->{'LINCRNA_DB'};
}  

sub ENSEMBL_HAVANA_LOGIC_NAME{
  my ($self, $arg) = @_;
  if(defined $arg){
    $self->{'ENSEMBL_HAVANA_LOGIC_NAME'} = $arg;
  }
  return $self->{'ENSEMBL_HAVANA_LOGIC_NAME'};
} 


sub HAVANA_LOGIC_NAME{
  my ($self, $arg) = @_;
  if(defined $arg){
    $self->{'HAVANA_LOGIC_NAME'} = $arg;
  }
  return $self->{'HAVANA_LOGIC_NAME'};
} 


sub filter_genes_by_translation{ 
  my ($aref) = @_ ;   

  my (@g_with_transl, @no_translation ) ;  

  for my $g ( @$aref ) { 
    my @t = @{ $g->get_all_Transcripts};   
    if (scalar(@t) > 1 ) { 
      throw("more than one transcript " )   ; 
    } 
    for ( @t ) {  
       if(  $_->translation ) {  
         push @g_with_transl , $g; 
       } else {  
         push @no_translation, $g ; 
       } 
     } 
  }  
  return [\@g_with_transl,\@no_translation];
 } 


use vars '$AUTOLOAD';
sub AUTOLOAD {
 my ($self,$val) = @_;
 (my $routine_name=$AUTOLOAD)=~s/.*:://; #trim package name
 $self->{$routine_name}=$val if $val ;
 return $self->{$routine_name} ;
}
sub DESTROY {} # required due to AUTOLOAD




1;