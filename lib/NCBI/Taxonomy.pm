package NCBI::Taxonomy;

use 5.008000;
use strict;
use warnings;
use DateTime::Format::Natural;

use Storable qw(retrieve nstore);

use version 0.77;
our $VERSION=version->declare("0.70.5");

# for logging purposes we use the Log4perl module
use Log::Log4perl;

my $init_text = "";
while (<DATA>) { $init_text .= $_; }

Log::Log4perl->init(\$init_text);
my $logger = Log::Log4perl->get_logger();

$logger->debug("Loaded the module NCBI::Taxonomy.pm (file ".__FILE__.", version: $VERSION)");

my $TAXDIR = './t/data/';   # where are the taxonomy-files stored
my $taxdatabase = $TAXDIR."/gi_taxid.bin";
my $taxnodesdatabase = $TAXDIR."/nodes.bin";

my $nodes;
if (-e $taxnodesdatabase)
{
    $nodes = getnewnodesimported();         # import the complete node information as newnodes
} else 
{
    # the nodes DB was not found
    $logger->debug("Unable to find the file '$taxnodesdatabase'");
}

my %downloaded_gi_taxid = ();

# used for speed up
my $max_ring_buffer_size = 7500;
my @ring_buffer = ();
my %ring_buffer_storage = ();

#
# Command: getLineagesbyGI( ref to list of gis )
#
# ref to list of gis ... should be selfexplaining
#
# result is a reference of a hash of list of hash
#        first hash key are the GIs
#        elements of list are the nodes of the tree upwards to the root
#        hash keys for the elements
#                sciname -> scientific name of taxon
#                rank -> rank given by NCBI
#                taxid -> taxid resulting from GI

sub getLineagesbyGI(\@) {

    my @gilist = @{shift()};

    my %gilist2search = ();
    # check if gis are only numbers!
    foreach (@gilist) {
	$logger->logcroak("Use only numbers as GIs!") if ($_ =~ /\D/);
	$gilist2search{$_}++;
    }

    return check4gis(\%gilist2search);

}

# Command: getTaxonomicRankbyGI( ref to list of gis, taxonomic rank )
#
# ref to list of gis ... should be selfexplaining
# taxonomic rank ... a string which determined for what rank is searched for (e.g. 'family')
#
# result is a reference of a hash of hash
#        first hash key are the GIs
#        hash keys for the elements
#                sciname -> scientific name of taxon
#                rank -> rank given by NCBI
#                taxid -> taxid resulting from GI
#
# Note all ranks used by NCBI are
#
# "class","family","forma","genus","infraclass","infraorder","kingdom","no rank","order",
# "parvorder","phylum","species","species group","species subgroup","subclass","subfamily",
# "subgenus","subkingdom","suborder","subphylum","subspecies","subtribe","superclass",
# "superfamily","superkingdom","superorder","superphylum","tribe","varietas"

sub getTaxonomicRankbyGI(\@$) {

    my @gilist = @{shift()};
    my $taxonrank = shift;

    # check for used rank!
    my $taxonrankvalid = 0;
    foreach (getallranksusedbyNCBI()) {
	if ($_ eq $taxonrank) {
	    $taxonrankvalid = 1;
	    last;
	}
    }

    $logger->logcroak("Use of not known taxonomic rank") if ($taxonrankvalid == 0);

    my %gilist2search = ();
    # check if gis are only numbers!
    foreach (@gilist) {
	$logger->logcroak("Use only numbers as GIs!") if ($_ =~ /\D/);
	$gilist2search{$_}++;
    }

    my $result = check4gis(\%gilist2search);

    # now I need to extract the right taxon rank
    my %taxonomicrankbyGI = ();
    foreach my $gi (keys %{$result}) {
	foreach my $act_level (@{$result->{$gi}}) {
	    if ($act_level->{rank} eq $taxonrank) {
		# I found the rank, so add to resulthash and go to next GI!
		$taxonomicrankbyGI{$gi} = $act_level;
		last;
	    }
	}
	# at this position the question is, Did I found a rank? If not make an empty hash-entry
	$taxonomicrankbyGI{$gi} = {} if (!exists $taxonomicrankbyGI{$gi});
    }

    return \%taxonomicrankbyGI;

}

# sub getallranksusedbyNCBI
#
# return a list of all ranks used by NCBI obtained by the following code:
# cut -f 3 -d "|" nodes.dmp | sed -e 's/^[[:blank:]]*\([^[:blank:]]*\)[[:blank:]]*$/"\1"/g' | sort | uniq | tr "\n" ","
#

sub getallranksusedbyNCBI {
    return ("class","family","forma","genus","infraclass","infraorder","kingdom",
	    "no rank","order","parvorder","phylum","species","species group",
	    "species subgroup","subclass","subfamily","subgenus","subkingdom",
	    "suborder","subphylum","subspecies","subtribe","superclass",
	    "superfamily","superkingdom","superorder","superphylum","tribe","varietas");
}

