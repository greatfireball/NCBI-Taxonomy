# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'getLineagesbyGI');

use lib './t';
use RefData;

# I generated a test set using the command 
#       cat t/data/gi_taxid*.dmp | shuf -n 10 | sort -n
#       73	23
#       114	26
#       188	22
#       238	10
#       278	24
#       285	4
#       461	21
#       571	22
#       575	22
#       800	23
#
# Afterwards I used the test tree to reconstruct the expected output

my $testset = {
   73 => $RefData::lineageclean->{23},
   114 => $RefData::lineageclean->{23},
   188 => $RefData::lineageclean->{22},
   238 => $RefData::lineageclean->{10},
   278 => $RefData::lineageclean->{5},
   285 => $RefData::lineageclean->{4},
   461 => $RefData::lineageclean->{21},
   571 => $RefData::lineageclean->{22},
   575 => $RefData::lineageclean->{22},
   800 => $RefData::lineageclean->{23}
};


foreach my $gi (keys %{$testset})
{
	my @gis = ($gi);
	my $expected = { $gi => $testset->{$gi} };
	my $got = NCBI::Taxonomy::getLineagesbyGI(@gis);
	is_deeply($got, $expected, "Lineage for single GI:$gi");
}

my @gis = (keys %{$testset});
my $expected = $testset;
my $got = NCBI::Taxonomy::getLineagesbyGI(@gis);
is_deeply($got, $expected, "Lineage for whole GI set");

done_testing();