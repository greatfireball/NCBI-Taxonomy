# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More tests;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'getLCAbyGIs');

done_testing();