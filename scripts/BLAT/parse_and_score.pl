#!/usr/local/ensembl/bin/perl -w


use strict;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Root;
use Bio::EnsEMBL::Exon;
use Bio::EnsEMBL::Translation;
#use Bio::EnsEMBL::TranscriptI;
use Bio::Tools::CodonTable;
#use Bio::EnsEMBL::Compara::Matrix::Generic;
#use Bio::EnsEMBL::Compara::Matrix::IO;
use Getopt::Long;
use Bio::EnsEMBL::Utils::Exception;



######rewrite so that it dosn't link to compara just core as dosn't actually use compara

my $usage="
$0 [-help]
  -F   filename    (Fr2.229.err)
  -O   output file name   (Fr2HS34_chr22 for gff line data)
  -D   diff between aligns to be included as 1 (15000)
  -S1   species 1 (Query)  (Fr2)
  -S2   species 2 (target)  (Hs34)
  -CF   conf_file    ~/.Registry.conf
  -M    matrix_file    blosum62 (optional)
  -R  reverse output order(tbx file for query rather than target)  0 or 1 1=reverse (optional)
  ";
    
 


my ($file, $outfile, $track, $data ,$species1, $species2, $diff, $matrix_file, $reverse_output, $help);

my $minus_count=0;
my $conf_file;
my @new_features=();
my $matrix;
my %prev;
my $i=0;
my @all=();
my @sorted=();


unless (scalar @ARGV) {print $usage; exit 0;}

GetOptions(  'help'    =>  \$help, 
    'F=s'    =>  \$file,
    'O=s'    =>  \$outfile, 
    'S1=s'    =>  \$species1,
    'S2=s'    =>  \$species2, 
    'D=i'    =>  \$diff,
    'CF=s'    =>  \$conf_file, 
    'M=s'    =>  \$matrix_file,
    'R=i'    =>  \$reverse_output);
    
if ($help){print $usage; exit 0;}


##
## Configure the Bio::EnsEMBL::Registry
## Uses $conf_file if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses
## ~/.ensembl_init if all the previous fail.
##
Bio::EnsEMBL::Registry->load_all($conf_file);

my $db = "Bio::EnsEMBL::Registry";


#my $t3stats=$outfile.".t3";
#$track=$outfile."_TransBLAT";
$data=$outfile.".data";
#$outfile=$outfile.".tbx";

if ($reverse_output){print "*********$reverse_output*********\n\n";}


my $sliceadaptor1 = $db->get_adaptor($species1, 'core', 'Slice') or die "can't get sliceA1\n";
my $sliceadaptor2 = $db->get_adaptor($species2, 'core', 'Slice') or die "can't get sliceA2\n";

my $sps1 = $sliceadaptor1->db->get_MetaContainer->get_Species->binomial;
my $sps2 = $sliceadaptor2->db->get_MetaContainer->get_Species->binomial;
$sps1 =~ s/^(\w)[\w]+ (.).+/$1$2/;
$sps2 =~ s/^(\w)[\w]+ (.).+/$1$2/;

