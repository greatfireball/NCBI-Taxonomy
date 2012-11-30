#!/usr/bin/env perl

use strict;
use warnings;
use Fcntl;

### Initialization Section
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO); 

use Getopt::Long;

my $linenumberreport = 10000000;

my $gi_taxid_nucl = "gi_taxid_nucl.dmp";
my $gi_taxid_prot = "gi_taxid_prot.dmp";
my $outfile = "gi_taxid.bin";

my $overwrite = 0;

my $getopt_result = GetOptions(
    'nucl=s' => \$gi_taxid_nucl,
    'prot=s' => \$gi_taxid_prot,
    'output=s' => \$outfile,
    'overwrite!' => \$overwrite
    );

### Get a logger
my $logger = get_logger();

$logger->info("Started update process...");

# check if the output file exists
if (-e $outfile && $overwrite != 1)
{
    $logger->logdie("The outputfile exists! Remove it, use the parameter --overwrite, or give another output location using --outfile parameter");
}

# check if the inputfiles are valid
if (! -e $gi_taxid_nucl)
{
    $logger->logdie("The inputfile for nucleotid gis to taxid is not valid. Used filename was '$gi_taxid_nucl'. Please give a valid filename using the --nucl parameter");
}

if (! -e $gi_taxid_prot)
{
    $logger->logdie("The inputfile for protein gis to taxid is not valid. Used filename was '$gi_taxid_prot'. Please give a valid filename using the --prot parameter");
}


# try to open the output file for writing
open(OF, ">", $outfile) || $logger->logdie("Unable to open the outputfile '$outfile' for writing");

# try to open the input files for reading
open(NF, "<", $gi_taxid_nucl) || $logger->logdie("Unable to open the nucleotid input file '$gi_taxid_nucl' for reading");
open(PF, "<", $gi_taxid_prot) || $logger->logdie("Unable to open the protein input file '$gi_taxid_prot' for reading");

### define the currently used data format
my $data_format = "LL";   ## this means I will store 2 32-bit values!
my $empty_line = pack($data_format, (0,0));
my $data_line_length = length($empty_line);

my $run = 0;

my $nucl_line = undef;
my $prot_line = undef;
my $output_line = 0;

my ($n_gi, $n_taxid, $p_gi, $p_taxid);

my $prot_line_number = 0;
my $nucl_line_number = 0;

my $out = "";

while ($run)
{
    # check if we have to read a new line from nucleotide input
    if (! $nucl_line)
    {
	$nucl_line = <NF>;
	$nucl_line_number++ if ($nucl_line);

	if ($nucl_line =~ /^(\d+)\t(\d+)/)
	{ 
	    ($n_gi, $n_taxid) = ($1, $2);
	} else {
	    $logger->error("Error on parsing line $nucl_line_number from nucleotide input file");
	}

	if ($nucl_line_number%$linenumberreport == 0)
	{
	    $logger->info("Got line $nucl_line_number from nucleotide input file");
	}
    }

    # check if we have to read a new line from protein input
    if (! $prot_line)
    {
	$prot_line = <PF>;
	$prot_line_number++ if ($prot_line);

	if ($prot_line =~ /^(\d+)\t(\d+)/)
	{ 
	    ($p_gi, $p_taxid) = ($1, $2);
	} else {
	    $logger->error("Error on parsing line $prot_line_number from protein input file");
	}

	if ($prot_line_number%$linenumberreport == 0)
	{
	    $logger->info("Got line $prot_line_number from protein input file");
	}
    }

    # check if the gis are different
    if ($n_gi && $p_gi && $n_gi == $p_gi)
    {
	$logger->logdie("Error: same gi for a nucleotide and a protein was found!");
    }

    # check if the current line in output is valid for one of the two input lines meaning the same as the gi!!!
    my $output_string = $empty_line;

    if ($output_line == $n_gi-1)
    {
	$output_string = pack($data_format, ($n_gi, $n_taxid));
	($nucl_line, $n_gi, $n_taxid) = (undef, undef, undef);
    } elsif ($output_line == $p_gi-1)
    {
	$output_string = pack($data_format, ($p_gi, $p_taxid));
	($prot_line, $p_gi, $p_taxid) = (undef, undef, undef);
    }

    $out .= $output_string;
    $output_line++;
    if ($output_line%$linenumberreport == 0)
    {
	$logger->info("Wrote output line $output_line to file");
    }

    # run should be undef if we reached the end of both input files
    $run = ! (eof(NF) && eof(PF));
}

$logger->info("Writing to output file started...");
print OF $out;
$logger->info("Writing to output file finished");

# try to close all files
close(OF) || $logger->logdie("Unable to close the outputfile '$outfile' after writing");
close(NF) || $logger->logdie("Unable to close the nucleotid input file '$gi_taxid_nucl'");
close(PF) || $logger->logdie("Unable to close the protein input file '$gi_taxid_prot'");

getmergedimported();
getnamesimported();
getnodesimported();

$logger->info("Update process finished");

### functions are located here

use Storable qw(nstore);

sub getnodesimported {
    # I want to read the nodes.dmp
    my $nodesfileinput = "nodes.dmp";
    my $nodesfileout = "nodes.bin";

    $logger->info("Started import of nodes.dmp from file '$nodesfileinput'");

    my @nodes = ();
    open(FH, "<", $nodesfileinput) || $logger->logdie("Unable to open file '$nodesfileinput'"); 
    while (<FH>) {
	my @tmp = split(/\t\|\t/, $_ );
	$nodes[$tmp[0]] = {ancestor => int($tmp[1]), rank => $tmp[2]};
    }
    close(FH) || $logger->logdie("Unable to close file '$nodesfileinput'"); 

    nstore(\@nodes, $nodesfileout) || $logger->logdie("Unable to store node information in file '$nodesfileout'");

    $logger->info("Finished import of nodes.dmp from file '$nodesfileinput'");

    return;
}


sub getnamesimported {
    # I want to read the names.dmp
    my $namesfileinput = "names.dmp";
    my $namesfileout = "names.bin";

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

    nstore(\%names_by_taxid, $namesfileout) || $logger->logdie("Unable to store name information in file '$namesfileout'");

    $logger->info("Finished import of names.dmp from file '$namesfileinput'");

    return;
}

sub getmergedimported {
    # I want to read the merged.dmp
    my $mergedfileinput = "merged.dmp";
    my $mergedfileout = "merged.bin";

    $logger->info("Started import of merged.dmp from file '$mergedfileinput'");

    my %merged_by_taxid = ();
    open(FH, "<", $mergedfileinput) || $logger->logdie("Unable to open file '$mergedfileinput'"); 
    while (<FH>) {
        my @tmp = split(/[\s\|]+/, $_ );
	print STDERR "Doppelbelegung von $tmp[0]" if (defined $merged_by_taxid{$tmp[0]});
        $merged_by_taxid{$tmp[0]} = $tmp[1];
    }
    close(FH) || $logger->logdie("Unable to close file '$mergedfileinput'"); 

    nstore(\%merged_by_taxid, $mergedfileout) || $logger->logdie("Unable to store merge information in file '$mergedfileout'");

    $logger->info("Finished import of merged.dmp from file '$mergedfileinput'");

    return;
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


