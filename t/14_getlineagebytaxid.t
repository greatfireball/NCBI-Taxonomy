# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'getlineagebytaxid');

use lib './t';
use RefData;

foreach my $taxid (keys %{$RefData::lineage})
{
	my $expected = $RefData::lineage->{$taxid};
	my $got = NCBI::Taxonomy::getlineagebytaxid($taxid);
	is_deeply($got, $expected, "Lineage for taxid $taxid");
}


done_testing();