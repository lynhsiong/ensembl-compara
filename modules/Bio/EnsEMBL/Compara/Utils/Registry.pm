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

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This modules contains common methods used when dealing with the
Registry, especially in the context of registry configuration files.

The hash structure accepted in all add*dbas functions is like this:

 my $ancestral_dbs = {
     'ancestral_prev'    => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$prev_release" ],
     'ancestral_curr'    => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$curr_release" ],
 };

It can be directly passed to the add*dbas function like this:

 Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $ancestral_dbs );

Note that read+write connections are opened for all databases on production
servers as long as they don't have "_prev" in the name. Otherwise, a
read-only connection (ensro user) is used.

The port and passwords are automatically retrieved through the mysql-cmd binary.

=head1 REGISTRY DEFINITION METHODS

=cut

package Bio::EnsEMBL::Compara::Utils::Registry;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor;

my %ports;
my %rw_users;
my %rw_passwords;


=head2 load_collection_core_database

  Example     : Bio::EnsEMBL::Compara::Utils::Registry::load_collection_core_database(
                  -host   => 'mysql-ens-sta-4',
                  -port   => 4494,
                  -user   => 'ensro',
                  -pass   => '',
                  -dbname => "bacteria_0_collection_core_${curr_eg_release}_${curr_release}_1",
                );
  Description : Add a DBAdaptor for every species found in the database. See the constructor of
                Bio::EnsEMBL::DBSQL::DBAdaptor and Bio::EnsEMBL::DBSQL::DBConnection for a
                description of the available arguments.
  Returntype  : none
  Exceptions  : none

=cut

sub load_collection_core_database {
    my @args = @_;
    my ($verbose, $species_suffix) = rearrange( [qw(VERBOSE SPECIES_SUFFIX)], @args);

    $species_suffix //= '';

    my $dbc = new Bio::EnsEMBL::DBSQL::DBConnection(@args);
    $dbc->sql_helper->execute_no_return(
        -SQL        => q{SELECT species_id, meta_value FROM meta WHERE meta_key = 'species.db_name'},
        -CALLBACK   => sub {
            my ($species_id, $species_name) = @{$_[0]};

            my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
                -group           => 'core',
                -species         => $species_name.$species_suffix,
                -species_id      => $species_id,
                -multispecies_db => 1,
                @args,
            );
            if ($verbose) {
                printf( "Species '%s' (id:%d) loaded from database '%s'\n", $species_name, $species_id, $dbc->dbname );
            }
        },
    );
    $dbc->disconnect_if_idle;
}


=head2 add_core_dbas

  Example     : Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $core_dbs );
  Description : Define a Bio::EnsEMBL::DBSQL::DBAdaptor for each database
  Returntype  : none
  Exceptions  : none

=cut

sub add_core_dbas {
    add_dbas('Bio::EnsEMBL::DBSQL::DBAdaptor', $_[0]);
}


=head2 add_compara_dbas

  Example     : Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );
  Description : Define a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor for each database
  Returntype  : none
  Exceptions  : none

=cut

sub add_compara_dbas {
    add_dbas('Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', $_[0]);
}


=head2 add_taxonomy_dbas

  Example     : Bio::EnsEMBL::Taxonomy::Utils::Registry::add_taxonomy_dbas( $taxonomy_dbs );
  Description : Define a Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor for each database
  Returntype  : none
  Exceptions  : none

=cut

sub add_taxonomy_dbas {
    add_dbas('Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor', $_[0], -group => 'taxonomy',);
}


=head2 add_dbas

  Example     : Bio::EnsEMBL::Taxonomy::Utils::Registry::add_dbas( 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', $compara_dbs );
  Description : Define a DBAdaptor of the required type for each database.  For databases
                on production instances that don't contain "_prev", a read+write connection
                is defined (using ensadmin or ensrw), querying the password with a mysql-cmd.
                Otherwise a read-only connection is defined (using the ensro user).
  Returntype  : none
  Exceptions  : none

=cut

sub add_dbas {
    my $dba_class = shift;
    my $compara_dbs = shift;

    foreach my $alias_name ( keys %$compara_dbs ) {
        my ( $host, $db_name ) = @{ $compara_dbs->{$alias_name} };

        my ( $user, $pass );
        if ( ($host =~ /-prod-/) && !($alias_name =~ /_prev/) ) {
            $user = get_rw_user($host);
            $pass = get_rw_pass($host);
        } else {
            $user = 'ensro';
            $pass = '';
        }

        $dba_class->new(
            -host => $host,
            -user => $user,
            -pass => $pass,
            -port => get_port($host),
            -species => $alias_name,
            -dbname  => $db_name,
            @_,
        );
    }
}


=pod

=head1 MYSQL_CMDS WRAPPER METHODS

=cut


=head2 get_port

  Arg[1]      : String $host. Host name
  Example     : Bio::EnsEMBL::Compara::Utils::Registry::get_port('mysql-ens-compara-prod-1');
  Description : Run the associated mysql-cmd to get the port of this host
  Returntype  : Integer
  Exceptions  : none

=cut

sub get_port {
    my $host = shift;
    unless (exists $ports{$host}) {
        my $port = `$host port`;
        chomp $port;
        $ports{$host} = $port;
    }
    return $ports{$host};
}


=head2 get_rw_user

  Arg[1]      : String $host. Host name
  Example     : Bio::EnsEMBL::Compara::Utils::Registry::get_rw_user('mysql-ens-compara-prod-1');
  Description : Run the associated mysql-cmd to get the read+write username for this host
  Returntype  : String
  Exceptions  : none

=cut

sub get_rw_user {
    my $host = shift;
    unless (exists $rw_users{$host}) {
        # There are several possible user names
        foreach my $rw_user (qw(ensadmin ensrw w)) {
            my $rc = system("which $host-$rw_user > /dev/null");
            unless ($rc) {
                $rw_users{$host} = $rw_user;
                last;
            }
        }
    }
    return $rw_users{$host};
}


=head2 get_rw_pass

  Arg[1]      : String $host. Host name
  Example     : Bio::EnsEMBL::Compara::Utils::Registry::get_rw_pass('mysql-ens-compara-prod-1');
  Description : Run the associated mysql-cmd to get the password of this host's read+write user
  Returntype  : String
  Exceptions  : none

=cut

sub get_rw_pass {
    my $host = shift;
    unless (exists $rw_passwords{$host}) {
        my $rw_user = get_rw_user($host);
        if ($rw_user) {
            my $rw_pass = `$host-$rw_user pass`;
            chomp $rw_pass;
            $rw_passwords{$host} = $rw_pass;
        }
    }
    return $rw_passwords{$host};
}

1;
