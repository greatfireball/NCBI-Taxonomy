use warnings;
use strict;
use lib './lib/';
use NCBI::Taxonomy;

open(FH, '</tmp/tina_lineage.txt');
my @gis = <FH>;
close(FH);

foreach (0..@gis-1) {$gis[$_] = $1 if ($gis[$_] =~ /^>(\d+)/); }
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

while (@gis) {
    my @subset = ();
    foreach (0..499) { push(@subset, shift(@gis)) if (@gis); }

    my $a=NCBI::Taxonomy::getLineagesbyGI(@subset);

    foreach my $gi (keys %$a) {
	print "GI|$gi|".join("|", map {($_->{rank},$_->{sciname})} reverse @{$a->{$gi}})."\n";
    }
}
#my $a=NCBI::Taxonomy::getTaxonomicRankbyGI(\@gis, 'family');