###########Get matrix
if ($matrix_file){
#my $mp = new Bio::EnsEMBL::Compara::Matrix::IO (-format => 'scoring',
#            -file => $matrix_file);
#$matrix = $mp->next_matrix;
  $matrix = get_matrix_from_pam_file($matrix_file);
}
  open (FILE, $file) or die  "can't open $file: $!";
  #open (OUT,  ">$outfile") or die "can't open $outfile: $!";
  open (DATA, ">$data") or die "can't open $data: $!";
  #open (TSTATS, ">$t3stats") or die "can't open $t3stats: $!";
  #print TSTATS "sps1\tchr1\tQ_start\tQ_end\tQ_strand\tsps2\tchr2\tT_start\tT_end\tT_strand\tscore\tident\tposit\tcigar\tt0 t1 t2\tbase3\tlen\tsum_len\n"; 
    
  #print OUT "track name=$track description=\"BLAT of $sps1 with $sps2(GFF)\" useScore=1 color=333300\n";
  #print DATA "no(group)\tsps1\tchr1\tprog\tfeat\tQ_start\tQ_end\tQ_strand\tsps2\tchr2\tT_start\tT_end\tT_strand\tscore\tident\tposit\tcigar\n";

  LINE:while (my $line=<FILE>)
    {
    
    chomp $line; 
    my @atrib=split /\t/,$line;
    
    
################################################################################################
## Need some sort of general reg expression here to cope with the weird honey bee groupings
##But Havn't managed to work one out therefore at present here is a hard coded hackaround
##
################################################################################################    
    
    unless ((defined($atrib[9])) && ($atrib[0] =~ /$sps1/) && ($atrib[4]-$atrib[3] >=15)){ next LINE;}
    my ($chr1, $chr1_2, $sp, $offset1, $seq_type1); my $chr2; my $offset2; my $seq_type2;
##    if ($sps1 =~/Am/){
##      ($sp, $chr1, $chr1_2, $offset1) = split /\./,$atrib[0];
###Am.chromosome:Group6.13.1485001 just for BEE
##      $chr1=~s/chromosome://;
##      $chr1=$chr1.".".$chr1_2;#just for BEE
##      }
##    elsif($sps1 =~/Cb/){
##      ($chr1_2, $chr1, $offset1) = split /\./,$atrib[0];
##      $chr1= "cb25.".$chr1;
##      $seq_type1="scaffold";
##      }
##    elsif($sps1 =~/Ag/){
##      ($chr1, $offset1) = split /\./,$atrib[0];
##      $chr1=~s/Ag2b//;
##      $seq_type1="chromosome";
##      }
##    elsif($sps1 =~/Fr/){
##      ($chr1, $offset1) = split /\./,$atrib[0];
##      $chr1=~s/FrChr_//;
##      $seq_type1="scaffold";
##      }
##    else{
      $atrib[0] =~/$sps1\.(\S+):(\S+)\.(\d+)$/; #use for rest
      $seq_type1= $1;
       $chr1 = $2;
      $offset1=$3;
##      }
        
#    $chr1=~s/$sps1//;
      
    $atrib[5] =~/$sps2\.(\S+):(\S+)\.(\d+)$/;
    $seq_type2=$1;
     $chr2 = $2;
    $offset2=$3;
       
    
  
  
    
    
    
    
    if($chr2=~/\.\D+:(\S+)$/){
      $chr2=$1; 
    #print STDERR " $chr2, $offset2\n";
      }
    
    $offset1--; $offset2--;
    my $Qstart=$offset1+$atrib[3];
    my $Qend=$offset1+$atrib[4];
    my $Hstart=$offset2+$atrib[6];
    my $Hend=$offset2+$atrib[7];
    
    #print STDERR " $sps1: chr1:$chr1\t$offset1\n $sps2: chr2:$chr2\t$offset2\n";

##########################################################################################################
#### Want to create/get a score, percent id, percent positive for each hsp rather 
#### than using that based on the PSL line.
#### NB both at amino acid and DNA level. Then sort the hsps according to aa_score, 
#### aa_percent_positive etc using dna only as a fall back if the aa score etc is the same for two seqs
####
#### NB this involves recreating both the DNA and aa alignments -- and using ???? to get score etc
####
#### Want to base the score on both id and BLOSUM matrices to see which is best -- ???stop codons??? To match or not to match???
################################################################################################################
#####CREATE SCORE and IDENT and POSIT 
my $Qst=$atrib[11]; if ($Qst eq '+'){$Qst= 1;}else {$Qst='-1';} 
my $Hst=$atrib[10]; if ($Hst eq '+'){$Hst= 1;}else {$Hst='-1';}

#print STDERR "Qst: $Qst\n";
#print STDERR "Hst: $Hst\n";


##############################################################################################
##should move the chromosome check to here to reduce the memory requirement 
##-- only a chromosome and scaffolds worth would be need to be held in memory
################################################################################################









  my $sliceQ = $sliceadaptor1->fetch_by_region('toplevel', $chr1, $Qstart, $Qend, $Qst);
  throw("Cannot get toplevel seq_region $chr1, $Qstart, $Qend, $Qst") if (!$sliceQ);
  my $sliceT = $sliceadaptor2->fetch_by_region('toplevel', $chr2, $Hstart, $Hend, $Hst);
  throw("Cannot get toplevel seq_region $chr2, $Hstart, $Hend, $Hst") if (!$sliceT);

  my $Qseq=$sliceQ->seq;
  my $Tseq=$sliceT->seq;

my @Qs=split //,$Qseq;
my @Ts=split //,$Tseq;

my$Qid=$sps1.".".$chr1.".".$Qstart.".".$Qend.".".$chr2;
my $Q_Transseq=Bio::Seq->new( -seq => $Qseq,
           -moltype => "dna",
         -alphabet => 'dna',
         -id =>$Qid);
my$Tid=$sps2.".".$chr2.".".$Hstart.".".$Hend.".".$chr1;
my $T_Transseq=Bio::Seq->new( -seq => $Tseq,
           -moltype => "dna",
         -alphabet => 'dna',
         -id =>$Tid);
         
my $Q_aa=$Q_Transseq->translate->seq;
my $T_aa=$T_Transseq->translate->seq;
my $t0=0; my $t1=0; my $t2=0;
my $base=0;

for (my $i=0; $i<scalar(@Qs); $i++){
  unless ($Qs[$i] eq $Ts[$i]){
      if ($base%3==0){
        $t0++;
        }
      elsif($base%3==1){
        $t1++;
        }
      else {
        $t2++;
        }

      }
      $base++;
    }



#print STDERR "$Qseq\n$Tseq\n";
#print STDERR "$Q_aa\n$T_aa\n";

my $len  = ($Hend-$Hstart)+1; #No gaps therefore same length for both         
my $score=0; #my $id=0;

my @Qaa=split//, $Q_aa;
my @Taa=split//, $T_aa;

#print STDERR "len: $len\tscalar: ".scalar(@Taa)."\n"; 
my $aa_len=int($len/3);
#if ($matrix_file){         
#  for (my $i=0; $i<$aa_len; $i++){
#    $score += $matrix->entry($Qaa[$i], $Taa[$i]);
#    $id++;
#    }
#  }
#else {
#  for (my $i=0; $i<$aa_len; $i++){
#  
#    if ($Qaa[$i] eq $Taa[$i]){
#      $score+=2;
#      $id++;
#      
#      }
#    else {############# no differentiation for stop codons as sticking to BLAT matrix
#      $score-=1;
#      }
#
#    }
#  
#  }
#    my ($i1, $i2, $i3);
#    $i1 = ($t1 or $t2)? $t0/(($t1+$t2)/2) : $t0;
#    $i2 = ($t0 or $t2)? $t1/(($t0+$t2)/2) : $t1;
#    $i3 = ($t0 or $t1)? $t2/(($t1+$t0)/2) : $t2;
#my @base3period=sort {$b<=>$a}($i1, $i2, $i3);  
#my $base3period= $base3period[0];
#my $sum_len=($t0+$t1+$t2)/$len;  

  my ($new_score, $id, $best_frame) = get_best_score_in_all_frames($Q_Transseq, $T_Transseq, $matrix);
  if ($best_frame > 2) {
    $Q_Transseq = $Q_Transseq->revcom;
    $Q_Transseq = $Q_Transseq->revcom;
    $Q_aa=$Q_Transseq->translate('', '', ($best_frame-3))->seq;
    $T_aa=$T_Transseq->translate('', '', ($best_frame-3))->seq;
  } else {
    $Q_aa=$Q_Transseq->translate('', '', $best_frame)->seq;
    $T_aa=$T_Transseq->translate('', '', $best_frame)->seq;
  }
  $score = $new_score;

  if ($score<=0){
    print STDERR " $score for $chr1, $Qstart, $Qend, $Qst, $chr2, $Hstart, $Hend, $Hst\n"; 
    print STDERR "$Q_aa;\n$T_aa\n";
    $minus_count++;
    $score=0;
    next LINE;
  }
         
    
  $all[$i] = {
        sps1  => $sps1,
        chr1   => $chr1,
        prog   => $atrib[1],
        feat   => $atrib[2],
        Q_start => $Qstart,
        Q_end   => $Qend,
        sps2  => $sps2,
        chr2   => $chr2,
        T_start  => $Hstart,
        T_end   => $Hend,
        score_PSL   => $atrib[8],
        score   => $score,
        pvalue  => $atrib[9],
        Q_strand  => $atrib[11],
        T_strand  => $atrib[10],
        Q_strand_no  => $Qst,
        T_strand_no  => $Hst,
        ident_old  => $atrib[12],
        ident  => int(($id/$aa_len)*100),
        posit  => $atrib[13],
        cigar  => $atrib[14],
        len  => $len,
        t0  => $t0,
        t1  => $t1,
        t2  => $t2,
#        sum_len  => $sum_len,
#        base3  => $base3period
      };
        
  $i++;#should start at 0 ##########Strands are the wrong way around
    
}#end of while file loop
    
    
    
    
  #need to sort array on Hstart first 
