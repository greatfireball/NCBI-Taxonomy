#!/usr/bin/env perl

use strict;
use warnings;

my $basename = "taxonomy";

my $gi_field = "\000"x(10*1024*1024*1024);
my $ref_field = \$gi_field;

my $acc_field = "";

open(my $fh, ">:bytes", $ref_field) || die "Unable to open filehandle\n";

my $max_gi = 0;

my $max_version = 127;

while (<>)
{
    chomp;
    next if (/^accession\s+accession.version\s+taxid\s+gi/);
    my ($acc, $acc_ver, $taxid, $gi) = split(/\t/, $_);

    $taxid = int($taxid);

    $max_gi = $gi if ($max_gi<$gi);

    my $taxid_compressed = substr(pack("l", $taxid), 0, 3);

    seek($fh, $gi*3, 0) || die;
    print $fh $taxid_compressed;

    my $version = 0;
    $version = int($1) if ($acc_ver =~ /\.(\d+)$/);

    my $flag = 0;

    while(length($acc)>0)
    {
	my $acc_output = substr($acc, 0, 8, "");
	if (length($acc_output)<8)
	{
	    $acc_output.=" "x(8-length($acc_output));
	}

	$acc_field .= pack("C1a8a3", $flag+$version, $acc_output, $taxid_compressed);

	$flag = 128;
    }
}

close($fh) || die "Unable to close filehandle\n";

# write to $basename.".gi.bin"
substr($field, ($max_gi+1)*3) = "";
open($fh, ">:bytes", $basename.".gi.bin") || die "Unable to open output file\n";
print $fh $gi_field;
close($fh) || die "Unable to close output file\n";

# write to $basename.".acc.bin"
open($fh, ">:bytes", $basename.".acc.bin") || die "Unable to open output file\n";
print $fh $acc_field;
close($fh) || die "Unable to close output file\n";

