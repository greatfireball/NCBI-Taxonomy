#!/usr/bin/env perl

use strict;
use warnings;
use Fcntl;

### Initialization Section
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO); 

use Getopt::Long;

my $linenumberreport = 10000000;

my $ranksfileout = "ranks.bin";
my $nodesfileout = "nodes.bin";

my @files2download = qw(ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxcat.tar.gz ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz);

my $overwrite = 0;
my $download = 1;

my $quiet = 0;

my $getopt_result = GetOptions(
    'overwrite!' => \$overwrite,
    'download!' => \$download,
    'quiet'     => \$quiet,
    );

### check if quiet is requested
if ($quiet != 0)
{
    # set the logger to FATALs only
    Log::Log4perl->easy_init($FATAL);
}

### Get a logger
my $logger = get_logger();

$logger->info("Started update process...");

# should I download the files?
if ($download)
{
    require File::Basename;

    foreach my $file (@files2download)
    {
	my $basename = File::Basename::basename($file, (".gz", ".tar.gz"));

	# does the file exist?
	if (-e "$basename")
	{
	    # remove the file
	    unlink($basename) || $logger->logdie("Unable to delete file '$basename'");
	}

	my $cmd = "wget -O - '$file' 2>/dev/null";
	if ($file =~ /.tar.gz$/)
	{
	    $cmd .= "| tar xzf -";
	} elsif ($file =~ /.gz$/)
	{
	    $cmd .= "| gunzip > $basename";
	}
	$logger->info("Running command '$cmd'...");
	qx($cmd);
	$logger->info("Running command '$cmd' finished.");
    }
}

$logger->info("Starting import of information about merged taxids");
my $merged = getmergedimported();
$logger->info("Finished import of information about merged taxids");

$logger->info("Starting import of information about names for taxids");
my $names = getnamesimported();
$logger->info("Finished import of information about names for taxids");

$logger->info("Starting import of information about nodes for taxids");
my ($nodes, $ranks) = getnodesimported();
$logger->info("Finished import of information about nodes for taxids");

$logger->info("Starting extraction and storage of used ranks");
my @ranks_used = keys %{$ranks};
nstore(\@ranks_used, $ranksfileout) || $logger->logdie("Unable to store information about the used ranks in file '$ranksfileout'");
$logger->info("Finished extraction and storage of used ranks");

$logger->info("Starting combining node and names information");
foreach my $act_taxid (0..@{$nodes}-1)
{
    if (ref $nodes->[$act_taxid])
    {
	$nodes->[$act_taxid]->{sciname} = $names->{$act_taxid};
	$nodes->[$act_taxid]->{taxid} = $act_taxid;
    }
}
$logger->info("Finished combining node and names information");

$logger->info("Started adding merged taxid information");
foreach my $merged_taxid (keys %{$merged})
{
    $nodes->[$merged_taxid]->{merged_with} = $merged->{$merged_taxid};
    $nodes->[$merged_taxid]->{taxid} = $merged_taxid;
    foreach (qw(ancestor rank sciname))
    {
	$nodes->[$merged_taxid]->{$_} = $nodes->[$nodes->[$merged_taxid]->{merged_with}]->{$_};
    }
}
$logger->info("Finished adding merged taxid information");

$logger->info("Started storing node information in binary format");
nstore($nodes, $nodesfileout) || $logger->logdie("Unable to store node information in file '$nodesfileout'");
$logger->info("Finished storing node information in binary format");

$logger->info("Update process finished");

### functions are located here

use Storable qw(nstore);