#NB I DO CHECK THAT THE Query ALIGNMENTS ARE ON DIFFERENT SCAFFOLDS -- NOT NEEDED FOR HS AS THEY ARE ALL ON ONE CHR!!!!!!! -- or just do a sort

##########################
##ok lets see what happens when we ignore strand and just go for the best scoring alignments?






#FIRST GROUP BY Query seq_region
my @sorteds=sort{$a->{chr2} cmp $b->{chr2} || $a->{chr1} cmp $b->{chr1} || $a->{T_start}<=>$b->{T_start} || $a->{T_end} <=> $b->{T_end} || $a->{Q_start} <=> $b->{Q_start} || $a->{Q_end} <=> $b->{Q_end}} @all;



###try adding in an extra or here with the target chr2 in it
my $prev_chr1; my $chr1=0; my @all_same;#e
my $prev_chr2; my $chr2=0; #e

my $lc=0;
CHR:foreach my $ali (@sorteds){ 
  $lc++;
  $chr1=$ali->{chr1};#e
  $chr2=$ali->{chr2};#e
  if ((defined($prev_chr1)) || (defined($prev_chr2))){#e
    #print STDERR $ali->{chr1}." $chr $prev_chr line 90 ".$ali->{T_start}." ".$ali->{Q_start}."\n";
      
      
      
    #next chr or end of file
    if (($prev_chr2 ne $chr2) || ($prev_chr2 ne $chr2) ||($lc==scalar @sorteds)){  #e
      
    #else{#do everything and start the next array afterwards
    #print STDERR scalar(@all_same)." GGGGG".$all_same[0]->{T_start}." ".$ali->{Q_start}."\n";
    
    my @sorted_hsps=sort{$a->{chr2} cmp $b->{chr2} || $a->{chr1} cmp $b->{chr1} || $a->{T_start}<=>$b->{T_start} || $a->{T_end} <=> $b->{T_end} || $a->{Q_start} <=> $b->{Q_start} || $a->{Q_end} <=> $b->{Q_end} } @all_same;
    #my @sorted_hsps=sort{$a->{T_start} <=> $b->{T_start} } @all_same;
        
my $A=0; my $qsdiff=0; my $qediff=0; my $ssdiff=0; my $sediff=0; my $compare;
my @parsed_hsps=@sorted_hsps;  
#my @kept_hsps='';#just keep the compare each time




my @features;

  
OVERLAP:foreach my $align (@sorted_hsps){###Need to redo this as a sub

      unless ($A==0){

        if (($align->{T_start} <= $compare->{T_end}) && ((($align->{Q_start} <= $compare->{Q_end}) && ($align->{Q_start} >= $compare->{Q_start})) || (($align->{Q_start} <= $compare->{Q_start}) && ($align->{Q_end} >= $compare->{Q_start})))){
    
    #it overlaps -- on both q and s don't care if it only overlaps on one strand as may be repeat
#print STDERR "Overlap:$A \n";
      if (($align->{Q_strand} eq $compare->{Q_strand}) && ($align->{T_strand} eq $compare->{T_strand})){
#same strand - do they extend each other? keep both otherwise keep higher score
          
#calculate the diff at each end and see if this is greater than eg 2aa
        
        $qsdiff= $align->{Q_start} - $compare->{Q_start}; #should always be positive
        $qediff= $align->{Q_end} - $compare->{Q_end} ;#should be positive to be included 
             
        $ssdiff= $align->{T_start} - $compare->{T_start}; 
        $sediff= $align->{T_end} - $compare->{T_end} ;#should be positive to be included 
        
        if($align->{score} >= $compare->{score}) {
          unless(($ssdiff > 6) || ($sediff < -6)){
            #ditch $compare
            my $sp=splice @parsed_hsps, $A-1, 1;
#print STDERR "a-1: ".$compare->{score} ." ditch i-1". $sp->{score}." \n";
              $compare=$align; next OVERLAP;
             }
          else{#keep both as extend
            #push @kept_hsps, $compare;
            $compare=$align; $A++; next OVERLAP;
            }
          }
          
        elsif($align->{score} < $compare->{score}) {
          unless ($sediff > 6){
            #ditch align
            my $sp=splice @parsed_hsps, $A, 1;
#print STDERR "$qediff align: ".$align->{score}." ditch align". $sp->{score}." \n";
             next OVERLAP;
            }
          else{#keep both as extend
            #push @kept_hsps, $compare;
            $compare=$align; $A++; next OVERLAP;
            }
          }
        
#print STDERR "keep both same strand should never get here$A\n";        
          #push @kept_hsps, $compare;
          $compare=$align; $A++; next OVERLAP; 
            
        }
          
#######NB must remember to return only those hsps that pass this 
      else{#diff strand therfore just keep the one with the highest score 
      ####unless overlap is very small ie due to possible palindromic regulatory region etc
      #calc overlap 
        my $overlap=($compare->{T_end}-$align->{T_start});
        my $comp_P_overlap=$overlap/$compare->{len};
        my $align_P_overlap=$overlap/$align->{len};
        #if (($comp_P_overlap<=0.1) || ($align_P_overlap<=0.1)){
          #keep both
  #print STDERR "diff strand, small overlap- keep both $A\n";
          #push @kept_hsps, $compare;
          #$compare=$align; 
          #$A++;
          #next OVERLAP;
          #}
      
        if ($compare->{score} >= $align->{score}) {
          #ditch align
          my $sp=splice @parsed_hsps, $A, 1;
#print STDERR "align: ".$align->{score}." (".$compare->{score} ." ) splice align ". $sp->{score}." \n";
           next OVERLAP;
          }
        elsif ($compare->{score} < $align->{score}) {
          #ditch i-1
          my $sp=splice @parsed_hsps, $A-1, 1;
#print STDERR "a-1: ".$compare->{score} ." (".$align->{score}." ) splice i-1 ". $sp->{score}." \n";
           $compare=$align; next OVERLAP;
          }
        
        }
      }
    else{ 
#print STDERR "no overlap keep $A\n";    
          #push @kept_hsps, $compare;
      $compare=$align; $A++; next OVERLAP;#don't overlap --keep and use as next $align
      }
        }
  else{ 
    $compare=$align; 
#print STDERR "First pass a=$A;\n";
    $A++; #only used on first pass
    #do something????
    next OVERLAP;
    }
  
  }#end foreach/OVERLAP
  #print STDERR " end of overlap1 before push ". scalar(@features)."  ".scalar(@parsed_hsps)."\n";
  
   push (@features, @parsed_hsps);#  
#########################################
   #same again but sorted by the other species.
#########################################
#########################################
my @new_sorted_hsps=sort{$a->{Q_start}<=>$b->{Q_start} || $a->{T_start} <=> $b->{T_start}} @features;
        
 $A=0; $qsdiff=0; $qediff=0;  $ssdiff=0;  $sediff=0; $compare='';
my @new_parsed_hsps=@new_sorted_hsps;  
  
  


OVERLAP:foreach my $align (@new_sorted_hsps){###Need to redo this as a sub

      unless ($A==0){
#print STDERR $compare->{Q_start}."\t ".$compare->{Q_end}."\t ".$compare->{T_start}.",\t ".$compare->{T_end}.", ". $compare->{score}."\n";
#print STDERR $align->{Q_start}."\t ".$align->{Q_end}.",\t ".$align->{T_start}."\t ".$align->{T_end}.", ". $align->{score}."\n";

        if (($align->{Q_start} <= $compare->{Q_end}) && ((($align->{T_start} <= $compare->{T_end}) && ($align->{T_start} >= $compare->{T_start})) || (($align->{T_start} <= $compare->{T_start}) && ($align->{T_end} >= $compare->{T_start})))){
    
    #it overlaps -- on both q and s don't care if it only overlaps on one strand as may be repeat
#print STDERR "Overlap:$A \n";
      if (($align->{Q_strand} eq $compare->{Q_strand}) && ($align->{T_strand} eq $compare->{T_strand})){
#same strand - do they extend each other? keep both otherwise keep higher score
          
#calculate the diff at each end and see if this is greater than eg 2aa
        
        $qsdiff= $align->{Q_start} - $compare->{Q_start}; #should always be positive
        $qediff= $align->{Q_end} - $compare->{Q_end} ;#should be positive to be included 
             
        $ssdiff= $align->{T_start} - $compare->{T_start}; 
        $sediff= $align->{T_end} - $compare->{T_end} ;#should be positive to be included 
        
        if($align->{score} >= $compare->{score}) {
          unless(($qsdiff > 6) || ($qediff < -6)){
            #ditch $compare
            my $sp=splice @new_parsed_hsps, $A-1, 1;
#print STDERR "a-1: ".$compare->{score} ." ditch i-1". $sp->{score}." \n";
              $compare=$align; next OVERLAP;
             }
          else{#keep both as extend
            $compare=$align; $A++; next OVERLAP;
          
            }
          }
          
        elsif($align->{score} < $compare->{score}) {
          unless ($qediff > 6){
            #ditch align
            my $sp=splice @new_parsed_hsps, $A, 1;
#print STDERR "$qediff align: ".$align->{score}." ditch align". $sp->{score}." \n";
             next OVERLAP;
            }
          else{#keep both as extend
            $compare=$align; $A++; next OVERLAP;
          
            }
          }
        
        $compare=$align; $A++; next OVERLAP; 
             
        }
          
#######NB must remember to return only those hsps that pass this 
      else{#diff strand therfore just keep the one with the highest score####unless overlap is very small ie due to possible palindromic regulatory region etc
      #calc overlap 
        my $overlap=($compare->{T_end}-$align->{T_start});
        my $comp_P_overlap=$overlap/$compare->{len};
        my $align_P_overlap=$overlap/$align->{len};
        #if (($comp_P_overlap<=0.1) || ($align_P_overlap<=0.1)){
#print STDERR "keep both as overlap small comp:$comp_P_overlap, align:$align_P_overlap\n";
          #keep both
          #$compare=$align; 
          #$A++;
          #next OVERLAP;
          #}
        if ($compare->{score} > $align->{score}) {
          #ditch align
          my $sp=splice @new_parsed_hsps, $A, 1;
#print STDERR "align: ".$align->{score}." (".$compare->{score} ." ) splice align ". $sp->{score}." \n";
           next OVERLAP;
          }
        elsif ($compare->{score} < $align->{score}) {
          #ditch i-1
          my $sp=splice @new_parsed_hsps, $A-1, 1;
#print STDERR "a-1: ".$compare->{score} ." (".$align->{score}." ) splice i-1 ". $sp->{score}." \n";
           $compare=$align; next OVERLAP;
          }
        else{#keep both
#print STDERR "keep both as scores the same".$align->{score}.", ".$compare->{score}."\n";        
        $compare=$align; $A++; next OVERLAP; 
          }
        }
      }
    else{ 
#print STDERR "not overlap $A\n";
      $compare=$align; $A++; next OVERLAP;#don't overlap --keep and use as next $align
      }
        }
  else{ 
    $compare=$align; 
#print STDERR "First pass a=$A;\n";
    $A++; #only used on first pass
    #do something????
    next OVERLAP;
    }
  
  }#end foreach/OVERLAP
  #print STDERR " end of overlap2 before push ". scalar(@new_features)."  ".scalar(@new_parsed_hsps)."\n";
   push (@new_features, @new_parsed_hsps);#  
 
 
 
 
 
     @all_same=();
    #print STDERR $ali->{chr1}." $chr $prev_chr\n";
    push @all_same, $ali;
    $prev_chr1=$chr1; $prev_chr2=$chr2;#e
     next CHR;
 
 


    
  }
    elsif(($prev_chr1 eq $chr1) || ($prev_chr2 eq $chr2)){#e
      push @all_same, $ali;
      #print scalar(@all_same)." ". ref($ali)."\n";
      

      
      }

    }
  else {#first pass
  push @all_same, $ali;
    $prev_chr1=$chr1;#e
    $prev_chr2=$chr2;#e
    }

  }

