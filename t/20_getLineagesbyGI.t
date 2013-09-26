# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'getLineagesbyGI');

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
   73 => [
		{
			taxid => 23,
			sciname => "species 10",
			rank => "species"
		},
		{
			taxid => 18,
			sciname => "genus06",
			rank => "genus"
		},
		{
			taxid => 12,
			sciname => "family03",
			rank => "family"
		},
		{
			taxid => 8,
			sciname => "class",
			rank => "class"
		},
		{
			taxid => 4,
			sciname => "phylum",
			rank => "phylum"
		},
		{
			taxid => 1,
			sciname => "root",
			rank => "no rank"
		}
   ],
   114 => [
		{
			taxid => 23,
			sciname => "species 10",
			rank => "species"
		},
		{
			taxid => 18,
			sciname => "genus06",
			rank => "genus"
		},
		{
			taxid => 12,
			sciname => "family03",
			rank => "family"
		},
		{
			taxid => 8,
			sciname => "class",
			rank => "class"
		},
		{
			taxid => 4,
			sciname => "phylum",
			rank => "phylum"
		},
		{
			taxid => 1,
			sciname => "root",
			rank => "no rank"
		}
   ],
   188 => [
		{
			taxid => 22,
			sciname => "species 09",
			rank => "species"
		},
		{
			taxid => 18,
			sciname => "genus06",
			rank => "genus"
		},
		{
			taxid => 12,
			sciname => "family03",
			rank => "family"
		},
		{
			taxid => 8,
			sciname => "class",
			rank => "class"
		},
		{
			taxid => 4,
			sciname => "phylum",
			rank => "phylum"
		},
		{
			taxid => 1,
			sciname => "root",
			rank => "no rank"
		}
   ],
   238 => [
		{
			taxid => 10,
			sciname => "genus03",
			rank => "genus"
		},
		{
			taxid => 7,
			sciname => "family01",
			rank => "family"
		},
		{
			taxid => 4,
			sciname => "phylum",
			rank => "phylum"
		},
		{
			taxid => 1,
			sciname => "root",
			rank => "no rank"
		}
   ],
   278 => [
		{
			taxid => 5,
			sciname => "species 01",
			rank => "species"
		},
		{
			taxid => 3,
			sciname => "genus01",
			rank => "genus"
		},
		{
			taxid => 1,
			sciname => "root",
			rank => "no rank"
		}
   ],
   285 => [
		{
			taxid => 4,
			sciname => "phylum",
			rank => "phylum"
		},
		{
			taxid => 1,
			sciname => "root",
			rank => "no rank"
		}
   ],
   461 => [
		{
			taxid => 21,
			sciname => "species 08",
			rank => "species"
		},
		{
			taxid => 18,
			sciname => "genus06",
			rank => "genus"
		},
		{
			taxid => 12,
			sciname => "family03",
			rank => "family"
		},
		{
			taxid => 8,
			sciname => "class",
			rank => "class"
		},
		{
			taxid => 4,
			sciname => "phylum",
			rank => "phylum"
		},
		{
			taxid => 1,
			sciname => "root",
			rank => "no rank"
		}
   ],
   571 => [
		{
			taxid => 22,
			sciname => "species 09",
			rank => "species"
		},
		{
			taxid => 18,
			sciname => "genus06",
			rank => "genus"
		},
		{
			taxid => 12,
			sciname => "family03",
			rank => "family"
		},
		{
			taxid => 8,
			sciname => "class",
			rank => "class"
		},
		{
			taxid => 4,
			sciname => "phylum",
			rank => "phylum"
		},
		{
			taxid => 1,
			sciname => "root",
			rank => "no rank"
		}
   ],
   575 => [
		{
			taxid => 22,
			sciname => "species 09",
			rank => "species"
		},
		{
			taxid => 18,
			sciname => "genus06",
			rank => "genus"
		},
		{
			taxid => 12,
			sciname => "family03",
			rank => "family"
		},
		{
			taxid => 8,
			sciname => "class",
			rank => "class"
		},
		{
			taxid => 4,
			sciname => "phylum",
			rank => "phylum"
		},
		{
			taxid => 1,
			sciname => "root",
			rank => "no rank"
		}
   ],
   800 => [
		{
			taxid => 23,
			sciname => "species 10",
			rank => "species"
		},
		{
			taxid => 18,
			sciname => "genus06",
			rank => "genus"
		},
		{
			taxid => 12,
			sciname => "family03",
			rank => "family"
		},
		{
			taxid => 8,
			sciname => "class",
			rank => "class"
		},
		{
			taxid => 4,
			sciname => "phylum",
			rank => "phylum"
		},
		{
			taxid => 1,
			sciname => "root",
			rank => "no rank"
		}
   ]
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