#!/bin/perl

use strict;
use warnings;

my %gi_list2search = ();
my %taxid_found_by_gi = ();

open(FH, "<gi_list_22876.txt");
while (<FH>) {
	$_ =~ s/^\s*|[\r\n\s]*$//g;
	$gi_list2search{$_}++;
}
close(FH);

# jetzt kann ich nach den Lines schauen
my $i=0;
open (FH, "<gi_taxid_nucl.dmp");
while (<FH>) {
	my @tmp = split(/\t/, $_ );
	chomp(@tmp);
	if (exists $gi_list2search{$tmp[0]}) {
		# in einem neuen Array speichern und aus dem Hash löschen!
		delete($gi_list2search{$tmp[0]});
		#print "Noch ".(keys %gi_list2search)." Taxa\n";
		$taxid_found_by_gi{$tmp[0]} = $tmp[1];
		last if (keys %gi_list2search == 0);
	}
	$i++;
	#print "." if ($i%1000000);
}
close(FH);

print STDERR "Es wurden ".(keys %taxid_found_by_gi)." taxids ermittelt\n";

# jetzt kann ich nodes.dmp einlesen
my @nodes = ();
open(FH, "<nodes.dmp");
while (<FH>) {
	my @tmp = split(/\t\|\t/, $_ );
	$nodes[$tmp[0]] = {ancestor => $tmp[1], rank => $tmp[2]};
}
close(FH);

# jetzt kann ich das Mapping machen
$i=0;
my %familytaxid_found_by_gi = ();
foreach (keys %taxid_found_by_gi) {
	my $taxid = $taxid_found_by_gi{$_};
	while ($nodes[$taxid]->{rank} !~ /^\s*class\s*$/ && $nodes[$taxid]->{ancestor} != $taxid) {
		$taxid = $nodes[$taxid]->{ancestor};
	}
	if ($taxid != $nodes[$taxid]->{ancestor}) {
		$familytaxid_found_by_gi{$_} = $taxid;
		$i++;
		print STDERR "Gefundene GIs: $i, last GI:$_\n";
	}
}

print STDERR "Es wurden ".(keys %familytaxid_found_by_gi)." family-taxids ermittelt\n";

# jetzt interessiert uns aber noch der Name, also wollen wir die Namen aus names.dmp
my @names = ();
open(FH, "<names.dmp");
while (<FH>) {
        my @tmp = split(/\t\|\t/, $_ );
	next if ($tmp[3] !~ /scientific name/);
	print STDERR "Doppelbelegung von $tmp[0]" if (defined $names[$tmp[0]]);
        $names[$tmp[0]] = $tmp[1];
}
close(FH);

my @found_family = ();
foreach (keys %familytaxid_found_by_gi) {
	if (defined $names[$familytaxid_found_by_gi{$_}]) {
		print "$_\t".$names[$familytaxid_found_by_gi{$_}]."\n";
		# hier mache ich eine Liste der GI-Familien, damit ich die fehlenden ausgeben kann!
		push(@found_family, $_);
	} else {
		print STDERR "Fehler bei GI:".$_." --- kann keinem Familiennamen zugeordnet werden!\n";
	}
}

# jetzt bleibt nur noch eine Differenz der eingegangen GIs und der Familien-GIs zu ermitteln und diese GIs ohne Familie auszugeben:
foreach (@found_family) {
	delete($taxid_found_by_gi{$_});
}
# jetzt sollten nur noch GIs ohne Familie enthalten sein:
print STDERR "Keine Zuordnung zu Familien für ".(keys %taxid_found_by_gi)."\n";
foreach (keys %taxid_found_by_gi) {
	print "$_\t\n";
}
