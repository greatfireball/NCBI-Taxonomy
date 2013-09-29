# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'pairwiseLCA');

use lib './t';
use RefData;

foreach my $act_pair (@RefData::pairwise_lca)
{
	my $expected = $act_pair->{lca_lineage};
	my $taxonA   = $act_pair->{first_lineage};
	my $taxonB   = $act_pair->{second_lineage};
	my $got = NCBI::Taxonomy::pairwiseLCA($taxonA, $taxonB);

	is_deeply($got, $expected, "LCA for taxid ".$act_pair->{first_taxon}." and taxid ".$act_pair->{second_taxon});
}

# test for same lineage
foreach my $act_taxon (1..23)
{
	my $expected = $RefData::lineage->{$act_taxon};
	my $taxonA   = $expected;
	my $taxonB   = $expected;
	my $got = NCBI::Taxonomy::pairwiseLCA($taxonA, $taxonB);

	is_deeply($got, $expected, "LCA for identical taxid $taxonA");
}

done_testing();