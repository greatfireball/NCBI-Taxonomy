# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'getLineagesbyGI');

my $gi = 20;
my @gis = ($gi);
my $expected = {
   23 => [
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
my $got = NCBI::Taxonomy::getLineagesbyGI(@gis);
is_deeply($got, $expected, "Lineage for GI:$gi");

done_testing();