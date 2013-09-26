# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

can_ok('NCBI::Taxonomy', 'getallranksusedbyNCBI');

my $expect = [
		'genus',
          	'class',
          	'phylum',
          	'species',
          	'family',
          	'no rank'
             ];

my $got = [ NCBI::Taxonomy::getallranksusedbyNCBI() ];

is_deeply( [ sort @{$got} ], [ sort @{$expect} ], 'Are the right taxonomic ranks are returned?');

done_testing();