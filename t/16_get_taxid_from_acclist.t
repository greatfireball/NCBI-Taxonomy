# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'get_taxid_from_gilist');

# the follwing lines were obtained from the test input data via:
# zcat t/data/test.accession2taxid.gz | cut -f 3,4 | sed 's/\([0-9]*\)\t\([0-9]*\)/\2 => \1,/;'

my $testset = {
    2 => 4,
    3 => 4,
    4 => 3,
    5 => 4,
    6 => 1,
    7 => 4,
    8 => 4,
    9 => 1,
    10 => 1,
    11 => 2,
    12 => 3,
    13 => 3,
    14 => 2,
    15 => 3,
    16 => 2,
    17 => 2,
    18 => 2,
    19 => 1,
    20 => 4,
    21 => 2
};

# test for single gis
while (my ($gi, $taxid) = each %{$testset})
{   
    my @gis = ($gi);
    my $expected = {$gi => $taxid};
    my $got = NCBI::Taxonomy::get_taxid_from_gilist(\@gis);
    is_deeply($got, $expected, "Taxid for a single species number ($gi)");
}

# test for a whole list
my @gis = (keys %{$testset});
my $expected = $testset;
my $got = NCBI::Taxonomy::get_taxid_from_gilist(\@gis);
is_deeply($got, $expected, "Taxids for a species list");

done_testing();