sub check4gis(\%) {
    my ($gilist) = @_;

    my %taxid_found_by_gi = ();

    open(FH, "<", $taxdatabase) || $logger->logdie("Unable to open taxonomic database at '$taxdatabase'");
    binmode(FH);

    my $data_format = "LL";

    my $bytesperline = length(pack($data_format, (0,0)));
    my $tmp = "";

    foreach my $gi (keys %$gilist) {
	my $bytepos = ($gi-1)*$bytesperline;
	
	# check if the taxid is not present, but was already downloaded
	if (exists $downloaded_gi_taxid{$gi})
	{
	    $logger->debug("Found taxid for gi $gi already downloaded");
	    $taxid_found_by_gi{$gi} = int($downloaded_gi_taxid{$gi});
	} else {
	    seek(FH, $bytepos, 0);
	    read(FH, $tmp, $bytesperline);
	    my ($dat_gi, $dat_taxid) = unpack($data_format, $tmp);
	    if ($dat_gi && $gi == $dat_gi) {
		$taxid_found_by_gi{$gi} = int($dat_taxid);
	    } else {
		my $output = qx(wget -q -O - 'http://www.ncbi.nlm.nih.gov/sviewer/viewer.fcgi?tool=portal&db=nuccore&val=$gi&dopt=genbank&sendto=on&log$=seqview&extrafeat=976&maxplex=1');
		if ($? == 0) {
		    if ($output =~ /^COMMENT\s+\[WARNING\] On (.+) this sequence was replaced by.+gi:(\d+)\./msg) {
			my ($datestring, $new_gi) = ($1,$2);
			my $parser = DateTime::Format::Natural->new;
			my $dt = $parser->parse_datetime($datestring);
			$logger->info("It seems GI|$gi was substituted on ".$dt." with GI|$new_gi (".'http://www.ncbi.nlm.nih.gov/entrez/sutils/girevhist.cgi?val='."$gi)");
		    } else {
			my @taxons = $output =~ /db_xref="taxon:(\d+)"/g;
			if (@taxons == 1) {
			    $taxid_found_by_gi{$gi} = int($taxons[0]);
			    $downloaded_gi_taxid{$gi} = int($taxons[0]);
			    $logger->info("Have to download the GenBank file for GI|$gi but was able to retrieve an Taxon-ID\n");
			} elsif (@taxons > 1) {
			    $logger->error("Error on retrieving a single Taxon-ID for GI|$gi. Returned were the following Taxon-IDs:".join(",", @taxons));
			} else {
			    $logger->error("Error on retrieving Taxon-ID for GI|$gi");
			}
		    }
		} else {
		    $logger->error("Error on receiving the following URL: http://www.ncbi.nlm.nih.gov/sviewer/viewer.fcgi?tool=portal&db=nuccore&val=$gi&dopt=genbank&sendto=on&log$=seqview&extrafeat=976&maxplex=1");
		}
	    }
	}
    }

    close(FH) || logger->logdie("Unable to close taxonomic database at '$taxdatabase'");

    # now I can perform the mapping
    my %Lineage_by_gi = ();
    foreach my $gi (keys %taxid_found_by_gi) {
	my $taxid = checktaxid4merged($taxid_found_by_gi{$gi});
	if (!defined $taxid) {
	    $logger->error("Error $gi gives undefined TaxID");
	    next;
	}
	$Lineage_by_gi{$taxid} = getlineagebytaxid($taxid);
    }

    return \%Lineage_by_gi;

}

sub checktaxid4merged 
{
    my ($taxid) = @_;
    if (defined $taxid && exists $nodes->[$taxid]->{merged_with})
    {
	return checktaxid4merged($nodes->[$taxid]->{merged_with});
    } else {
	return $taxid;
    }
}

sub pairwiseLCA {

    my ($lineageA, $lineageB) = @_;

    my $len_A = @{$lineageA};

    my $index = $len_A-1;

    my @lcalineage = ();

    my %taxidsB = ();

    foreach my $taxon (@{$lineageB})
    {
	$taxidsB{$taxon->{taxid}}++;
    }

    while (exists $taxidsB{$lineageA->[$index]{taxid}} && $index > 0)
    {
	push(@lcalineage, $lineageA->[$index]);
	$index--;
    }

    return [reverse @lcalineage];
    
}

# my $result = NCBI::Taxonomy::getLCAbyGIs(\@gis, 0.5);

