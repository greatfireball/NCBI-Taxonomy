# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'getallranksusedbyNCBI');

use lib './t';
use RefData;

my @expect = @RefData::ranks;

my @got = NCBI::Taxonomy::getallranksusedbyNCBI();

is_deeply( [ sort @got ], [ sort @expect ], 'Are the right taxonomic ranks are returned?');

done_testing();