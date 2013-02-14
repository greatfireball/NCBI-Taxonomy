package NCBI::Taxonomy;

use 5.008000;
use strict;
use warnings;
use DateTime::Format::Natural;

use Storable qw(retrieve);

# second we generate a version number depending on the current main
# version number and the revision. The main version number is located
# at the globals module and can be accessed by the function
# globals::getmainversionnumber()
use version 0.77; my $mainversionnumber = "0.62"; '$Revision: 1900$' =~ /Revision:\s*(\d+)/; our $VERSION=version->declare($mainversionnumber.".".$1);

# for logging purposes we use the Log4perl module
use Log::Log4perl;

my $init_text = "";
while (<DATA>) { $init_text .= $_; }

Log::Log4perl->init(\$init_text);
my $logger = Log::Log4perl->get_logger();

$logger->debug("Loaded the module NCBI::Taxonomy.pm (file ".__FILE__.", version: $VERSION)");

my $TAXDIR = '/bio/data/NCBI/taxonomy/';   # where are the taxonomy-files stored
my $taxdatabase = $TAXDIR."/gi_taxid.bin";
my $taxnodesdatabase = $TAXDIR."/nodes.bin";
my $taxnamesdatabase = $TAXDIR."/names.bin";
my $taxmergeddatabase = $TAXDIR."/merged.bin";

my @nodes = @{getnodesimported()};            # import the nodes.dmp for later use at loading of the module
my %names_by_taxid = %{getnamesimported()};   # import the names.dmp for later use at loading of the module
my %merged_by_taxid = %{getmergedimported()}; # import the merged.dmp for later use at loading of the module

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

    open(FH, "<", $taxdatabase) || logger->logdie("Unable to open taxonomic database at '$taxdatabase'");
    binmode(FH);

    my $data_format = "LL";

    my $bytesperline = length(pack($data_format, (0,0)));
    my $tmp = "";

    foreach my $gi (keys %$gilist) {
	my $bytepos = ($gi-1)*$bytesperline;
	
	# check if the taxid is not present, but was already downloaded
	if (exists $downloaded_gi_taxid{$gi})
	{
	    $logger->info("Found taxid for gi $gi already downloaded");
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

	# check if the lineage exists in the ring_buffer
	if (exists $ring_buffer_storage{$taxid})
	{
	    $logger->debug("Used ring buffer to speed up");
	    $Lineage_by_gi{$gi} = [@{$ring_buffer_storage{$taxid}}]
	} else {
	    my $taxid4ringbuffer = $taxid;
	    while () {
		push(@{$Lineage_by_gi{$gi}}, {taxid => $taxid, rank => $nodes[$taxid]->{rank}});
		$taxid = checktaxid4merged($nodes[$taxid]->{ancestor});
		if (!defined $taxid) {
		    $logger->error("Error $gi gives undefined TaxID");
		    delete $Lineage_by_gi{$gi};
		    last;
		}
		if ($taxid == 1) {
		    push(@{$Lineage_by_gi{$gi}}, {taxid => $taxid, rank => $nodes[$taxid]->{rank}}); 
		    # check if the ringbuffer is filled completely
		    if (@ring_buffer >= $max_ring_buffer_size)
		    {
			while (@ring_buffer >= $max_ring_buffer_size)
			{
			    my $forremove = shift(@ring_buffer);
			    delete ($ring_buffer_storage{$forremove});
			    $logger->debug("Deleted from ring buffer!");
			}
		    } 
	
		    push(@ring_buffer, $taxid4ringbuffer);
		    $ring_buffer_storage{$taxid4ringbuffer} = [@{$Lineage_by_gi{$gi}}];
		    $logger->debug("Filled ring buffer!");

		    last;
		};
	    }
	}
    }

    # mapping was done, last step is adding the names to every taxid
    # first step is to get a list of all needed taxids - names
    my %taxidnamesneeded = ();
    foreach my $gi (keys %Lineage_by_gi) {
	foreach (@{$Lineage_by_gi{$gi}}) { $taxidnamesneeded{$_->{taxid}}++ }
    }

    # last step is to add the scientific names to the lineage
    foreach my $gi (keys %Lineage_by_gi) {
	foreach (@{$Lineage_by_gi{$gi}}) { $_->{sciname} = $names_by_taxid{$_->{taxid}}; }
    }

    return \%Lineage_by_gi;

}

sub getnodesimported {
    my $nodes = retrieve($taxnodesdatabase) || $logger->logcroak("Unable to read taxonomic nodes database from '$taxnodesdatabase'");

    return $nodes;
}

sub getnamesimported {
    my $names_by_taxid = retrieve($taxnamesdatabase)  || $logger->logcroak("Unable to read taxonomic names database from '$taxnamesdatabase'");

    return $names_by_taxid;
}

sub getmergedimported {

    my $merged_by_taxid = retrieve($taxmergeddatabase)  || $logger->logcroak("Unable to read merging database from '$taxmergeddatabase'");
    
    return $merged_by_taxid;
}

sub checktaxid4merged ($) {
    my ($taxid) = @_;
    if (defined $taxid && exists $merged_by_taxid{$taxid})
    {
	return $merged_by_taxid{$taxid};
    } else {
	return $taxid;
    }
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
