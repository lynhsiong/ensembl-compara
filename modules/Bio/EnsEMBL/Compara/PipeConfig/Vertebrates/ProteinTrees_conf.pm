=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -mlss_id <curr_ptree_mlss_id>

=head1 DESCRIPTION

The Vertebrates PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division'      => 'vertebrates',

    # clustering parameters:
        # affects 'hcluster_dump_input_per_genome'
        'outgroups'                     => { 'saccharomyces_cerevisiae' => 2 },
        # File with gene / peptide names that must be excluded from the clusters (e.g. know to disturb the trees)
        'gene_blacklist_file'           => $self->o('warehouse_dir') . '/proteintree_blacklist.e82.txt',

    # species tree reconciliation
        # you can define your own species_tree for 'notung' or 'CAFE'. It *has* to be binary
        'binary_species_tree_input_file'   => $self->o('binary_species_tree'),

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => ['Theria', 'Sauria', 'Tetraodontiformes', 'Percomorphaceae'],

    # threshold used by per_genome_qc in order to check if the amount of orphan genes are acceptable
    # values were infered by checking previous releases, values that are out of these ranges may be caused by assembly and/or gene annotation problems.
        'mapped_gene_ratio_per_taxon' => {
            '2759'    => 0.5,     #eukaryotes
            '33208'   => 0.65,    #metazoans
            '7742'    => 0.85,    #vertebrates
            '117571'  => 0.9,     #bony vertebrates
            '9443'    => 0.95,    #primates
          },

        # List of species some genes have been projected from
        'projection_source_species_names' => [ 'homo_sapiens', 'mus_musculus', 'danio_rerio' ],

    # GOC parameters
        'goc_taxlevels'                 => ["Euteleostomi","Ciona"],
    };
}



sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    my %overriden_rc_names = (
        'CAFE_table'                => '24Gb_job',
        'hcluster_run'              => '1Gb_job',
        'hcluster_parse_output'     => '1Gb_job',
        'split_genes'               => 'default',   # This is 250Mb
        'CAFE_species_tree'         => '24Gb_job',
        'expand_clusters_with_projections' => '500Mb_job',
    );
    foreach my $logic_name (keys %overriden_rc_names) {
        $analyses_by_name->{$logic_name}->{'-rc_name'} = $overriden_rc_names{$logic_name};
    }
    $analyses_by_name->{'CAFE_analysis'}->{'-parameters'}{'pvalue_lim'} = 1;
    $analyses_by_name->{'make_treebest_species_tree'}->{'-parameters'}->{'allow_subtaxa'} = 1;
}


1;