#######################################################################################
## print out into general data file, and tab file for URL/DAS display
## NB data file now a tab delimited file for upload directly into genomic_align genome
## Plus file of t3 stats
#####################################################################################



#####################################################################################
##    SORT for GROUPING
##
##We do not use strand for display therefore ignore
##Sort with:
#target chromosome, query chromosome, target start, query start for Target display and reverse if specific for query
#####################################################################################


#my @sorted_features=sort{$a->{chr2} cmp $b->{chr2} || $a->{T_strand_no}<=>$b->{T_strand_no} || $a->{Q_strand_no}<=>$b->{Q_strand_no} || $a->{chr1} cmp $b->{chr1} ||$a->{T_start}<=>$b->{T_start} } @new_features;

my @sorted_features;
###To display for query
if ($reverse_output){
  @sorted_features=sort{$a->{chr1} cmp $b->{chr1} || $a->{chr2} cmp $b->{chr2} ||$a->{Q_start}<=>$b->{Q_start}|| $a->{T_start}<=>$b->{T_start}} @new_features;
  }
else{
###To display for target
  @sorted_features=sort{$a->{chr2} cmp $b->{chr2} || $a->{chr1} cmp $b->{chr1} ||$a->{T_start}<=>$b->{T_start}|| $a->{Q_start}<=>$b->{Q_start}} @new_features;
  }

  my $x=0;my $ok=0;
  foreach my $array (@sorted_features){
#########################################

    $x++; $ok++; #start at 1
    unless ($ok==1){
    #print STDERR $sorted_features[$ok-2]->{chr1}." eq ".$array->{chr1}."\n";
    
      #if (($sorted_features[$ok-2]->{chr2} eq $array->{chr2}) && ($sorted_features[$ok-2]->{chr1} eq $array->{chr1}) && ($sorted_features[$ok-2]->{Q_strand} eq $array->{Q_strand}) && ($sorted_features[$ok-2]->{T_strand} eq $array->{T_strand})) { ###use if strand important
      
      if (($sorted_features[$ok-2]->{chr2} eq $array->{chr2}) && ($sorted_features[$ok-2]->{chr1} eq $array->{chr1})){ ##use when strand irrelevant for grouping 
      
      
      my $deltaH = $array->{T_start}-$sorted_features[$ok-2]->{T_end};
      my $deltaQ = $array->{Q_start}-$sorted_features[$ok-2]->{Q_end};
        if (($deltaH <= $diff) && ($deltaQ <= $diff)){#overlap
          $x--;#keep the same no
          }
        }
      }
    if ($reverse_output){
      #print OUT "$array->{chr1}\t$array->{prog}\t$array->{feat}\t$array->{Q_start}\t$array->{Q_end}\t$array->{score}\t$array->{Q_strand}\t.\t$x\t\n";    
      }
    else{
      #print OUT "$array->{chr2}\t$array->{prog}\t$array->{feat}\t$array->{T_start}\t$array->{T_end}\t$array->{score}\t$array->{T_strand}\t.\t$x\t\n";  
      }  
    print DATA "$ok($x)\t$array->{sps1}\t$array->{chr1}\t$array->{prog}\t$array->{feat}\t$array->{Q_start}\t$array->{Q_end}\t$array->{Q_strand}\t$array->{sps2}\t$array->{chr2}\t$array->{T_start}\t$array->{T_end}\t$array->{T_strand}\t$array->{score}\t$array->{ident}\t$array->{posit}\t$array->{cigar}\n";
    
    
    #print TSTATS "$array->{sps1}\t$array->{chr1}\t$array->{Q_start}\t$array->{Q_end}\t$array->{Q_strand}\t$array->{sps2}\t$array->{chr2}\t$array->{T_start}\t$array->{T_end}\t$array->{T_strand}\t$array->{score}\t$array->{ident}\t$array->{posit}\t$array->{cigar}\t$array->{t0} $array->{t1} $array->{t2}\t$array->{base3}\t$array->{len}\t$array->{sum_len}\n"; 
    
    $prev{T_start}=$array->{T_start};
    
####use if strand needed    
    #unless ((defined($prev{T_strand})) && ($prev{T_strand} eq $array->{T_strand}) && ($prev{T_end}>$array->{T_end})){ $prev{T_end}=$array->{T_end};}
    #$prev{T_strand}=$array->{T_strand};
    }
    
    print STDERR "Lost $minus_count bad seqs\n"; 
