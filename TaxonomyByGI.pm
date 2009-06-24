package TaxonomyByGI;

# written by Frank Förster

# allows to get the linnage for a given set of GIs

my $TAXDIR = '/bio/data/NCBI/nt/taxonomy'; # where are the taxonomy-files stored

#
# Command: getLineagesbyGI( ref to list of gis, type )
#
# ref to list of gis ... should be selfexplaining
# type ... [NnPp] for nuleotides or proteins
#
# result is a reference of a hash of list of hash
#        first hash key are the GIs
#        elements of list are the nodes of the tree upwards to the root
#        hash keys for the elements
#                sciname -> scientific name of taxon
#                rank -> rank given by NCBI
#                taxid -> taxid resulting from GI

sub getLineagesbyGI(\@$) {

    my @gilist = @{shift()};
    my $seqtype = uc(shift);

    die "Use of [Nn] for nucleotides or [Pp] for proteins as type!\n" unless ($seqtype eq "N" || $seqtype eq "P");

    my %gilist2search = ();
    # check if gis are only numbers!
    foreach (@gilist) {
	die "Use only numbers as GIs!" if ($_ =~ /\D/);
	$gilist2search{$_}++;
    }

    return check4gis(\%gilist2search, $seqtype);

}

sub check4gis(%$) {
    my ($gilist, $type) = @_;

    my %taxid_found_by_gi = ();

    if ($type eq "N") {
	open(FH, "<".$TAXDIR."/gi_taxid_nucl.dmp");
    } else {
	open(FH, "<".$TAXDIR."/gi_taxid_prot.dmp");
    }

    while (<FH>) {
	my @tmp = split(/\t/, $_ );
	chomp(@tmp);
	if (exists $gilist->{$tmp[0]}) {
	    # put the gi and corresponding taxid into new list and delete it from 2search list
	    delete($gilist->{$tmp[0]});
       	    $taxid_found_by_gi{$tmp[0]} = $tmp[1];
	    last if (keys %{$gilist} == 0);
	}
    }
    close(FH);

    # now I have to read the nodes.dmp
    my @nodes = ();
    open(FH, "<".$TAXDIR."/nodes.dmp");
    while (<FH>) {
	my @tmp = split(/\t\|\t/, $_ );
	$nodes[$tmp[0]] = {ancestor => int($tmp[1]), rank => $tmp[2]};
    }
    close(FH);

    # now I can perform the mapping
    $i=0;
    my %Lineage_by_gi = ();
    foreach my $gi (keys %taxid_found_by_gi) {
	my $taxid = $taxid_found_by_gi{$gi};
	$Lineage_by_gi{$gi} = ();
#	while ($nodes[$taxid]->{ancestor} != 1) {
	while () {
	    push(@{$Lineage_by_gi{$gi}}, {taxid => $taxid, rank => $nodes[$taxid]->{rank}});
	    $taxid = $nodes[$taxid]->{ancestor};
	    if ($taxid == 1) {push(@{$Lineage_by_gi{$gi}}, {taxid => $taxid, rank => $nodes[$taxid]->{rank}}); last;};
	}
    }

    # mapping was done, last step is adding the names to every taxid
    # first step is to get a list of all needed taxids - names
    my %taxidnamesneeded = ();
    foreach my $gi (keys %Lineage_by_gi) {
	foreach (@{$Lineage_by_gi{$gi}}) { $taxidnamesneeded{$_->{taxid}}++ }
    }
    # now I am able to search for the taxids
    my %names_by_taxid = ();
    open(FH, "<".$TAXDIR."/names.dmp");
    while (<FH>) {
        my @tmp = split(/\t\|\t/, $_ );
	next if ($tmp[3] !~ /scientific name/);
	next if (!exists $taxidnamesneeded{$tmp[0]}); # next if I do not need the name
	print STDERR "Doppelbelegung von $tmp[0]" if (defined $names[$tmp[0]]);
        $names{$tmp[0]} = $tmp[1];
    }
    close(FH);

    # last step is to add the scientific names to the lineage
    foreach my $gi (keys %Lineage_by_gi) {
	foreach (@{$Lineage_by_gi{$gi}}) { $_->{sciname} = $names{$_->{taxid}}; }
    }

    return \%Lineage_by_gi;

}
