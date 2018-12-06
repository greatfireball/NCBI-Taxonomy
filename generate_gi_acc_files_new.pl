#!/usr/bin/env perl

use strict;
use warnings;

#my $hash_size = 10000019;
#my $hash_size = 9;
my $hash_size = 1000003;
my $taxid_width_bits   = 24;

use Digest::MD5 qw(md5);

my $field = [];
my $data = [];

while (<>)
{
    chomp;
    next if (/^accession\s+accession.version\s+taxid\s+gi/);
    my ($acc, $acc_ver, $taxid, $gi) = split(/\t/, $_);

    $taxid = int($taxid);
    my $taxid_compressed = substr(pack("l", $taxid), 0, int($taxid_width_bits/8));

    my $version = 0;
    $version = int($1) if ($acc_ver =~ /\.(\d+)$/);

    # store the gi
    my @md5 = unpack("Q*", md5($gi));
    my $hash = $md5[0]%$hash_size;

    $field->[$hash]++;

    my $data_package = pack("C1C1a3a*", 0, 0, $taxid_compressed, $gi);
    substr($data_package, 0, 1, pack("C1", length($data_package)));
    $data->[$hash] .= $data_package;

    # store the gi
    @md5 = unpack("Q*", md5($acc));
    $hash = $md5[0]%$hash_size;

    $field->[$hash]++;

    $data_package = pack("C1C1a3a*", 0, $version, $taxid_compressed, $acc);
    substr($data_package, 0, 1, pack("C1", length($data_package)));
    $data->[$hash] .= $data_package;
}

my $sum = 0;
my $counter = 0;
my $undef_counter = 0;
foreach (@$field)
{
    if (defined $_)
    {
	$sum = $sum + $_;
	$counter++;
    } else {
	$undef_counter++;
    }
}

printf STDERR "%d values set, sum: %d, mean value: %.2f, %d undef values\n", $counter, $sum, ($sum/$counter), $undef_counter;

my $uncompressed = 0;
my $compressed   = 0;

for(my $i=0; $i<@$data; $i++)
{
    if (defined $data->[$i])
    {
	print STDERR "Sorting $i\n";

	my @dat2sort = ();

	my $pos = 0;

	#print $data->[$i];
	
	while ($pos < length($data->[$i]))
	{
	    # get first (length) byte
	    my $len = unpack("C", substr($data->[$i], $pos, 1));
	    my $data_package = substr($data->[$i], $pos, $len);
	    $pos=$pos+$len;

	    my ($flag, $version, $taxid_compressed, $acc) = unpack("C1C1a3a*", $data_package);
	    
	    push(@dat2sort, [$acc, $data_package]);
	}

	print STDERR "Unsorted: ", join(",", map {$_->[0]} (@dat2sort)), "\n";
	@dat2sort = sort {$a->[0] cmp $b->[0]} (@dat2sort);
	print STDERR "Sorted: ", join(",", map {$_->[0]} (@dat2sort)), "\n";

        my $data_sorted = join("", map { $_->[1] } @dat2sort);
	$uncompressed += length($data_sorted);

	my $data_compressed = "";

	use IO::Compress::Gzip qw(gzip $GzipError);

	gzip \$data_sorted => \$data_compressed, '-Level' => 9, 'Minimal' => 1 || die "gzip failed: $GzipError";

	$compressed += length($data_compressed);

	$data->[$i] = $data_compressed;
    }
}

printf STDERR "Uncompressed length: %d, Compressed length: %d, Compression level: %.3f\n", $uncompressed, $compressed, $compressed/$uncompressed;
