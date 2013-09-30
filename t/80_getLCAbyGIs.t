# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
use Test::Exception;

BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'getLCAbyGIs');

dies_ok( sub {NCBI::Taxonomy::getLCAbyGIs()} , 'The normal call of NCBI::Taxonomy::getLCAbyGIs() should die');

done_testing();