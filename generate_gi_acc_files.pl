#!/usr/bin/env perl

use strict;
use warnings;

my $basename = "taxonomy";

my $gi_field = "\000"x(10*1024*1024*1024);
my $ref_field = \$gi_field;

my $acc_field = "";

open(my $fh, ">:bytes", $ref_field) || die "Unable to open filehandle\n";

my $taxid_width_bits   = 24;
my $max_gi = 0;

my $max_version = 127;

while (<>)
{
    chomp;
    next if (/^accession\s+accession.version\s+taxid\s+gi/);
    my ($acc, $acc_ver, $taxid, $gi) = split(/\t/, $_);

    $taxid = int($taxid);

    $max_gi = $gi if ($max_gi<$gi);

    my $taxid_compressed = substr(pack("l", $taxid), 0, int($taxid_width_bits/8));

    seek($fh, $gi*int($taxid_width_bits/8), 0) || die;
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

# prepare the header
=pod

=head2 Main header

      Field:        | Bytes per Entry: | Description:
   ----------------------------------------------------------------------------------------------------------
    MagicBytes      |         4        | "NTIF" as string for NCBI-Taxonomy-Index-File
    Version(maj)    |         2        | major version number of file format as 16bit unsigned number
    Version(min)    |         2        | minor version number of file format as 16bit unsigned number
                    |         8        | Reserved
    Offset GI part  |         8        | File offset of GI part as 64bit unsigned number
    Length GI part  |         8        | Length of GI part as 64bit unsigned number
    Offset Acc part |         8        | File offset of Accession part as 64bit unsigned number
    Length Acc part |         8        | Length of Accession part as 64bit unsigned number
    Width TaxID     |         1        | Width of the TaxID in Bits
    Creation date   |        14        | Creation date of the index file in Format YYYYMMDDHHMMSS
    md5sum input    |        16        | MD5sum of all input data processed to generate the index file
    md5sum index    |        16        | MD5sum of complete index file (with this checksum set to all zeros)
                    |        33        | Reserved

=cut

my $header_length_expected = 128;
my $header        = "\000"x$header_length_expected;

my $major_version = 1;
my $minor_version = 0;
my $taxid_width   = 24;
my $gi_offset     = length($header);
my $gi_length     = 0;
my $acc_offset    = 0;
my $acc_length    = 0;
my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
my $current_date  = sprintf("%04d%02d%02d%02d%02d%02d", 1900+$year, 1+$mon, $mday, $hour, $min, $sec);

$header = pack("A4SSA8QQQQCA14A16A16A33",
	       "NTIF",             # magic bytes
	       $major_version,     # major version number
	       $minor_version,     # minor version number
	       "\000"x8,           # reserved
	       $gi_offset,         # GI Part Offset
	       $gi_length,         # GI Part Length
	       $acc_offset,        # Acc Part Offset
	       $acc_length,        # Acc Part Length
	       $taxid_width,       # Bit per TaxID
	       $current_date,      # Creation date
	       "\000"x16,          # md5sum (unused)
	       "\000"x16,          # md5sum (unused)
	       "\000"x33           # reserved
    );

=pod 

=head2 GI header

      Field:             | Bytes per Entry: | Description:
   ----------------------------------------------------------------------------------------------------------
    Offset GI data part  |         8        | File offset of GI data part as 64bit unsigned number
    Length GI data part  |         8        | Length of GI data part as 64bit unsigned number
    Width TaxID          |         1        | Width of the TaxID in Bits
                         |       111        | Reserved

=cut

my $gi_header_length_expected = 128;
my $gi_header = "\000"x$gi_header_length_expected;
my $gi_data_length = int(($max_gi+1)*$taxid_width/8);


$gi_header = pack("QQCA111",
		  $gi_offset+length($gi_header),
		  $gi_data_length,
		  $taxid_width,
		  "\000"x111
    );

die unless (length($gi_header) == $gi_header_length_expected);

substr($gi_field, $gi_data_length) = "";

=pod

=head2 ACC header

      Field:             | Bytes per Entry: | Description:
   ----------------------------------------------------------------------------------------------------------
    Offset acc data part |         8        | File offset of acc data part as 64bit unsigned number
    Length acc data part |         8        | Length of acc data part as 64bit unsigned number
    Width single entry   |         1        | Width of a single entry in Bits
    Width TaxID          |         1        | Width of the TaxID in Bits
                         |       110        | Reserved

=cut

my $acc_header_length_expected = 128;
my $acc_header = "\000"x$acc_header_length_expected;

$acc_header = pack("QQCCA110",
		   $gi_offset+$gi_length+length($acc_header),
		   length($acc_field),
		   $taxid_width,
		   12,
		   "\000"x110
    );

die unless (length($acc_header) == $acc_header_length_expected);

$gi_offset     = length($header);
$gi_length     = length($gi_header)+length($gi_field);
$acc_offset    = $gi_offset+$gi_length;
$acc_length    = length($acc_header)+length($acc_field);
		   
$header = pack("A4SSA8QQQQCA14A16A16A33",
	       "NTIF",             # magic bytes
	       $major_version,     # major version number
	       $minor_version,     # minor version number
	       "\000"x8,           # reserved
	       $gi_offset,         # GI Part Offset
	       $gi_length,         # GI Part Length
	       $acc_offset,        # Acc Part Offset
	       $acc_length,        # Acc Part Length
	       $taxid_width,       # Bit per TaxID
	       $current_date,      # Creation date
	       "\000"x16,          # md5sum (unused)
	       "\000"x16,          # md5sum (unused)
	       "\000"x33           # reserved
    );
die unless (length($header) == $header_length_expected);

open($fh, ">:bytes", $basename.".taxonomy.bin") || die "Unable to open output file\n";
print $fh $header, $gi_header, $gi_field, $acc_header, $acc_field;
close($fh) || die "Unable to close output file\n";
