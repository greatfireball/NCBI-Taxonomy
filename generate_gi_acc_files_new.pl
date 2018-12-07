#!/usr/bin/env perl

use strict;
use warnings;

### Initialization Section
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);  # Set priority of root logger to ERROR

### Application Section
my $logger = get_logger();

#my $hash_size = 10000019;
#my $hash_size = 9;
my $hash_size  = 1000003;
my $gi_buckets = 1000003;
my $taxid_width_bits   = 24;

use Digest::MD5 qw(md5);

my $acc_data = [];
my $gi_data  = [];

use Gzip::Faster;
use Term::ProgressBar;

$logger->info("Starting data import");

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
    my $bucket = int($gi/$gi_buckets);
    my $pos    = int($gi%$gi_buckets);

    $gi_data->[$bucket][$pos] = $taxid_compressed;

    # store the acc
    my $data_package = pack("C1C1a3a*", 0, $version, $taxid_compressed, $acc);
    substr($data_package, 0, 1, pack("C1", length($data_package)));
    push(@{$acc_data}, $data_package);
}

my $uncompressed = 0;
my $compressed   = 0;

$logger->info("Starting sorting and compression");

my $gf = Gzip::Faster->new();
$gf->gzip_format(1);    # switch to deflate format
$gf->raw(0);            # switch to non-raw deflate format
$gf->level(9);          # compression level 9

my $progress = Term::ProgressBar->new({count => int(@$gi_data), name => "Compress", ETA => 'linear', remove => 0});
$progress->minor(0);
my $next_update = 0;

for (my $i=0; $i<@$gi_data; $i++)
{
    if (defined $gi_data->[$i])
    {
	# print STDERR "Sorting $i\n";
	my $joined_string = join("", map {defined $_ ? $_ : pack("CCC", 0,0,0) } (@{$gi_data->[$i]}));
	$uncompressed += length($joined_string);
	my $data_compressed = $gf->zip($joined_string);
	$compressed += length($data_compressed);
    }
    $next_update = $progress->update($i) if $i >= $next_update;
}

$progress->update(int(@$gi_data)) if int(@$gi_data) >= $next_update;
$logger->info(sprintf "Uncompressed length: %d, Compressed length: %d, Compression level: %.3f\n", $uncompressed, $compressed, $compressed/$uncompressed);

__END__
$logger->info("Writing output file");

open(FH, ">", "hash_offsets.map") || die "$!\n";
open(FD, ">", "accessions.dat") || die "$!\n";
my $pos = 0;

$progress = Term::ProgressBar->new({count => int(@$data), name => "Output Writing", ETA => 'linear', remove => 0});
$progress->minor(0);
$next_update = 0;

for(my $i=0; $i<int(@$data); $i++)
{
    print FH pack("Q", $pos);
    print FD $data->[$i];
    $pos+=length($data->[$i]);
    $next_update = $progress->update($i) if $i >= $next_update;
}

$progress->update(int(@$data)) if int(@$data) >= $next_update;
close(FH) || die "$!\n";
close(FD) || die "$!\n";

$logger->info(sprintf "Written %d Bytes of output data and %d Bytes of hash files", $pos, 8*int(@$data));

       while ($pos < length($data->[$i]))
       {
           # get first (length) byte
           my $len = unpack("C", substr($data->[$i], $pos, 1));
           my $data_package = substr($data->[$i], $pos, $len);
           $pos=$pos+$len;

           my ($flag, $version, $taxid_compressed, $acc) = unpack("C1C1a3a*", $data_package);

           push(@dat2sort, [$acc, $data_package]);
       }