close FILE; #close OUT; close  TSTATS;
close DATA;



sub get_best_score_in_all_frames {
  my ($seq1, $seq2, $matrix) = @_;

  my @dna_seq1_6fr = Bio::SeqUtils->translate_6frames($seq1);
  my @dna_seq2_6fr = Bio::SeqUtils->translate_6frames($seq2);

  my $score;
  my $id = 0;
  my $frame = 0;
##  my $seqs;
  for (my $i=0; $i<6; $i++) {
    my $this_score = 0;
    my $this_id = 0;
    my $this_seq1 = $dna_seq1_6fr[$i]->seq;
    my $this_seq2 = $dna_seq2_6fr[$i]->seq;
    my $length = length($this_seq1);
    $length = length($this_seq2) if (length($this_seq2) < $length);
    my @this_seq1 = split("", $this_seq1);
    my @this_seq2 = split("", $this_seq2);
##    for (my $j=0; $j<$length; $j++) {
##      my $aa1 = $this_seq1[$j];
##      my $aa2 = $this_seq2[$j];
###      if (($j != $length-1) and ($aa1 eq "*" or $aa2 eq "*")) {
###        $this_score -= 10;
###      }
##      if (defined($matrix)) {
##        $this_score += $matrix->{$aa1}->{$aa2};
##      } else {
##        if ($aa1 eq $aa2) {
##          $this_score += 2;
##          $id++;
##        } else {
##          $this_score--;
##        }
##      }
##    }

    if (defined($matrix)) {
      for (my $j=0; $j<$length; $j++) {
        my $aa1 = $this_seq1[$j];
        my $aa2 = $this_seq2[$j];
        $this_score += $matrix->{$aa1}->{$aa2};
        $this_id++ if ($aa1 eq $aa2);
      }
    } else {
      for (my $j=0; $j<$length; $j++) {
        my $aa1 = $this_seq1[$j];
        my $aa2 = $this_seq2[$j];
        if ($aa1 eq $aa2) {
          $this_score += 2;
          $this_id++;
        } else {
          $this_score--;
        }
      }
    }

    if (!defined($score) or ($this_score > $score)) {
      $score = $this_score;
      $id = $this_id;
      $frame = $i;
##      $seqs = $this_seq1."\n".$this_seq2;
    }
  }

  return ($score, $id, $frame);
}

sub get_matrix_from_pam_file {
  my ($filename) = @_;
  my $matrix;

  open(PAM, $filename) or throw("Cannot open <$filename>");
  my @col_keys;
  while (<PAM>) {
    next if ($_ =~ /^#/);
    $_ =~ s/[\r\n]+$//;
    my @values = split(/ +/, $_);
    my $row_key = shift(@values);
    if (!@col_keys and $row_key eq "") {
      @col_keys = @values;
    } else {
      foreach my $col_key (@col_keys) {
        $matrix->{$row_key}->{$col_key} = shift(@values);
      }
    }
  }

  return $matrix;
}
