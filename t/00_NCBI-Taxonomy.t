# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl NCBI-Taxonomy.t'

#########################

use Test::More;

## empty all old database files from data folder
foreach my $file (glob "./t/data/*.bin")
{
	unlink($file) || die "Unable to delete file '$file'\n";
}

use_ok('NCBI::Taxonomy');

done_testing();
