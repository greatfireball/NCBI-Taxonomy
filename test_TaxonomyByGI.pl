use warnings;
use strict;
require TaxonomyByGI;

open(FH, '</bio/data/NCBI/nt/taxonomy/gi_list_22876.txt');
my @gis = <FH>;
close(FH);

foreach (0..@gis-1) {$gis[$_] = $1 if ($gis[$_] =~ /(\d+)/); }
#my @gis = (18361509,18361510, 18361511,18361512, 18361513,18361514);

use Data::Dumper;

# my @g = ();
# my $i = 0;
# foreach (@gis) {
#     $g[0] = $_;
#     my $a=TaxonomyByGI::getTaxonomicRankbyGI(\@g, 'family');
#     $i++;
#     print "$i bearbeitet\n";
# }

#my $a=TaxonomyByGI::getLineagesbyGI(@gis);
my $a=TaxonomyByGI::getTaxonomicRankbyGI(\@gis, 'family');

#print Dumper($a);
