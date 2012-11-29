package NCBI::Taxonomy;

use 5.008000;
use strict;
use warnings;
use DateTime::Format::Natural;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use NCBI::Taxonomy ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.52.1';

# Preloaded methods go here.

my $TAXDIR = '/bio/data/NCBI/taxonomy/';   # where are the taxonomy-files stored
my @nodes = getnodesimported();            # import the nodes.dmp for later use at loading of the module
my %names_by_taxid = getnamesimported();   # import the names.dmp for later use at loading of the module
my %merged_by_taxid = getmergedimported(); # import the merged.dmp for later use at loading of the module

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
	die "Use only numbers as GIs!" if ($_ =~ /\D/);
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

    die "Use of not known taxonomic rank\n" if ($taxonrankvalid == 0);

    my %gilist2search = ();
    # check if gis are only numbers!
    foreach (@gilist) {
	die "Use only numbers as GIs!" if ($_ =~ /\D/);
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

    open(FH, "<".$TAXDIR."/gi_taxid.txt");
    binmode(FH);

    my $bytesperline = 24;
    my $tmp = "";

    foreach my $gi (keys %$gilist) {
	my $bytepos = ($gi-1)*$bytesperline;
	seek(FH, $bytepos, 0);
	read(FH, $tmp, $bytesperline);
	if (($tmp =~ /(\d+)\t\s*(\d+)/) && ($gi == $1)) {
	    $taxid_found_by_gi{$gi} = int($2);
	} else {
	    my $output = qx(wget -q -O - 'http://www.ncbi.nlm.nih.gov/sviewer/viewer.fcgi?tool=portal&db=nuccore&val=$gi&dopt=genbank&sendto=on&log$=seqview&extrafeat=976&maxplex=1');
	    if ($? == 0) {
		if ($output =~ /^COMMENT\s+\[WARNING\] On (.+) this sequence was replaced by.+gi:(\d+)\./msg) {
		    my ($datestring, $new_gi) = ($1,$2);
		    my $parser = DateTime::Format::Natural->new;
		    my $dt = $parser->parse_datetime($datestring);
		    print STDERR "It seems GI|$gi was substituted on ".$dt." with GI|$new_gi (".'http://www.ncbi.nlm.nih.gov/entrez/sutils/girevhist.cgi?val='."$gi)\n";
		} else {
		    my @taxons = $output =~ /db_xref="taxon:(\d+)"/g;
		    if (@taxons == 1) {
			$taxid_found_by_gi{$gi} = int($taxons[0]);
			print STDERR "Have to download the GenBank file for GI|$gi but was able to retrieve an Taxon-ID\n";
		    } elsif (@taxons > 1) {
			print STDERR "Error on retrieving a single Taxon-ID for GI|$gi. Returned were the following Taxon-IDs:".join(",", @taxons)."\n";
		    } else {
			print STDERR "Error on retrieving Taxon-ID for GI|$gi\n";
		    }
		}
	    } else {
		print STDERR "Error on receiving the following URL: http://www.ncbi.nlm.nih.gov/sviewer/viewer.fcgi?tool=portal&db=nuccore&val=$gi&dopt=genbank&sendto=on&log$=seqview&extrafeat=976&maxplex=1\n";
	    }
	}
    }

    close(FH);

    # now I can perform the mapping
    my %Lineage_by_gi = ();
    foreach my $gi (keys %taxid_found_by_gi) {
	my $taxid = checktaxid4merged($taxid_found_by_gi{$gi});
	if (!defined $taxid) {
	    print STDERR "$gi liefert eine undefinierte TaxID\n";
	    next;
	}
	$Lineage_by_gi{$gi} = ();
	while () {
	    push(@{$Lineage_by_gi{$gi}}, {taxid => $taxid, rank => $nodes[$taxid]->{rank}});
	    $taxid = checktaxid4merged($nodes[$taxid]->{ancestor});
	    if (!defined $taxid) {
		print STDERR "Bei $gi wird eine undefinierte TaxID zurückgeliefert\n";
		delete $Lineage_by_gi{$gi};
		last;
	    }
	    if ($taxid == 1) {push(@{$Lineage_by_gi{$gi}}, {taxid => $taxid, rank => $nodes[$taxid]->{rank}}); last;};
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
    # I want to read the nodes.dmp
    my @nodes = ();
    open(FH, "<".$TAXDIR."/nodes.dmp");
    while (<FH>) {
	my @tmp = split(/\t\|\t/, $_ );
	$nodes[$tmp[0]] = {ancestor => int($tmp[1]), rank => $tmp[2]};
    }
    close(FH);

    return @nodes;
}

sub getnamesimported {
    my %names_by_taxid = ();
    open(FH, "<".$TAXDIR."/names.dmp");
    while (<FH>) {
        my @tmp = split(/\t\|\t/, $_ );
	next if ($tmp[3] !~ /scientific name/);
	print STDERR "Doppelbelegung von $tmp[0]" if (defined $names_by_taxid{$tmp[0]});
        $names_by_taxid{$tmp[0]} = $tmp[1];
    }
    close(FH);

    return %names_by_taxid;
}

sub getmergedimported {
    my %merged_by_taxid = ();
    open(FH, "<".$TAXDIR."/merged.dmp");
    while (<FH>) {
        my @tmp = split(/[\s\|]+/, $_ );
	print STDERR "Doppelbelegung von $tmp[0]" if (defined $merged_by_taxid{$tmp[0]});
        $merged_by_taxid{$tmp[0]} = $tmp[1];
    }
    close(FH);

    return %merged_by_taxid;
}

sub checktaxid4merged ($) {
    my ($taxid) = @_;
    return (exists $merged_by_taxid{$taxid})?$merged_by_taxid{$taxid}:$taxid;
}

1;
__END__
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

=head1 AUTHOR

Frank Foerster, E<lt>frf53jh@biozentrum.uni-wuerzburg.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Frank Foerster

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


perl -MDateTime::Format::Natural -e '
     while (<>) {$a.=$_;} 
     if ($a =~ /^COMMENT\s+\[WARNING\] On (.+) this sequence was replaced by.+gi:(\d+)\./msg) { 
        print "$1\t$2\n";
     } 
     $parser = DateTime::Format::Natural->new;
     $dt = $parser->parse_datetime($1);
     print $dt;'