sub getLCAbyGIs
{
    my ($refgis, $threshold, $min_lineages) = @_;

    if ((! defined $min_lineages) || $min_lineages !~ /^\d+$/ || $min_lineages < 2)
    {
	$logger->info("No information about the minimum number of lineages was supplied or a non-number or a value less than 2... The parameter will be set to 2 as default!");
	$min_lineages = 2;
    }

    my $glh = getLineagesbyGI(@{$refgis});

    my $lineages_found = 0+(keys %{$glh});

    if ($lineages_found < $min_lineages)
    {
	$logger->info("Number of lineages resulting from GIs is to low (expected >= ", $min_lineages,", found: ", $lineages_found,"), therefore the LCA will be skipped");
	# return an empty array reference
	return [];
    }

    my @pairwise_comparisons = ();

    my %splitcounthash = ();

    my @gis_with_lineage = (keys %{$glh});

    foreach my $x (0..@gis_with_lineage-2)
    {
	foreach my $y ($x+1..@gis_with_lineage-1)
	{
	    push(@pairwise_comparisons, NCBI::Taxonomy::pairwiseLCA($glh->{$gis_with_lineage[$x]}, $glh->{$gis_with_lineage[$y]}));
	}
    }

    foreach my $act_comparison (@pairwise_comparisons)
    {
	
	foreach (@{$act_comparison})
	{
	    $splitcounthash{$_->{taxid}}++;
	}
    }

    my $thresholdcount = $threshold*(scalar @pairwise_comparisons);

    my @sorted_taxids = sort {$splitcounthash{$a} <=> $splitcounthash{$b}} grep {$splitcounthash{$_} >= $thresholdcount} (keys %splitcounthash);

    # get the count number
    my $min_ge_thresholdcount = $splitcounthash{$sorted_taxids[0]};

    # extract only taxids with same count value!!!
    @sorted_taxids = grep {$splitcounthash{$_} == $min_ge_thresholdcount} @sorted_taxids;

    $logger->debug("Found ", (scalar @sorted_taxids), " splits with the same count ($min_ge_thresholdcount)");
    $logger->debug("Taxids with same counts are: ", join(", ", @sorted_taxids));

    my $out = [];

    foreach my $taxid (@sorted_taxids)
    {
	push(@{$out}, getlineagebytaxid($taxid));
    }

    # sort the out array by the lineage length (shortest first)
    @{$out} = sort {0+@{$a} <=> 0+@{$b}} @{$out};

    # test if the shorter taxids are occuring within longer taxonomies
    my %discarded = ();

    my $num_out = 0+@{$out};
    foreach my $act_lineage (0..$num_out-2)
    {
	my $taxid2find = $out->[$act_lineage][0]{taxid};
	foreach my $compare_lineage ($act_lineage+1..$num_out-1)
	{
	    if (grep {($taxid2find == $_->{taxid})} @{$out->[$compare_lineage]})
	    {
		$logger->debug("Discarding lineage");
		$discarded{$act_lineage}++;
		last;
	    }
	}	
    }

    my @final = map {$out->[$_]} grep { ! exists $discarded{$_} } (0..$num_out-1);

    $logger->debug("Finally the number of lineages for output is ", scalar @final);

    return \@final;

}

sub getlineagebytaxid {
    my ($taxid) = @_;
    
    my $out = [];
    my $act_id = $taxid;

    do 
    {
	push(@{$out}, $nodes->[$act_id]); 
	$act_id=$nodes->[$act_id]{ancestor}
    } until ($nodes->[$act_id]{ancestor}==$act_id);

    return $out;
}

sub getnewnodesimported {
    my $nodes = retrieve($taxnodesdatabase)  || $logger->logcroak("Unable to read new nodes database from '$taxnodesdatabase'");
    
    return $nodes;
}

1;

# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

NCBI::Taxonomy - Perl extension for blah blah blah

=head1 SYNOPSIS

  use NCBI::Taxonomy;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for NCBI::Taxonomy, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 HISTORY

version 0.60.0

A new version which uses a binary file type for storing the gi and taxid information.

version 0.61.1853

Switched to Log::Log4perl for messages and added croak commands for failing IO calls!

version 0.62.1854

I am using a ring buffer to save 6000 lineages for taxids to speed up the finding of the lineages.

version 0.63.*

Implementation of a last common ancestor

0.63.1863 

Include last common ancestor calculations now

0.64.1868

Fixed the LCA on request of Felix... A new parameter was added and an
empty result array reference will be returned, if less than 2 lineages
are compared.

0.70.3

Included the new format for the nodes and removed the subroutines
which were necessary for the import of the dmp files.

0.70.5

Added data for creation of a DB and therefore enabling test functionality.


=head1 AUTHOR

Frank Foerster, E<lt>frf53jh@biozentrum.uni-wuerzburg.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Frank Foerster

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut

__DATA__

log4perl.logger = INFO, Screen
log4perl.appender.Screen        = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.stderr = 1
log4perl.appender.Screen.layout.ConversionPattern = %d %m %n
