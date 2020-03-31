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

Bio::EnsEMBL::Compara::PipeConfig::Pan::CreateSpeciesTree_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Pan::CreateSpeciesTree_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the LoadMembers pipeline for Pan. Please, refer
to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Covid19::CreateSpeciesTree_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::CreateSpeciesTree_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        'division' => 'covid19',
        'outgroup' => 'human_adenovirus_b3_gca_000880515',
        'taxonomic_ranks' => ['genus', 'family', 'order', 'class', 'phylum', 'superkingdom'],

    };
}


1;