sub getnodesimported {
    # I want to read the nodes.dmp
    my $nodesfileinput = "nodes.dmp";

    $logger->info("Started import of nodes.dmp from file '$nodesfileinput'");

    my @nodes = ();
    my %ranks = ();
    open(FH, "<", $nodesfileinput) || $logger->logdie("Unable to open file '$nodesfileinput'"); 
    while (<FH>) {
	my @tmp = split(/\t\|\t/, $_ );
	unless (defined $tmp[0] && defined $tmp[1] && defined $tmp[2])
	{
	    # skip the line if the elements 0..2 in @tmp are not defined!
	    $logger->debug("Found undefined values for the line '$_'");
	    next;
	}
	$nodes[$tmp[0]] = {ancestor => int($tmp[1]), rank => $tmp[2]};
	$ranks{$tmp[2]}++;
    }
    close(FH) || $logger->logdie("Unable to close file '$nodesfileinput'"); 

    $logger->info("Finished import of nodes.dmp from file '$nodesfileinput'");

    return \@nodes, \%ranks;
}


sub getnamesimported {
    # I want to read the names.dmp
    my $namesfileinput = "names.dmp";

    $logger->info("Started import of names.dmp from file '$namesfileinput'");

    my %names_by_taxid = ();
    open(FH, "<", $namesfileinput) || $logger->logdie("Unable to open file '$namesfileinput'"); 
    while (<FH>) {
        my @tmp = split(/\t\|\t/, $_ );
	next if ($tmp[3] !~ /scientific name/);
	print STDERR "Doppelbelegung von $tmp[0]" if (defined $names_by_taxid{$tmp[0]});
        $names_by_taxid{$tmp[0]} = $tmp[1];
    }
    close(FH) || $logger->logdie("Unable to close file '$namesfileinput'"); 

    $logger->info("Finished import of names.dmp from file '$namesfileinput'");

    return \%names_by_taxid;
}

sub getmergedimported {
    # I want to read the merged.dmp
    my $mergedfileinput = "merged.dmp";

    $logger->info("Started import of merged.dmp from file '$mergedfileinput'");

    my %merged_by_taxid = ();
    open(FH, "<", $mergedfileinput) || $logger->logdie("Unable to open file '$mergedfileinput'"); 
    while (<FH>) {
        my @tmp = split(/[\s\|]+/, $_ );
	print STDERR "Doppelbelegung von $tmp[0]" if (defined $merged_by_taxid{$tmp[0]});
        $merged_by_taxid{$tmp[0]} = $tmp[1];
    }
    close(FH) || $logger->logdie("Unable to close file '$mergedfileinput'"); 

    $logger->info("Finished import of merged.dmp from file '$mergedfileinput'");

    return \%merged_by_taxid;
}


exit;

__END__


my $act_line=0;

my @lines = split(/\s+/, qx(tail -qn 1   | cut -f 1 | tr "\n" " "));

my @files=('gi_taxid_nucl.dmp', 'gi_taxid_prot.dmp');
@files= reverse @files if ($lines[0]<$lines[1]);

open(FH, "<".$files[0]);
open(OUT, ">".'gi_taxid.txt'); # frueher tmp.txt
while (<FH>) {
	if ($act_line != 0 && $act_line%100000==0)
        {
            if ($act_line%1000000==0)
            {
                print STDERR int($act_line/1000000);
            } else {
                print STDERR ".";
            }
        }	 
	my ($gi,$taxid) = $_ =~ /^(\d+)\t(\d+)/; 
	while ($act_line != ($gi-1)) {
		print OUT ((" "x15)."\t".(" "x7)."\n"); 
		$act_line++;
	} 
	printf OUT "%15i\t%7i\n", $gi, $taxid;
	$act_line++
}
close(OUT);
close(FH);

print STDERR "\nFinished first file!\n"; 
$act_line = 0;

open(FH, "<".$files[1]);
sysopen(OUT, 'gi_taxid.txt', O_WRONLY, 0440);
binmode(OUT);
while (<FH>) {
        $act_line++;
        if ($act_line != 0 && $act_line%100000==0)
        {
            if ($act_line%1000000==0)
            {
                print STDERR int($act_line/1000000);
            } else {
                print STDERR ".";
            }
        }
        my ($gi,$taxid) = $_ =~ /^(\d+)\t(\d+)/;
	sysseek(OUT, ($gi-1)*24, 0);
        syswrite(OUT, sprintf("%15i\t%7i\n", $gi, $taxid), 24);
}
close(OUT);
close(FH);


