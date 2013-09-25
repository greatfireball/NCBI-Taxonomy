# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'get_taxid_from_gilist');

# the follwing lines where randomly choosen from the test data set using the following command:
# cat t/data/gi_taxid*.dmp | shuf -n 25 | sort -n | sed 's/\t/ => /g; s/$/,/;'

my $testset = {
   4 => 4,
   31 => 9,
   38 => 22,
   91 => 11,
   104 => 10,
   157 => 21,
   170 => 17,
   173 => 2,
   244 => 2,
   332 => 14,
   385 => 12,
   417 => 6,
   465 => 23,
   557 => 4,
   620 => 18,
   665 => 13,
   714 => 1,
   745 => 2,
   782 => 12,
   816 => 7,
   897 => 7,
   910 => 25,
   938 => 18,
   991 => 20,
   999 => 6
};

# test for single gis
while (my ($gi, $taxid) = each %{$testset})
{   
    my @gis = ($gi);
    my $expected = {$gi => $taxid};
    my $got = NCBI::Taxonomy::get_taxid_from_gilist(\@gis);
    is_deeply($got, $expected, "Lineage for a single species number ($gi)");
}

# test for a whole list
my @gis = (keys %{$testset});
my $expected = $testset;
my $got = NCBI::Taxonomy::get_taxid_from_gilist(\@gis);
is_deeply($got, $expected, "Lineage for a species list");



done_testing();