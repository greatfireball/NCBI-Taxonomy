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
   2  => $RefData::lineageclean->{4},
   3  => $RefData::lineageclean->{4},
   4  => $RefData::lineageclean->{3},
   5  => $RefData::lineageclean->{4},
   6  => $RefData::lineageclean->{1},
   7  => $RefData::lineageclean->{4},
   8  => $RefData::lineageclean->{4},
   9  => $RefData::lineageclean->{1},
   10 => $RefData::lineageclean->{1},
   11 => $RefData::lineageclean->{2},
   12 => $RefData::lineageclean->{3},
   13 => $RefData::lineageclean->{3},
   14 => $RefData::lineageclean->{2},
   15 => $RefData::lineageclean->{3},
   16 => $RefData::lineageclean->{2},
   17 => $RefData::lineageclean->{2},
   18 => $RefData::lineageclean->{2},
   19 => $RefData::lineageclean->{1},
   20 => $RefData::lineageclean->{4},
   21 => $RefData::lineageclean->{2}

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