# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'get_taxid_from_gilist');

# the follwing lines were obtained from the test input data via:
# zcat t/data/test.accession2taxid.gz | awk '{print $2"\t"$3;}' | sed "s/\([^[:space:]]*\)\t\([0-9]*\)/'\1' => \2,/;"

my $testset = {
    'A0000002.9' => 4,
    'A0000000003.5' => 4,
    'G0000004.7' => 3,
    'F0000005.7' => 4,
    'D00000006.6' => 1,
    'C0000000000007.7' => 4,
    'F000008.4' => 4,
    'E000000009.2' => 1,
    'B00000010.8' => 1,
    'B00000011.2' => 2,
    'G0000000012.5' => 3,
    'D00000000013.1' => 3,
    'E00000014.10' => 2,
    'A00000015.6' => 3,
    'B00016.6' => 2,
    'E017.9' => 2,
    'G018.6' => 2,
    'B0000000000019.1' => 1,
    'E000000000000020.8' => 4,
    'D0000021.7' => 2
};

# test for single gis
while (my ($acc, $taxid) = each %{$testset})
{   
    my @accs = ($acc);
    my $expected = {$acc => $taxid};
    my $got = NCBI::Taxonomy::get_taxid_from_gilist(\@accs);
    is_deeply($got, $expected, "Taxid for a single species accession ($acc)");
}

# test for a whole list
my @accs = (keys %{$testset});
my $expected = $testset;
my $got = NCBI::Taxonomy::get_taxid_from_gilist(\@accs);
is_deeply($got, $expected, "Taxids for a species list");

done_testing();
