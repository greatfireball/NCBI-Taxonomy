# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;
BEGIN { use_ok('NCBI::Taxonomy') };

#########################


### testing for an existing subroutine

# change to the right folder
my $folder = "./t/data/";

chdir($folder) || die "Unable to change to folder '$folder'\n";

my $cmd = "perl ../../make_taxid_indizes.pl --no-download --overwrite --quiet";

system($cmd);

my $errorcode = $?;

is($errorcode, 0, "Test of error code of make_taxid_indizes.pl run");

done_testing();